`timescale 1ns/1ps

module tb_signal_synchronizer();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters of bin2gray_converter module section

parameter   int                 SYNCWIDTH       =    1;
parameter   int                 MAX_SYNC_IDX    =    5;

logic		                        clk_src         ;
logic		                        clk_dst         ;

// logic		[SYNCWIDTH - 1 : 0] 	data_src        ;
// logic		[SYNCWIDTH - 1 : 0] 	data_dst_s2f    [MAX_SYNC_IDX-2];
// logic		[SYNCWIDTH - 1 : 0] 	data_dst_f2s    [MAX_SYNC_IDX-2];

logic   data_src        ;
logic   data_dst_s2f    [MAX_SYNC_IDX-2];
logic   data_dst_f2s    [MAX_SYNC_IDX-2];

//End of declaring local signals and parameters of bin2gray_converter module section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk_src clock section

initial
begin : clk_src_generation_process
	clk_src = 0;
	forever #10 clk_src=~clk_src;
end

//End of generatring clk_src clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of generatring clk_dst clock section

initial
begin : clk_dst_generation_process
	clk_dst = 0;
	forever #2 clk_dst=~clk_dst;
end

//End of generatring clk_dst clock section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing isp_gamma_correction module section

generate
    genvar gv_s2f;
    for (gv_s2f = 2; gv_s2f < MAX_SYNC_IDX; gv_s2f++) begin: slow_to_fast_gen
        signal_synchronizer 
        #
        (
            .SYNCWIDTH          (SYNCWIDTH                  ),
            .SYNCSTEPS          (gv_s2f                     )
        )
                                i_signal_synchronizer_s2f
        (
            //Basic signals declaration
            .clk_src            (clk_src                    ),
            .clk_dst            (clk_dst                    ),

            .data_src           (data_src                   ),
            .data_dst           (data_dst_s2f   [gv_s2f-2]  )
        );
    end
endgenerate

generate
    genvar gv_f2s;
    for (gv_f2s = 2; gv_f2s < MAX_SYNC_IDX; gv_f2s++) begin: fast_to_slow_gen
        signal_synchronizer 
        #
        (
            .SYNCWIDTH          (SYNCWIDTH                  ),
            .SYNCSTEPS          (gv_f2s                     )
        )
                                i_signal_synchronizer_f2s
        (
            //Basic signals declaration
            .clk_src            (clk_dst                    ),
            .clk_dst            (clk_src                    ),

            .data_src           (data_src                   ),
            .data_dst           (data_dst_f2s   [gv_f2s-2]  )
        );
    end
endgenerate

//End of instancing isp_gamma_correction module section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of main scenario generation section
initial begin
    data_src = '0;
    
    for (int i = 0; i < 10; i++) begin
        #100ns;
        data_src = ~data_src;
    end

    $finish();
end
//End of main scenario generation section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
