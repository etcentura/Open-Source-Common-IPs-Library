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
    input		logic		                        rst_n                                                       ,

    //Write side signals declaration
    input		logic		                        clk_write                                                   ,
    input		logic		                        enable_write                                                ,
    input		logic		[DWIDTH - 1 : 0] 	    data_write              [WINDOW_SIZE]   [WINDOW_SIZE]       ,
    output		logic		                        flag_full               [WINDOW_SIZE]                       ,
    output      logic 	                            rst_n_synched_write                                         ,
    
    input		logic		                        clk_read                                                    ,
    input		logic		                        enable_read                                                 ,
    input		logic		[DWIDTH - 1 : 0] 	    data_read                                                   ,
    output		logic                               flag_empty               [WINDOW_SIZE]                      ,
    output		logic		                        valid_read                                                  ,
    output      logic 	                            rst_n_synched_read                                          ,

    //Read side signals declaration

    //Configuration signals
    input 	    logic 	    [CSR_WIDTH - 1 : 0]     csr_im_width                                                ,
    input 	    logic 	    [CSR_WIDTH - 1 : 0]     csr_im_height                                               ,
    input 	    logic 	                            csr_flip_input_rows                                         ,

    //Status port of the lines captured 
    output 	    logic 	                            status_line_captured    [WINDOW_SIZE]
);


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//rst_n synch
logic 	                            synced_rst_n_write_main                                             ;
logic 	                            synced_rst_n_read_main                                              ;     

//input data arbitre
logic 	                            int_valid_latch_w                                                   ; 
logic 	                            int_ready_latch_w                                                   ;

logic 	    [DWIDTH - 1 : 0] 	    int_data_latch_w                    [WINDOW_SIZE]   [WINDOW_SIZE]   ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_win_cols                                            ;

logic 	    [DWIDTH - 1 : 0] 	    int_data_to_fifo                    [WINDOW_SIZE]                   ;

//internal status port
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_win_inline                                          ;
logic 	                            int_status_line_captured                                            ;
logic 	                            int_status_line_captured_to_read                                    ;

//Read req detector and resync
logic 	                            enable_read_reg                                                     ;
logic 	                            enable_read_pos                                                     ;
logic 	                            enable_read_neg                                                     ;
logic 	                            enable_read_flag                                                    ;
logic 	       [3 : 0]              enable_read_count                                                   ;
logic 	                            read_req_resync_to_write                                            ;

//Internal fifo data flow control signals
logic 	                            rst_n_synched_write_int             [WINDOW_SIZE]                   ;
logic 	                            rst_n_synched_read_int              [WINDOW_SIZE]                   ;
logic 	                            flag_full_int                       [WINDOW_SIZE]                   ;
logic 	                            flag_empty_int                      [WINDOW_SIZE]                   ;

logic 	                            valid_read_int                      [WINDOW_SIZE]                   ;
logic                               enable_read_int                     [WINDOW_SIZE]                   ;
logic		[DWIDTH - 1 : 0] 	    data_read_int                       [WINDOW_SIZE]                   ;

logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_line_pixs_read                                      ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_frame_rows_read                                     ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_line_pixs_response                                  ;
logic 	    [CSR_WIDTH - 1 : 0] 	arbitre_counter_frame_rows_response                                 ;


//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input data section
always_ff @(posedge clk_write)
begin
    if(!synced_rst_n_write_main)begin
        int_valid_latch_w               <= '0; 
        int_ready_latch_w               <= '1;
    end
    else begin
        if(int_ready_latch_w)begin
            if(enable_write)begin
                int_valid_latch_w <= '1;
                int_ready_latch_w <= '0;
            end
        end
        else begin
            if(arbitre_counter_win_cols == WINDOW_SIZE - 1)begin
                int_valid_latch_w <= '0;
                int_ready_latch_w <= '1;
            end
        end
    end
end

