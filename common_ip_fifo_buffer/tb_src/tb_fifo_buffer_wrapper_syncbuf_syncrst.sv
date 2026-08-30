`timescale 1ns/1ps

module tb_fifo_buffer_wrapper_syncbuf_syncrst();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section

parameter		int                 DWIDTH		=	8           ;
parameter		int                 AWIDTH		=	8           ;
parameter		int                 FIFO_STYLE  =	0           ;   //0 - SCFIFO, 1 - DCFIFO
parameter       int                 SYNC_RSTN   =   1           ;   //0 - async reset, 1 - synced to both write and read separately

parameter       int                 MAX_VALUE   =   2**DWIDTH-1 ;
parameter       int                 MAX_WORDS   =   2**AWIDTH   ;

logic                               rst_n                       ;

logic		                        clk                         ;
// logic		                        clk_write               ;
logic		                        enable_write                ;
logic		    [DWIDTH - 1 : 0] 	data_write                  ;
logic                               flag_full                   ;
logic 	        [AWIDTH - 1 : 0] 	flag_afull_thrsh            ;
logic 	                            flag_afull                  ;
logic 	                            rst_n_synched_write         ;

// logic		                        clk_read                ;
logic		                        enable_read                 ;
logic		    [DWIDTH - 1 : 0] 	data_read                   ;
logic		                        flag_empty                  ;
logic		                        valid_read                  ;
logic 	        [AWIDTH - 1 : 0] 	flag_aempty_thrsh           ;
logic 	                            flag_aempty                 ;
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
    .clk_write              (clk                    ),
    .enable_write           (enable_write           ),
    .data_write             (data_write             ),
    .flag_full              (flag_full              ),
    .flag_afull_thrsh       (flag_afull_thrsh       ),
    .flag_afull             (flag_afull             ),
    .rst_n_synched_write    (rst_n_synched_write    ),

    
    //Read side signals declaration
    .clk_read               (clk                    ),
    .enable_read            (enable_read            ),
    .data_read              (data_read              ),
    .flag_empty             (flag_empty             ),
    .valid_read             (valid_read             ),
    .flag_aempty_thrsh      (flag_aempty_thrsh      ),
    .flag_aempty            (flag_aempty            ),
    .rst_n_synched_read     (rst_n_synched_read     )
);
//End of instancing module section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
initial
begin : clk_generation_process
	clk = 0;
	forever #10 clk=~clk;
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

    repeat(50) @(posedge clk);
    rst_n = '0;

    //Await rst capturing
    while(1) begin
        @(posedge clk);
        if(rst_n_synched_write && rst_n_synched_read) begin
            break;
        end
    end

    @(posedge clk);
    rst_n <= '1;
    @(posedge clk);

    repeat(50) @(posedge clk);

    if(flag_empty != 1) begin
        $display(">>>>> ERROR: FIFO flag shows that buffer is not empty");
        $finish();
    end

    for (int i = 0; i < MAX_WORDS; i++) begin
        enable_write <= '1;
        data_write <= $urandom_range(0, MAX_VALUE);
        @(posedge clk);
    end
    enable_write <= '0;

    repeat(50) @(posedge clk);

    if(flag_full != 1) begin
        $display(">>>>> ERROR: FIFO flag shows that buffer is not full");
        $finish();
    end

    for (int i = 0; i < MAX_WORDS; i++) begin
        enable_read <= '1;
        @(posedge clk);
    end
    enable_read <= '0;

    repeat(50) @(posedge clk);
    $display(">>>>> SUCCESS: test done");
    $finish();
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of process to handle fifo writing section
initial begin: write_queue
    while (1) begin
        @(posedge clk);
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
        @(posedge clk);
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