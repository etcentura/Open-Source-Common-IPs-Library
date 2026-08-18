module signal_synchronizer
#
(
    parameter	int                     SYNCWIDTH		=	1,
    parameter	int                     SYNCSTEPS		=	2
)

(
    //Basic signals declaration
    input		logic		                        clk_src     ,
    input		logic		                        clk_dst     ,

    input		logic		[SYNCWIDTH - 1 : 0] 	data_src    ,
    output		logic		[SYNCWIDTH - 1 : 0] 	data_dst
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section
logic		[SYNCWIDTH - 1 : 0] 	reg_src                 ;
logic		[SYNCWIDTH - 1 : 0] 	reg_dst [SYNCSTEPS]     ;
//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of checking input parameters secntion section
initial begin
    if(SYNCWIDTH <= 1) begin
        $error("Parameter SYNCWIDTH must NOT be more than 1");
    end
    $display("%m setup with parameter SYNCWIDTH         : %d", SYNCWIDTH    );

    if(SYNCSTEPS <= 0) begin
        $error("Parameter SYNCWSYNCSTEPSIDTH must NOT be equal or less than 0");
    end
    $display("%m setup with parameter SYNCSTEPS         : %d", SYNCSTEPS    );
end
//End of checking input parameters secntion section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of latching data by source reg section
always_ff @(posedge clk_src)
begin
    reg_src <= data_src;
end
//End of latching data by source reg section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of synchronizing signals section
always_ff @(posedge clk_dst)
begin
    reg_dst [0] <= reg_src;
    for (int i = 1; i < SYNCSTEPS; i++) begin
        reg_dst [i] <= reg_dst [i-1];
    end
end
//End of synchronizing signals section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of outputting data section
always_comb
begin
    data_dst = reg_dst[SYNCSTEPS - 1];
end
//End of outputting data section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

endmodule