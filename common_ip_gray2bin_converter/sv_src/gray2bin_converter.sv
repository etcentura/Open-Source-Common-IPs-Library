module gray2bin_converter
#
(
    parameter		DWIDTH =    8
)

(
    input		logic		[DWIDTH - 1 : 0] 	data_input  ,
    output		logic		[DWIDTH - 1 : 0] 	data_output 
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of converting binary to gray code section
always_comb
begin
    data_output [DWIDTH - 1] = data_input [DWIDTH - 1];
    for (int i = DWIDTH - 2; i >= 0; i--) begin
        data_output [i] = data_input[i] ^ data_output[i+1];
    end
end
//End of converting binary to gray code section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule