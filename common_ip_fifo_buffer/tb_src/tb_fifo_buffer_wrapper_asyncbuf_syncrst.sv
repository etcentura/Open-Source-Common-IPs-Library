`timescale 1ns/1ps

module tb_fifo_buffer_wrapper_asyncbuf_syncrst();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section

parameter		int                 DWIDTH		=	8           ;
parameter		int                 AWIDTH		=	8           ;
parameter		int                 FIFO_STYLE  =	1           ;   //0 - SCFIFO, 1 - DCFIFO
parameter       int                 SYNC_RSTN   =   1           ;   //0 - async reset, 1 - synced to both write and read separately

parameter       int                 MAX_VALUE   =   2**DWIDTH-1 ;
parameter       int                 MAX_WORDS   =   2**AWIDTH   ;

logic                               rst_n                       ;

logic		                        clk_write                   ;
logic		                        enable_write                ;
logic		    [DWIDTH - 1 : 0] 	data_write                  ;
logic                               flag_full                   ;
logic 	                            rst_n_synched_write         ;

logic		                        clk_read                    ;
logic		                        enable_read                 ;
logic		    [DWIDTH - 1 : 0] 	data_read                   ;
logic		                        flag_empty                  ;
logic		                        valid_read                  ;
logic 	                            rst_n_synched_read          ;

//Queue to store 
logic		    [DWIDTH - 1 : 0] 	data_queue[$]               ;
logic		    [DWIDTH - 1 : 0] 	data_from_queue             ;
logic		    [DWIDTH - 1 : 0] 	data_from_buffer            ;

//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing module section section
fifo_buffer_wrapper
#
(
    .DWIDTH                 (DWIDTH                 ),
    .AWIDTH                 (AWIDTH                 ),
    .FIFO_STYLE             (FIFO_STYLE             ),   //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN              (SYNC_RSTN              )    //0 - async reset, 1 - synced to both write and read separately
)
                            i_fifo_buffer_wrapper
(
    //RST signlal
    .rst_n                  (rst_n                  ),

    //Write side signals declaration
    .clk_write              (clk_write              ),
    .enable_write           (enable_write           ),
    .data_write             (data_write             ),
    .flag_full              (flag_full              ),
    .rst_n_synched_write    (rst_n_synched_write    ),

    
    //Read side signals declaration
    .clk_read               (clk_read               ),
    .enable_read            (enable_read            ),
    .data_read              (data_read              ),
    .flag_empty             (flag_empty             ),
    .valid_read             (valid_read             ),
    .rst_n_synched_read     (rst_n_synched_read     )
);
//End of instancing module section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
//Writing is faster than reading
initial
begin : clk_generation_process_write
	clk_write = 0;
	forever #5 clk_write=~clk_write;
end

initial
begin : clk_generation_process_read
	clk_read = 0;
	forever #10 clk_read=~clk_read;
end
//End of generatring clk clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section
initial 
begin: main_scenario
    rst_n = '1;
    enable_write <= '0;
    enable_read <= '0;

    repeat(50) @(posedge clk_write);
    rst_n = '0;

    //Await rst capturing
    while(1) begin
        @(posedge clk_write);
        if(rst_n_synched_write && rst_n_synched_read) begin
            break;
        end
    end

    @(posedge clk_write);
    rst_n <= '1;
    @(posedge clk_write);

    repeat(50) @(posedge clk_write);

    if(flag_empty != 1) begin
        $display(">>>>> ERROR: FIFO flag shows that buffer is not empty");
        $finish();
    end

    for (int i = 0; i < MAX_WORDS; i++) begin
        enable_write <= '1;
        data_write <= $urandom_range(0, MAX_VALUE);
        @(posedge clk_write);
    end
    enable_write <= '0;

    repeat(50) @(posedge clk_read);

    if(flag_full != 1) begin
        $display(">>>>> ERROR: FIFO flag shows that buffer is not full");
        $finish();
    end

    for (int i = 0; i < MAX_WORDS; i++) begin
        enable_read <= '1;
        @(posedge clk_read);
    end
    enable_read <= '0;

    repeat(50) @(posedge clk_read);
    $display(">>>>> SUCCESS: test done");
    $finish();
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of process to handle fifo writing section
initial begin: write_queue
    while (1) begin
        @(posedge clk_write);
        if(enable_write) begin
            data_queue.push_back(data_write);
        end
    end
end
//End of process to handle fifo writing section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of process to handle fifo reading section
initial begin
    data_from_queue = '0;
    while (1) begin
        @(posedge clk_read);
        if(valid_read) begin
            data_from_queue = data_queue.pop_front();
            data_from_buffer = data_read;

            if(data_from_queue != data_from_buffer) begin
                $error(">>>>> ERROR: FIFO data is not the same");
                $finish();
            end
        end
    end
end
//End of process to handle fifo reading section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule