`timescale 1ns/1ps

module tb_bin2gray_converter();

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters of bin2gray_converter module section

parameter   int                 DWIDTH  =    8;

logic		[DWIDTH - 1 : 0] 	data_input;
logic		[DWIDTH - 1 : 0] 	data_output;

int                             error_counter;
logic		[DWIDTH - 1 : 0] 	golden_data_output;

//End of declaring local signals and parameters of bin2gray_converter module section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of instancing isp_gamma_correction module section

common_ip_bin2gray_converter
#
(
    .DWIDTH         (DWIDTH         )
)
                    i_common_ip_bin2gray_converter
(
    .data_input     (data_input     ),
    .data_output    (data_output    ) 
);
//End of instancing isp_gamma_correction module section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of task to evaluate golden gray code section
task calcualte_golden_gray_code(input logic [DWIDTH-1:0] input_binary_code);
    golden_data_output = input_binary_code ^ (input_binary_code >> 1);
endtask
//End of task to evaluate golden gray code section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of main scenario generation section
initial begin
    data_input = '0;
    error_counter = '0;
    for (int i = 0; i < 2**DWIDTH; i++) begin
        data_input <= i;
        #10ns;
        calcualte_golden_gray_code(data_input);
        if(data_output != golden_data_output) begin
            error_counter++;
        end
    end

    if (error_counter != 0) begin
        $display(">>>>>");
        $display("ERROR");
        $display(">>>>>");
    end
    else begin
        $display(">>>>>");
        $display("SUCCESS");
        $display(">>>>>");
    end
    $finish();
end
//End of main scenario generation section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule
