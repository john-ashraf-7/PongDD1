`timescale 1ns / 1ps


module m100_counter(
    input clk,
    input reset,
    input d_inc_l, d_inc_r, d_clr,
    output  [3:0] dig_l, dig_r
    );
    
    // signal declaration
    reg [3:0] curr_dig_l, curr_dig_r, dig_l_next, dig_r_next;
    
    // register control
    always @(posedge clk or posedge reset)
        if(reset) begin
            curr_dig_r <= 0;
            curr_dig_l <= 0;
        end
        
        else begin
            curr_dig_r <= dig_r_next;
            curr_dig_l <= dig_l_next;
        end
    
    // next state logic
    always @* begin
        dig_l_next = curr_dig_l;
        dig_r_next = curr_dig_r;
        
        if(d_clr) begin
            dig_l_next <= 0;
            dig_r_next <= 0;
        end
        
        //incrementing left
        else if(d_inc_l)
        begin
            if(curr_dig_l == 9)
                dig_l_next = 0;
                
            else    // dig0 != 9
                dig_l_next = curr_dig_l + 1;
        end
        
        //incrementing right
        else if(d_inc_r)
        begin
        if(curr_dig_r == 9)
                    dig_r_next = 0;
                else
                    dig_r_next = curr_dig_r + 1;
    end
    end
    // output
    assign dig_l = curr_dig_l;
    assign dig_r = curr_dig_r;
    
endmodule
