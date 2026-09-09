`timescale 1ns/1ps

module tb_video_pattern_generator_wrapper();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section
parameter		int     DWIDTH		=	8       ;   //Width of the bus for: data
parameter		int     AWIDTH		=	10      ;   //Width of the bus for: address (2**AWIDTH = MAX pixels in line)
parameter		int     FIFO_STYLE  =	1       ;   //0 - SCFIFO, 1 - DCFIFO
parameter       int     SYNC_RSTN   =   0       ;   //0 - async reset, 1 - synced to both write and read separately
parameter       int     WINDOW_SIZE =   8       ;   //Size of the window to be stored to the buffer
parameter       int     CSR_WIDTH   =   32      ;   //Width of the control-setup registers

//RST signlal
logic		                        rst_n                                                   ;
//Write side signals declaration
logic		                        clk_write                                               ;
logic		                        enable_write                                            ;
logic		[DWIDTH - 1 : 0] 	    data_write                                              ;
logic                               flag_full               [WINDOW_SIZE]                   ;
logic 	                            rst_n_synched_write                                     ;
//Read side signals declaration
logic		                        clk_read                                                ;
logic		                        enable_read                                             ;
logic		[DWIDTH - 1 : 0] 	    data_read               [WINDOW_SIZE]   [WINDOW_SIZE]   ;
logic		                        flag_empty              [WINDOW_SIZE]                   ;
logic		                        valid_read                                              ;
logic 	                            rst_n_synched_read                                      ;
//Configuration signals
logic 	                            csr_flip_output_rows                                    ;
logic 	    [CSR_WIDTH - 1 : 0]     csr_im_width                                            ;
logic 	    [CSR_WIDTH - 1 : 0]     csr_im_height                                           ;
//Status port of the lines captured 
logic 	                            status_line_captured    [WINDOW_SIZE]                   ;

//TB signals to handle the queue processing
int                                 golden_data_col_counter                                 ;
int                                 golden_data_row_counter                                 ;
int                                 real_data_col_counter                                   ;
int                                 real_data_row_counter                                   ;
logic		[DWIDTH - 1 : 0] 	    golden_data_queue       [WINDOW_SIZE]   [$]             ;
logic		[DWIDTH - 1 : 0] 	    golden_data_read        [WINDOW_SIZE]   [WINDOW_SIZE]   ;
logic		[DWIDTH - 1 : 0] 	    real_data_read          [WINDOW_SIZE]   [WINDOW_SIZE]   ;
int                                 errors                                                  ;
//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing dut section
line2window_wrapper
#
(
    .DWIDTH                         (DWIDTH                 ),      //Width of the bus for: data
    .AWIDTH                         (AWIDTH                 ),      //Width of the bus for: address (2**AWIDTH = MAX pixels in line)
    .FIFO_STYLE                     (FIFO_STYLE             ),      //0 - SCFIFO, 1 - DCFIFO
    .SYNC_RSTN                      (SYNC_RSTN              ),      //0 - async reset, 1 - synced to both write and read separately
    .WINDOW_SIZE                    (WINDOW_SIZE            ),      //Size of the window to be stored to the buffer
    .CSR_WIDTH                      (CSR_WIDTH              )       //Width of the control-setup registers
)
                                    i_line2window_wrapper
(
    //RST signlal
    .rst_n                          (rst_n                  ),

    //Write side signals declaration
    .clk_write                      (clk_write              ),
    .enable_write                   (enable_write           ),
    .data_write                     (data_write             ),
    .flag_full                      (flag_full              ),
    .rst_n_synched_write            (rst_n_synched_write    ),

    
    //Read side signals declaration
    .clk_read                       (clk_read               ),
    .enable_read                    (enable_read            ),
    .data_read                      (data_read              ),
    .flag_empty                     (flag_empty             ),
    .valid_read                     (valid_read             ),
    .rst_n_synched_read             (rst_n_synched_read     ),

    //Configuration signals
    .csr_flip_output_rows           (csr_flip_output_rows   ),
    .csr_im_width                   (csr_im_width           ),
    .csr_im_height                  (csr_im_height          ),

    //Status port of the lines captured 
    .status_line_captured           (status_line_captured   )
);
//End of instancing dut section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of clk generation section
initial
begin: clk_generation_clk_write
    clk_write = 0;
    forever #20 clk_write = !clk_write;
end

initial
begin: clk_generation_clk_read
    clk_read = 0;
    forever #10 clk_read = !clk_read;
end
//End of clk generation section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving queues to handle data section
initial begin: indexing_golden_queues
    golden_data_col_counter = '0;
    golden_data_row_counter = '0;
    while(1) begin
        @(posedge clk_write) begin
            if(enable_write)begin
                if(golden_data_col_counter == csr_im_width - 1)begin
                    if(golden_data_row_counter == csr_im_height - 1)begin
                        golden_data_col_counter <= '0;
                        golden_data_row_counter <= '0;
                    end
                    else begin
                        golden_data_col_counter <= '0;
                        golden_data_row_counter <= golden_data_row_counter + 1;
                    end
                end
                else begin
                    golden_data_col_counter <= golden_data_col_counter + 1;
                end
            end
            
        end
    end
end

initial begin: write_data_to_queues
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        golden_data_queue[i].delete();
    end

    while(1) begin
        @(posedge clk_write);
        if(enable_write)begin
            golden_data_queue[golden_data_row_counter].push_back(data_write);
        end
    end
end

initial begin: capture_data_from_module
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        for (int j = 0; j < WINDOW_SIZE; j++) begin
            real_data_read[i][j] = '0;
        end
    end

    while(1) begin
        @(posedge clk_read);
        if(valid_read)begin
            for (int i = 0; i < WINDOW_SIZE; i++) begin
                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    real_data_read[i][j] <= data_read[i][j];
                end
            end
        end
    end
end
//End of driving queues to handle data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of tasks to process the window reading section
task read_window_from_module();
    for(int i = 0; i < WINDOW_SIZE; i++) begin
        enable_read <= '1;
        @(posedge clk_read);
    end
    enable_read <= '0;

    repeat(10) @(posedge clk_read);
endtask

task read_window_from_queue();
    for (int i = 0; i < WINDOW_SIZE; i++) begin
        for (int j = 0; j < WINDOW_SIZE; j++) begin
            golden_data_read[i][WINDOW_SIZE - j - 1] <= golden_data_queue[i].pop_front();
        end
    end
endtask
//End of tasks to process the window reading section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section

initial begin: main_scenario
    enable_write = '0;
    data_write = '0;
    enable_read = '0;
    csr_flip_output_rows = '0;
    csr_im_width = 640;
    csr_im_height = 480;
    rst_n = '1;
    errors = '0;

    real_data_col_counter = '0;
    real_data_row_counter = '0;

    repeat(50) @(posedge clk_write);
    rst_n <= '0;
    while (1) begin
        @(posedge clk_write);
        if(rst_n_synched_write && rst_n_synched_read)begin
            break;
        end
    end

    @(posedge clk_write);
    rst_n <= '1;

    repeat(50) @(posedge clk_write);

    for (int iterations = 0; iterations < 25; iterations++) begin
        for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < csr_im_width; j++) begin
                    enable_write <= 1;
                    data_write <= $urandom_range(0, DWIDTH**2 - 1);
                    @(posedge clk_write);
                end
                enable_write <= '0;
                data_write <= '0;
                repeat(50) @(posedge clk_write);
            end

            repeat(50) @(posedge clk_read);

            for (int i = 0; i < csr_im_width/WINDOW_SIZE; i++) begin
                read_window_from_queue();
                read_window_from_module();

                repeat(30) @(posedge clk_read);

                for (int j = 0; j < WINDOW_SIZE; j++) begin
                    for (int k = 0; k < WINDOW_SIZE; k++) begin
                        @(posedge clk_read);
                        if(golden_data_read[i][j] != real_data_read[i][j])begin
                            errors++;
                        end
                    end
                end
            end
            repeat(50) @(posedge clk_read);
    end

    
    
    if(errors == 0) begin
        $display(">>>>> SUCCESS");    
    end
    else begin
        $display(">>>>> ERROR");    
    end
    $finish();
end

//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
