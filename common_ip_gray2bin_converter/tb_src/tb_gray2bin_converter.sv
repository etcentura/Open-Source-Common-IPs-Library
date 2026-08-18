`timescale 1ns/1ps

module tb_gray2bin_converter();

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

jpeg_gray2bin_converter
#
(
    .DWIDTH         (DWIDTH         )
)
                    i_jpeg_gray2bin_converter
(
    .data_input     (data_input     ),
    .data_output    (data_output    ) 
);
//End of instancing isp_gamma_correction module section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of task to evaluate golden gray code section
task calcualte_golden_binary_code(input logic [DWIDTH-1:0] input_gray_code);
    bit [DWIDTH-1:0] mask;

    mask = input_gray_code;
    golden_data_output = input_gray_code;

    while(mask) begin
        mask = mask >> 1;
        golden_data_output = golden_data_output ^ mask;
    end

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
        calcualte_golden_binary_code(data_input);
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
