`timescale 1ns / 1ps


module pong_top(
    input clk,              // 100MHz
    input reset,            // btnR
    input [3:0] btn_out,      // btnD, btnU
    input data,             // input data from nes controller to FPGA
    input vel_switch,
	output latch,
	output nes_clk,  
    output hsync,           // to VGA Connector
    output vsync,           // to VGA Connector
    output [11:0] rgb,       // to DAC, to VGA Connector
    output reg [6:0] segments,
    output reg [3:0] anode
    );
    
    // state declarations for 4 states
    parameter newgame = 2'b00;
    parameter play    = 2'b01;
    parameter newball = 2'b10;
    parameter over    = 2'b11;
        
//    wire [1:0] btn_out;    
        
    // signal declaration
    reg [1:0] state_reg, state_next;
    wire [9:0] w_x, w_y;
    wire w_vid_on, w_p_tick, graph_on, missr, missl;
    wire [3:0] text_on;
    wire [11:0] graph_rgb, text_rgb;
    reg [11:0] rgb_reg, rgb_next;
    wire [3:0] dig_l, dig_r;
    reg gra_still, d_clr, timer_start;
    reg d_inc_l, d_inc_r;
    wire timer_tick, timer_up;
    reg [3:0] ball_reg, ball_next;
    
//    Debouncer d1(clk, reset, btn[0], btn_out[0]);
//    Debouncer d2(clk, reset, btn[1], btn_out[1]);



//7 SEG

    reg [3:0] order;
    wire clk_out;
    reg [1:0] count;
    
    clockDivider #(5000)clockdiv(clk, reset, 1, clk_out);
    
    always @(posedge clk_out) begin    
        case(count)
        0: begin
        order <= dig_r;
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
        order <= dig_l;
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




    // Module Instantiations
    vga_controller vga_unit(
        .clk_100MHz(clk),
        .reset(reset),
        .video_on(w_vid_on),
        .hsync(hsync),
        .vsync(vsync),
        .p_tick(w_p_tick),
        .x(w_x),
        .y(w_y));
    
    pong_text text_unit(
        .clk(clk),
        .x(w_x),
        .y(w_y),
        .dig0(dig_l),
        .dig1(dig_r),
        .ball(ball_reg),
        .text_on(text_on),
        .text_rgb(text_rgb));
        
    pong_graph graph_unit(
        .clk(clk),
        .reset(reset),
        .btn(btn_out),
        .gra_still(gra_still),
        .video_on(w_vid_on),
        .vel_switch(vel_switch),
        .x(w_x),
        .y(w_y),
        .missr(missr),
        .missl(missl),
        .graph_on(graph_on),
        .graph_rgb(graph_rgb));
    
    // 60 Hz tick when screen is refreshed
    assign timer_tick = (w_x == 0) && (w_y == 0);
    timer timer_unit(
        .clk(clk),
        .reset(reset),
        .timer_tick(timer_tick),
        .timer_start(timer_start),
        .timer_up(timer_up));
    
    m100_counter counter_unit(
        .clk(clk),
        .reset(reset),
        .d_inc_l(d_inc_l),
        .d_inc_r(d_inc_r),
        .d_clr(d_clr),
        .dig_l(dig_l),
        .dig_r(dig_r));
    
       
    // FSMD state and registers
    always @(posedge clk or posedge reset)
        if(reset) begin
            state_reg <= newgame;
            ball_reg <= 0;
            rgb_reg <= 0;
        end
    
        else begin
            state_reg <= state_next;
            ball_reg <= ball_next;
            if(w_p_tick)
                rgb_reg <= rgb_next;
        end
    
    // FSMD next state logic
    always @* begin
        gra_still = 1'b1;
        timer_start = 1'b0;
        d_inc_l = 1'b0;
        d_inc_r = 1'b0;
        d_clr = 1'b0;
        state_next = state_reg;
        ball_next = ball_reg;
        
        case(state_reg)
            newgame: begin
                ball_next = 4'd9;          // 9 balls
                d_clr = 1'b1;               // clear score
                
                if(btn_out != 4'b0000) begin      // button pressed
                    state_next = play;
                end
            end
            
            play: begin
                gra_still = 1'b0;   // animated screen
                

                
                if(missr & ~missl) begin
                    if(ball_reg == 0)
                        state_next = over;
                    
                    else begin
                        state_next = newball;
                        ball_next = ball_reg - 1; 
                        d_inc_r =1;
                 
                    end
                
                
                    timer_start = 1'b1;     // 2 sec timer
                end
                else if(~missr & missl) begin
                    if(ball_reg == 0)
                         state_next = over;
                        
                    else begin
                        state_next = newball;
                        ball_next = ball_reg - 1; 
                        d_inc_l =1;
                 
                    end
                    
                    
                        timer_start = 1'b1;     // 2 sec timer
                    end      
               end
            
            newball: // wait for 2 sec and until button pressed
            if(timer_up && (btn_out != 4'b0000))
                state_next = play;
                
            over:   // wait 2 sec to display game over
                if(timer_up)
                    state_next = newgame;
        endcase           
    end
    
    // rgb multiplexing
    always @*
        if(~w_vid_on)
            rgb_next = 12'h000; // blank
        
        else
            if(text_on[3] || ((state_reg == newgame) && text_on[1]) || ((state_reg == over) && text_on[0]))
                rgb_next = text_rgb;    // colors in pong_text
            
            else if(graph_on)
                rgb_next = graph_rgb;   // colors in graph_text
                
            else if(text_on[2])
                rgb_next = text_rgb;    // colors in pong_text
                
            else
                rgb_next = 12'h0ff;     // aqua background
    
    // output
    assign rgb = rgb_reg;
    
endmodule