always_ff @(posedge clk_write)
begin
    if(!synced_rst_n_write_main)begin
        for (int i = 0; i < WINDOW_SIZE; i++) begin
            for (int j = 0; j < WINDOW_SIZE; j++) begin
                int_data_latch_w[i][j] <= '0;
            end
        end
    end
    else begin
        if(int_ready_latch_w && enable_write)begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    if(csr_flip_input_rows)begin
                        int_data_latch_w[i][j] <= data_write[i][WINDOW_SIZE - j - 1];
                    end
                    else begin
                        int_data_latch_w[i][j] <= data_write[i][j];
                    end
                end
            end
        end
        else if(int_valid_latch_w)begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                for (int j = WINDOW_SIZE-1; j > 0; j--) begin
                    int_data_latch_w[i][j] <= int_data_latch_w[i][j-1];
                end
            end
        end
    end
end

always_ff @(posedge clk_write)
begin
    if(!synced_rst_n_write_main)begin
        arbitre_counter_win_cols <= '0;
    end
    else begin
        if(int_valid_latch_w)begin
            arbitre_counter_win_cols <= arbitre_counter_win_cols + 1;
        end
        else begin
            arbitre_counter_win_cols <= '0;
        end
    end
end

always_comb
begin
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        int_data_to_fifo[i] = int_data_latch_w[i][WINDOW_SIZE-1];
    end
end

always_ff @(posedge clk_write)
begin
    if(!synced_rst_n_write_main)begin
        arbitre_counter_win_inline <= '0;
    end
    else begin
        if(int_valid_latch_w) begin
            if(arbitre_counter_win_inline == csr_im_width - 1)begin
                arbitre_counter_win_inline <= '0;
            end
            else begin
                arbitre_counter_win_inline <= arbitre_counter_win_inline + 1;
            end
        end
    end
end

always_ff @(posedge clk_write)
begin
    if(!synced_rst_n_write_main)begin
        int_status_line_captured <= '0;
    end
    else begin
        if(read_req_resync_to_write)begin
            int_status_line_captured <= '0;
        end
        else if (arbitre_counter_win_inline == csr_im_width - 1) begin
            int_status_line_captured <= '1;
        end
    end
end
//End of latching input data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync status line captured to read side section
signal_synchronizer
#
(
    .SYNCWIDTH      (1                                  ),
    .SYNCSTEPS      (2                                  )
)
                    i_signal_synchronizer_line_captured
(
    .clk_src        (clk_write                          ),
    .clk_dst        (clk_read                           ),
    .data_src       (int_status_line_captured           ),
    .data_dst       (int_status_line_captured_to_read   )
);
//End of resync status line captured to read side section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of detecting read request section
always_ff @(posedge clk_read)
begin
    if(!synced_rst_n_read_main)
        begin
            enable_read_reg <= '0;
        end
    else
        begin
            enable_read_reg <= enable_read;
        end
end

assign 	enable_read_pos 	= ~enable_read_reg & enable_read;
assign 	enable_read_neg 	= enable_read_reg & ~enable_read;

always_ff @(posedge clk_read)
begin
    if(!synced_rst_n_read_main)begin
        enable_read_flag  <= '0;
        enable_read_count <= '0;
    end
    else begin
        if(!enable_read_flag)begin
            if(enable_read_pos)begin
                enable_read_flag  <= '1;
                enable_read_count <= '0;
            end
        end
        else begin
            if(enable_read_count == 8-1)begin
                enable_read_flag  <= '0;
                enable_read_count <= '0;
            end
            else begin
                enable_read_count <= enable_read_count + 1;
            end
        end
    end
end
//End of detecting read request section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync enable read flag section
signal_synchronizer
#
(
    .SYNCWIDTH      (1                                  ),
    .SYNCSTEPS      (2                                  )
)
                    i_signal_synchronizer_enable_read
