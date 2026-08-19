module fifo_buffer_wrapper
#
(
    parameter		int     DWIDTH		=	8                   ,
    parameter		int     AWIDTH		=	8                   ,
    parameter		int     FIFO_STYLE  =	0                   ,   //0 - SCFIFO, 1 - DCFIFO
    parameter       int     SYNC_RSTN   =   0                   ,   //0 - async reset, 1 - synced to both write and read separately
)

(
    //RST signlal
    input		logic		                    rst_n               ,

    //Write side signals declaration
    input		logic		                    clk_write           ,
    input		logic		                    enable_write        ,
    input		logic		[DWIDTH - 1 : 0] 	data_write          ,
    output		logic                           flag_full           ,
    input 	    logic 	    [AWIDTH - 1 : 0] 	flag_afull_thrsh    ,
    output      logic 	                        flag_afull          ,
    output      logic 	                        rst_n_synched_write ,

    
    //Read side signals declaration
    input		logic		                    clk_read            ,
    input		logic		                    enable_read         ,
    output		logic		[DWIDTH - 1 : 0] 	data_read           ,
    output		logic		                    flag_empty          ,
    output		logic		                    valid_read          ,
    input 	    logic 	    [AWIDTH - 1 : 0] 	flag_aempty_thrsh   ,
    output      logic 	                        flag_aempty         ,
    output      logic 	                        rst_n_synched_read  ,
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Declaring core storage
logic	    [DWIDTH - 1 : 0] 	core_fifo_storage   [2**AWIDTH]     ;

//Write side signals latching
logic		[DWIDTH - 1 : 0] 	int_data_latch_w                    ;
logic		                    int_valid_latch_w                   ;

//Read side signals declaration
logic		[DWIDTH - 1 : 0] 	int_data_latch_r                    ;
logic		                    int_valid_latch_r                   ;

//These signal are used when FIFO_STYLE == 1 (DCFIFO selected)
logic		[AWIDTH : 0] 	    int_write_pointer                   ;
logic		[AWIDTH : 0] 	    int_write_pointer_gray              ;
logic		[AWIDTH : 0]        int_write_pointer_gray_reg          ;
logic		[AWIDTH : 0] 	    int_write_pointer_gray_sync         ;
logic		[AWIDTH : 0] 	    int_write_pointer_sync              ;

logic		[AWIDTH : 0] 	    int_read_pointer                    ;
logic		[AWIDTH : 0] 	    int_read_pointer_gray               ;
logic		[AWIDTH : 0] 	    int_read_pointer_gray_reg           ;
logic		[AWIDTH : 0] 	    int_read_pointer_gray_sync          ;
logic		[AWIDTH : 0] 	    int_read_pointer_sync               ;

//These signal are used when SYNC_RSTN == 1
logic 	                        synced_rst_n_write                  ;
logic 	                        synced_rst_n_read                   ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching input data section
always_ff @(posedge clk_write)
begin
    int_valid_latch_w <= '0;
    if ((enable_write) && (!flag_full)) begin
        int_valid_latch_w <= '1;
        int_data_latch_w <= data_write;
    end
end
//End of latching input data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data into the memory section
always_ff @(posedge clk_write)
begin
    if(!rst_n_write)
        begin
            int_write_pointer <= '0;
        end
    else
        begin
            if ((int_valid_latch_w) && (!flag_full)) begin
                int_write_pointer <= int_write_pointer + 1;
            end
        end
end

always_ff @(posedge clk_write)
begin
    if ((int_valid_latch_w) && (!flag_full)) begin
        core_fifo_storage[int_write_pointer[AWIDTH - 1 : 0]] <= int_data_latch_w;
    end 
end
//End of driving data into the memory section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync of write pointer section
generate
    if(FIFO_STYLE == 1)begin
        //Converting binary pointer into the gray code to sync it
        common_ip_bin2gray_converter
        #
        (
            .DWIDTH         (AWIDTH + 1                     )
        )
                            i_common_ip_bin2gray_converter_write
        (
            .data_input     (int_write_pointer              ),
            .data_output    (int_write_pointer_gray         )
        );

        //Registering converted into the gray code binary pointer
        always_ff @(posedge clk_write) 
        begin
            int_write_pointer_gray_reg <= int_write_pointer_gray;
        end

        //Sync the write pointer gray code
        signal_synchronizer
        #
        (
            .SYNCWIDTH      (AWIDTH + 1                     ),
            .SYNCSTEPS      (2                              )
        )
                            i_signal_synchronizer_write
        (
            .clk_src        (clk_write                      ),
            .clk_dst        (clk_read                       ),

            .data_src       (int_write_pointer_gray_reg     ),
            .data_dst       (int_write_pointer_gray_sync    )
        );

        //Deconverting gray code into binary form on the read-side
        gray2bin_converter
        #
        (
            .DWIDTH         (AWIDTH + 1                     )
        )
                            i_gray2bin_converter_write
        (
            .data_input     (int_write_pointer_gray_sync    ),
            .data_output    (int_write_pointer_sync         )
        );
    end
endgenerate
//End of resync of write pointer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving data from the memory section
always_ff @(posedge clk_read)
begin
    if(!rst_n_read)
        begin
            int_read_pointer <= '0;
        end
    else
        begin
            if ((enable_read) && (!flag_empty)) begin
                int_read_pointer <= int_read_pointer + 1;
            end
        end
end

always_ff @(posedge clk_read)
begin
    int_data_latch_r <= core_fifo_storage[int_read_pointer[AWIDTH - 1 : 0]];
    
    int_valid_latch_r <= '0;
    if ((enable_read) && (!flag_empty)) begin
        int_valid_latch_r <= '1;
    end
end
//End of driving data from the memory section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of outputting data section
always_ff @(posedge clk_read)
begin
    valid_read <= int_valid_latch_r;
    data_read <= int_data_latch_r;
end
//End of outputting data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of resync of read pointer section
generate
    if(FIFO_STYLE == 1) begin
        //Converting binary pointer into the gray code to sync it
        common_ip_bin2gray_converter
        #
        (
            .DWIDTH         (AWIDTH + 1                     )
        )
                            i_common_ip_bin2gray_converter_read
        (
            .data_input     (int_read_pointer               ),
            .data_output    (int_read_pointer_gray          )
        );

        //Registering converted into the gray code binary pointer
        always_ff @(posedge clk_read) 
        begin
            int_read_pointer_gray_reg <= int_read_pointer_gray;
        end

        //Sync the read pointer gray code
        signal_synchronizer
        #
        (
            .SYNCWIDTH      (AWIDTH + 1                     ),
            .SYNCSTEPS      (2                              )
        )
                            i_signal_synchronizer_read
        (
            .clk_src        (clk_read                       ),
            .clk_dst        (clk_write                      ),

            .data_src       (int_read_pointer_gray_reg      ),
            .data_dst       (int_read_pointer_gray_sync     )
        );

        //Deconverting gray code into binary form on the write-side
        gray2bin_converter
        #
        (
            .DWIDTH         (AWIDTH + 1                     )
        )
                            i_gray2bin_converter_read
        (
            .data_input     (int_read_pointer_gray_sync     ),
            .data_output    (int_read_pointer_sync          )
        );
    end
endgenerate
//End of resync of read pointer section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of comparing pointers section
generate
    if (FIFO_STYLE == 1) begin
        //Compairing synced pointers if DCFIFO selected
        always_comb
        begin
            flag_full = '0;
            if ({~int_write_pointer[AWIDTH], int_write_pointer[AWIDTH-1:0]} == int_read_pointer_sync) begin
                flag_full = '1;
            end
        end

        always_comb
        begin
            flag_empty = '0;
            if (int_write_pointer_sync == int_read_pointer) begin
                flag_empty = '1;
            end
        end
    end
    else begin
        //Compairing usual pointers if SCFIFO selected
        always_comb
        begin
            flag_full = '0;
            if ({~int_write_pointer[AWIDTH], int_write_pointer[AWIDTH-1:0]} == int_read_pointer) begin
                flag_full = '1;
            end
        end

        always_comb
        begin
            flag_empty = '0;
            if (int_write_pointer == int_read_pointer) begin
                flag_empty = '1;
            end
        end
    end
endgenerate
//End of comparing pointers section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of name section
generate
    if (SYNC_RSTN == 1) begin
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
            .data_dst       (synced_rst_n_write             )
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
            .data_dst       (synced_rst_n_read              )
        );

        always_comb
        begin
            rst_n_synched_write = ~synced_rst_n_write;
            rst_n_synched_read = ~synced_rst_n_read;
        end
    end
    else begin
        always_comb
        begin
            rst_n_synched_write = ~rst_n;
            rst_n_synched_read = ~rst_n;
        end
    end
endgenerate
//End of name section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
