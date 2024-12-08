`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/06/2024 07:01:07 PM
// Design Name: 
// Module Name: BCD_sec_min
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module BCD_sec_min(
    input clk,          
    input reset,        
    input en, 
    output reg [6:0] segments, 
    output reg [3:0] anode);
    
 
    reg [3:0] order;
    wire clk_out;
    
    reg [1:0] count;
    
    clockDivider #(50000)clockdiv(clk, reset, en, clk_out);
    
    always @(posedge clk_out) begin    
        case(count)
        0: begin
        order <= score_l;
        anode <= 4'b1110;
        count <= count + 1;
        end
        1: begin
        order <= 15;
        anode <= 4'b0111;
        count <= count + 1;
        end
        2: begin
        order <= 15;
        anode <= 4'b1011;     
        count <= count + 1;
        end
        3: begin
        order <= score_r;
        anode <= 4'b1101;
        count <= 0;
        end
        
        endcase
        case(order)
        0: segments = 7'b0000001;
        1: segments = 7'b1001111;
        2: segments = 7'b0010010;
        3: segments = 7'b0000110;
        4: segments = 7'b1001100;
        5: segments = 7'b0100100;
        6: segments = 7'b0100000;
        7: segments = 7'b0001111;
        8: segments = 7'b0000000;
        9: segments = 7'b0000100;
	default: segments = 7'b1111111;
        endcase
    end
endmodule