(
    .clk_src        (clk_read                           ),
    .clk_dst        (clk_write                          ),
    .data_src       (enable_read_flag                   ),
    .data_dst       (read_req_resync_to_write           )
);
//End of resync enable read flag section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync for the reset section
signal_synchronizer
#
(
    .SYNCWIDTH      (1                                  ),
    .SYNCSTEPS      (2                                  )
)
                    i_signal_synchronizer_rst_write
(
    .clk_src        (clk_write                          ),
    .clk_dst        (clk_write                          ),
    .data_src       (rst_n                              ),
    .data_dst       (synced_rst_n_write_main            )
);

signal_synchronizer
#
(
    .SYNCWIDTH      (1                                  ),
    .SYNCSTEPS      (2                                  )
)
                    i_signal_synchronizer_rst_read
(
    .clk_src        (clk_read                           ),
    .clk_dst        (clk_read                           ),
    .data_src       (rst_n                              ),
    .data_dst       (synced_rst_n_read_main             )
);
//End of resync for the reset section
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
//Begin of instancing fifo buffers to store window data section
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
            .enable_write           (int_valid_latch_w              ),
            .data_write             (int_data_latch_w[j]            ),
            .flag_full              (flag_full[j]                   ),
            .rst_n_synched_write    (rst_n_synched_write_int[j]     ),

            
            //Read side signals declaration
            .clk_read               (clk_read                       ),  
            .enable_read            (enable_read_int[j]             ),  
            .data_read              (data_read_int[j]               ),  
            .flag_empty             (flag_empty[j]                  ),  
            .valid_read             (valid_read_int[j]              ),  
            .rst_n_synched_read     (rst_n_synched_read_int[j]      )   
        );
    end
endgenerate
//End of instancing fifo buffers to store window data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving read counters section
always_ff @(posedge clk_read)
begin
    if(!synced_rst_n_read_main)begin
        arbitre_counter_line_pixs_read   <= '0;
        arbitre_counter_frame_rows_read  <= '0;
    end
    else begin
        if(enable_read)begin
            if(arbitre_counter_line_pixs_read == csr_im_width - 1)begin
                if(arbitre_counter_frame_rows_read == csr_im_height - 1)begin
                    arbitre_counter_line_pixs_read   <= '0;
                    arbitre_counter_frame_rows_read  <= '0;
                end
                else begin
                    arbitre_counter_line_pixs_read   <= '0;
                    arbitre_counter_frame_rows_read  <= arbitre_counter_frame_rows_read + 1;
                end
            end
            else begin
                arbitre_counter_line_pixs_read   <= arbitre_counter_line_pixs_read + 1;
            end
        end
    end
end
//End of driving read counters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of response counters section
always_ff @(posedge clk_read)
begin
    if(!synced_rst_n_read_main)begin
        arbitre_counter_line_pixs_response   <= '0;
        arbitre_counter_frame_rows_response  <= '0;
    end
    else begin
        if(valid_read)begin
            if(arbitre_counter_line_pixs_response == csr_im_width - 1)begin
                if(arbitre_counter_frame_rows_response == csr_im_height - 1)begin
                    arbitre_counter_line_pixs_response   <= '0;
                    arbitre_counter_frame_rows_response  <= '0;
                end
                else begin
                    arbitre_counter_line_pixs_response   <= '0;
                    arbitre_counter_frame_rows_response  <= arbitre_counter_frame_rows_response + 1;
                end
            end
            else begin
                arbitre_counter_line_pixs_response   <= arbitre_counter_line_pixs_response + 1;
            end
        end
    end
end
//End of response counters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of arbiter for read enable and valid response section
always_comb
begin
    enable_read_int = '0;
    enable_read_int[arbitre_counter_frame_rows_read] = enable_read;

    valid_read = '0;
    valid_read = valid_read_int[arbitre_counter_frame_rows_response];

    data_read = data_read_int[arbitre_counter_frame_rows_response];
end
//End of arbiter for read enable and valid response section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
