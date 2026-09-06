module clk_divider_wrapper
#
(
    parameter 	CSR_WIDTH 	= 32
)

(
    //Basic signals declaration
    input 	logic 		                clk                     ,
    input 	logic 		                rst_n                   ,

    //Generated clk signal
    output 	logic 	                    generated_clk           ,
    
    //Input csr register
    input 	logic 	[CSR_WIDTH-1:0] 	csr_control             ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_div_cnt_limit       ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_raise_pos           ,
    input 	logic 	[CSR_WIDTH-1:0] 	csr_fall_pos            ,

    //Status and errors signals
    output 	logic 	                    error_raise_fall
);

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of declaring local signals and parameters section

//Parsing control register bits
logic 	                    parsed_common_enable            ;  //csr_control[0]
logic 	                    parsed_freeze_state             ;  //csr_control[1]
logic 	                    parsed_use_half_prescale        ;  //csr_control[2]

//Clk division
logic 	[CSR_WIDTH-1:0] 	clk_division_counter            ;
logic 	                    clk_signal_divided              ;

//End of declaring local signals and parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of parsing parameters section
always_comb
begin
    parsed_common_enable                = csr_control[0];
    parsed_freeze_state                 = csr_control[1];
    parsed_use_half_prescale            = csr_control[2];
end
//End of parsing parameters section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving clk divider section
always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            clk_division_counter    <= '0;
        end
    else
        begin
            if(parsed_common_enable)begin
                if(parsed_use_half_prescale)begin
                    if(clk_division_counter == csr_div_cnt_limit-1 >> 1) begin
                        clk_division_counter <= '0;
                    end
                    else begin
                        clk_division_counter <= clk_division_counter + 1;
                    end
                end
                else begin
                    if(clk_division_counter == csr_div_cnt_limit-1) begin
                        clk_division_counter <= '0;
                    end
                    else begin
                        clk_division_counter <= clk_division_counter + 1;
                    end
                end
            end
            else begin
                if(!parsed_freeze_state)begin
                    clk_division_counter    <= '0;
                end
            end
        end
end

always_ff @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            clk_signal_divided  <= '0;
        end
    else begin
        if(parsed_common_enable)begin
            if(!error_raise_fall)begin
                if((clk_division_counter >= csr_raise_pos) && (clk_division_counter < csr_fall_pos))begin
                    clk_signal_divided  <= '1;
                end
                else begin
                    clk_signal_divided  <= '0;
                end
            end
            else begin
                clk_signal_divided  <= '0;
            end
            
        end
        else begin
            if(!parsed_freeze_state)begin
                clk_signal_divided  <= '0;
            end
        end
    end
end
//End of driving clk divider section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving status and error signals section
always_comb
begin
    generated_clk = clk_signal_divided;
end
//End of driving status and error signals section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
//Begin of driving output signal section
always_comb
begin
    error_raise_fall = (csr_raise_pos > csr_fall_pos) 
                    || ((csr_raise_pos > csr_div_cnt_limit-1 >> 1) && parsed_use_half_prescale)
                    || ((csr_fall_pos > csr_div_cnt_limit-1 >> 1) && parsed_use_half_prescale)
                    || ((csr_raise_pos > csr_div_cnt_limit-1) && !parsed_use_half_prescale)
                    || ((csr_fall_pos > csr_div_cnt_limit-1) && !parsed_use_half_prescale);
end
//End of driving output signal section
//^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
endmodule