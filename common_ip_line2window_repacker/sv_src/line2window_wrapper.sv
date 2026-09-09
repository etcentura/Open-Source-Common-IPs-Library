module line2window_wrapper
#
(
    parameter		int     DWIDTH		=	8                   ,   //Width of the bus for: data
    parameter		int     AWIDTH		=	8                   ,   //Width of the bus for: address (2**AWIDTH = MAX pixels in line)
    parameter		int     FIFO_STYLE  =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     SYNC_RSTN   =   0                   ,   //0 - async reset, 1 - synced to both write and read separately
    parameter       int     WINDOW_SIZE =   8                   ,   //Size of the window to be stored to the buffer
    parameter       int     CSR_WIDTH   =   32                      //Width of the control-setup registers
)

(
    //RST signlal
    input		logic		                        rst_n                                                   ,

    //Write side signals declaration
    input		logic		                        clk_write                                               ,
    input		logic		                        enable_write                                            ,
    input		logic		[DWIDTH - 1 : 0] 	    data_write                                              ,
    output		logic                               flag_full               [WINDOW_SIZE]                   ,
    output      logic 	                            rst_n_synched_write                                     ,

    
    //Read side signals declaration
    input		logic		                        clk_read                                                ,
    input		logic		                        enable_read                                             ,
    output		logic		[DWIDTH - 1 : 0] 	    data_read               [WINDOW_SIZE]   [WINDOW_SIZE]   ,
    output		logic		                        flag_empty              [WINDOW_SIZE]                   ,
    output		logic		                        valid_read                                              ,
    output      logic 	                            rst_n_synched_read                                      ,

    //Configuration signals
    input 	    logic 	    [CSR_WIDTH - 1 : 0]     csr_im_width                                            ,
    input 	    logic 	    [CSR_WIDTH - 1 : 0]     csr_im_height                                           ,
    input 	    logic 	                            csr_flip_output_rows                                    ,

    //Status port of the lines captured 
    output 	    logic 	                            status_line_captured    [WINDOW_SIZE]
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//rst_n synch
logic 	                            synced_rst_n_write_main                                             ;
logic 	                            synced_rst_n_read_main                                              ;

//Internal fifo data flow control signals
logic 	                            rst_n_synched_write_int             [WINDOW_SIZE]                   ;
logic 	                            rst_n_synched_read_int              [WINDOW_SIZE]                   ;
logic 	                            enable_write_int                    [WINDOW_SIZE]                   ;
logic		[DWIDTH - 1 : 0] 	    data_read_int                       [WINDOW_SIZE]                   ;
logic 	                            valid_read_int                      [WINDOW_SIZE]                   ;
logic 	                            flag_full_int                       [WINDOW_SIZE]                   ;
logic 	                            flag_empty_int                      [WINDOW_SIZE]                   ;

//input data arbitre
logic 	                            int_valid_latch_w                                                   ;
logic 	    [DWIDTH - 1 : 0] 	    int_data_latch_w                                                    ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_pixs_w                                              ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_lines_w                                             ;

//internal status port
logic 	                            int_status_line_captured            [WINDOW_SIZE]                   ;

//capturing read request
logic 	                            captured_read_req                                                   ;
logic 	                            captured_read_req_sync                                              ;
logic 	                            captured_read_req_sync_back                                         ;

//window forming singals
logic 	    [CSR_WIDTH - 1 : 0]     window_read_counter                                                 ;
logic 	    [DWIDTH - 1 : 0] 	    int_data_window                     [WINDOW_SIZE]   [WINDOW_SIZE]   ;
logic 	                            int_valid_window                                                    ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input data section
always_ff @(posedge clk_write)
begin
    int_valid_latch_w <= '0;
    if (enable_write) begin
        int_valid_latch_w <= '1;
        int_data_latch_w <= data_write;
    end
end
//End of latching input data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving write arvitre counter section
always_ff @(posedge clk_write)
begin
    if (!synced_rst_n_write_main)
        begin
            arbitre_counter_pixs_w      <= '0;
            arbitre_counter_lines_w     <= '0;
        end
    else
        begin
            if (int_valid_latch_w) begin
                if (arbitre_counter_pixs_w == csr_im_width - 1)
                    begin
                        if (arbitre_counter_lines_w == WINDOW_SIZE - 1)
                            begin
                                arbitre_counter_pixs_w      <= '0;
                                arbitre_counter_lines_w     <= '0;
                            end
                        else
                            begin
                                arbitre_counter_pixs_w      <= '0;
                                arbitre_counter_lines_w     <= arbitre_counter_lines_w + 1;
                            end
                    end
                else
                    begin
                        arbitre_counter_pixs_w   <= arbitre_counter_pixs_w + 1;
                    end
            end  
        end
end
//End of driving write arvitre counter section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of selecting fifo buffer to write section
always_comb
begin
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        if(i == arbitre_counter_lines_w)begin
            enable_write_int[i] = int_valid_latch_w;    
        end
        else begin
            enable_write_int[i] = '0;
        end
    end
end
//End of selecting fifo buffer to write section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving status line signals section
always_ff @(posedge clk_write or negedge synced_rst_n_write_main)
begin
    if(!synced_rst_n_write_main)
        begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                int_status_line_captured[i] <= '0;    
            end
        end
    else
        begin
            if(captured_read_req_sync) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    int_status_line_captured[i] <= '0;    
                end
            end
            else if(arbitre_counter_pixs_w == csr_im_width - 1) begin
                int_status_line_captured[arbitre_counter_lines_w] <= '1;
            end
        end
end

generate
    genvar i;
    for (i = 0; i < WINDOW_SIZE; i++) begin
        signal_synchronizer
        #
        (
            .SYNCWIDTH      (1                              ),
            .SYNCSTEPS      (2                              )
        )
                            i_signal_synchronizer_resync_line_status
        (
            .clk_src        (clk_write                      ),
            .clk_dst        (clk_read                       ),
            .data_src       (int_status_line_captured[i]    ),
            .data_dst       (status_line_captured[i]        )
        );
    end
endgenerate
//End of driving status line signals section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving capturing read request section
always_ff @(posedge clk_read or negedge synced_rst_n_read_main)
begin
    if(!synced_rst_n_read_main)
        begin
            captured_read_req <= '0;
        end
    else
        begin
            if(captured_read_req_sync_back) begin
                captured_read_req <= '0;
            end
            else if(enable_read) begin
                captured_read_req <= '1;
            end
        end
end

signal_synchronizer
#
(
    .SYNCWIDTH      (1                              ),
    .SYNCSTEPS      (2                              )
)
                    i_signal_synchronizer_read2write_read_req
(
    .clk_src        (clk_read                       ),
    .clk_dst        (clk_write                      ),
    .data_src       (captured_read_req              ),
    .data_dst       (captured_read_req_sync         )
);

signal_synchronizer
#
(
    .SYNCWIDTH      (1                              ),
    .SYNCSTEPS      (2                              )
)
                    i_signal_synchronizer_read2write_read_req_back
(
    .clk_src        (clk_read                       ),
    .clk_dst        (clk_write                      ),
    .data_src       (captured_read_req_sync         ),
    .data_dst       (captured_read_req_sync_back    )
);
//End of driving capturing read request section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of forming a window section
always_ff @(posedge clk_read or negedge synced_rst_n_read_main)
begin
    if(!synced_rst_n_read_main)
        begin
            window_read_counter <= '0;
        end
    else
        begin
            if(valid_read_int[0]) begin
                if(window_read_counter == WINDOW_SIZE-1) begin
                    window_read_counter <= '0;
                end
                else begin
                    window_read_counter <= window_read_counter + 1;
                end
            end
        end
end

always_ff @(posedge clk_read or negedge synced_rst_n_read_main)
begin
    if(!synced_rst_n_read_main)
        begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    int_data_window[i][j] <= '0;
                end
            end
        end
    else
        begin
            if(valid_read_int[0]) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    int_data_window[i][0] <= data_read_int[i];
                    for (int j = 1; j < WINDOW_SIZE; j++) begin
                        int_data_window[i][j] <= int_data_window[i][j-1];
                    end
                end
            end
        end
end

always_ff @(posedge clk_read or negedge synced_rst_n_read_main)
begin
    if(!synced_rst_n_read_main)
        begin
            int_valid_window <= '0;
        end
    else
        begin
            if((window_read_counter == WINDOW_SIZE-1) && (valid_read_int[0])) begin
                int_valid_window <= '1;
            end
            else begin
                int_valid_window <= '0;
            end
        end
end

//End of forming a window section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync for the reset section
signal_synchronizer
#
(
    .SYNCWIDTH      (1                              ),
    .SYNCSTEPS      (2                              )
)
                    i_signal_synchronizer_rst_write
(
    .clk_src        (clk_write                      ),
    .clk_dst        (clk_write                      ),
    .data_src       (rst_n                          ),
    .data_dst       (synced_rst_n_write_main        )
);

signal_synchronizer
#
(
    .SYNCWIDTH      (1                              ),
    .SYNCSTEPS      (2                              )
)
                    i_signal_synchronizer_rst_read
(
    .clk_src        (clk_read                       ),
    .clk_dst        (clk_read                       ),
    .data_src       (rst_n                          ),
    .data_dst       (synced_rst_n_read_main         )
);
//End of resync for the reset section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating fifo buffers to store windows data section
generate
    genvar j;
    for (j = 0; j < WINDOW_SIZE; j++) begin: fifo_gen
        fifo_buffer_wrapper
        #
        (
            .DWIDTH                 (DWIDTH                         ),
            .AWIDTH                 (AWIDTH                         ),
            .FIFO_STYLE             (FIFO_STYLE                     ),
            .SYNC_RSTN              (SYNC_RSTN                      )
        )
                                    i_fifo_buffer_wrapper
        (
            //RST signlal
            .rst_n                  (rst_n                          ),

            //Write side signals declaration
            .clk_write              (clk_write                      ),
            .enable_write           (enable_write_int[j]            ),
            .data_write             (int_data_latch_w               ),
            .flag_full              (flag_full[j]                   ),
            .rst_n_synched_write    (rst_n_synched_write_int[j]     ),

            
            //Read side signals declaration
            .clk_read               (clk_read                       ),  
            .enable_read            (enable_read                    ),  
            .data_read              (data_read_int[j]               ),  
            .flag_empty             (flag_empty[j]                  ),  
            .valid_read             (valid_read_int[j]              ),  
            .rst_n_synched_read     (rst_n_synched_read_int[j]      )   
        );
    end
endgenerate
//End of generating fifo buffers to store windows data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving rst detection section
always_comb
begin
    rst_n_synched_write = synced_rst_n_write_main & rst_n_synched_write_int[0];
    rst_n_synched_read = synced_rst_n_read_main & rst_n_synched_read_int[0];
end
//End of driving rst detection section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of outputting signals section
always_comb
begin
    valid_read = int_valid_window;
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        for (int j = 0; j < WINDOW_SIZE; j++) begin
            if(csr_flip_output_rows)begin 
                data_read[i][j] = int_data_window[i][WINDOW_SIZE - j - 1];    
            end
            else begin
                data_read[i][j] = int_data_window[i][j];
            end
            
        end
    end
end
//End of outputting signals section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule