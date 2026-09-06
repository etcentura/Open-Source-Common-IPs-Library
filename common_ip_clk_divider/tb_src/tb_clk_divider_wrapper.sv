`timescale 1ns/1ps

module tb_clk_divider_wrapper();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local singals and parameters for fifo section

parameter 	CSR_WIDTH 	= 32;
parameter   GENERATORS_NUMBER = 8;

//Basic signals declaration
logic 		                clk                                             ;
logic 		                rst_n                                           ;
//Generated clk signal
logic 	                    generated_clk           [GENERATORS_NUMBER]     ;
//Input csr register
logic 	[CSR_WIDTH-1:0] 	csr_control             [GENERATORS_NUMBER]     ;
logic 	[CSR_WIDTH-1:0] 	csr_div_cnt_limit       [GENERATORS_NUMBER]     ;
logic 	[CSR_WIDTH-1:0] 	csr_raise_pos           [GENERATORS_NUMBER]     ;
logic 	[CSR_WIDTH-1:0] 	csr_fall_pos            [GENERATORS_NUMBER]     ;
//Status and errors signals
logic 	                    error_raise_fall        [GENERATORS_NUMBER]     ;

parameter   logic [CSR_WIDTH-1:0] csr_control_set [GENERATORS_NUMBER] = '{
                                                        32'h00000001,  // {29'd0, 1'b0, 1'b0, 1'b1}
                                                        32'h00000003,  // {29'd0, 1'b0, 1'b1, 1'b1}
                                                        32'h00000005,  // {29'd0, 1'b1, 1'b0, 1'b1}
                                                        32'h00000007,  // {29'd0, 1'b1, 1'b1, 1'b1}
                                                        32'h00000001,  // Повтор
                                                        32'h00000003,  // Повтор
                                                        32'h00000005,  // Повтор
                                                        32'h00000007   // Повтор
                                                    };

parameter   logic [CSR_WIDTH-1:0] csr_div_cnt_limit_set [GENERATORS_NUMBER] = '{
                                                        100                     ,
                                                        500                     ,
                                                        1000                    ,
                                                        5000                    ,
                                                        10000                   ,
                                                        50000                   ,
                                                        100000                  ,
                                                        500000                  
                                                    };

parameter   logic [CSR_WIDTH-1:0] csr_raise_pos_set [GENERATORS_NUMBER] = '{
                                                        30,
                                                        250,
                                                        250,
                                                        1200,
                                                        1000,
                                                        1,
                                                        22000,
                                                        7000
                                                    };

parameter   logic [CSR_WIDTH-1:0] csr_fall_pos_set [GENERATORS_NUMBER] = '{
                                                        80,
                                                        470,
                                                        470,
                                                        2300,
                                                        9000,
                                                        48000,
                                                        25000,
                                                        120000
                                                    };
//End of declaring local singals and parameters for fifo section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing module section section
generate
    genvar i;
    for (i = 0; i < GENERATORS_NUMBER; i++) begin: generate_modules
        clk_divider_wrapper
        #
        (
            .CSR_WIDTH              (CSR_WIDTH)
        )
                                    i_clk_divider_wrapper
        (
            //Basic signals declaration
            .clk                    (clk                    ),
            .rst_n                  (rst_n                  ),

            //Generated clk signal
            .generated_clk          (generated_clk[i]       ),
            
            //Input csr register
            .csr_control            (csr_control[i]         ),
            .csr_div_cnt_limit      (csr_div_cnt_limit[i]   ),
            .csr_raise_pos          (csr_raise_pos[i]       ),
            .csr_fall_pos           (csr_fall_pos[i]        ),

            //Status and errors signals
            .error_raise_fall       (error_raise_fall[i]    )
        );
    end
endgenerate
//End of instancing module section section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk clock section
//Writing is faster than reading
initial
begin : clk_generation_process
	clk = 0;
	forever #5 clk=~clk;
end
//End of generatring clk clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generating main scenario section
initial begin: main
    for (int j = 0; j < GENERATORS_NUMBER; j++) begin
        csr_control             [j]     = csr_control_set       [j];
        csr_div_cnt_limit       [j]     = csr_div_cnt_limit_set [j];
        csr_raise_pos           [j]     = csr_raise_pos_set     [j];
        csr_fall_pos            [j]     = csr_fall_pos_set      [j];
    end

    rst_n = '1;

    repeat(50) @(posedge clk);
    rst_n <= '0;
    repeat(50) @(posedge clk);
    rst_n <= '1;

    #5ms $finish();
end
//End of generating main scenario section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule

