`timescale 1ns / 1ps

module pong_graph(
    input clk,  
    input reset,    
    input [3:0] btn,        // btn[0|3] = up, btn[1|2] = down
    input gra_still,        // still graphics - newgame, game over states
    input video_on,
    input vel_switch,
    input [9:0] x,
    input [9:0] y,
    output graph_on,

    output reg missl,missr,   // ball hit or miss
    output reg [11:0] graph_rgb
    );
    
    // maximum x, y values in display area
    parameter X_MAX = 639;
    parameter Y_MAX = 479;
    
    // create 60Hz refresh tick
    wire refresh_tick;
    assign refresh_tick = ((y == 481) && (x == 0)) ? 1 : 0; // start of vsync(vertical retrace)
    
    
    // WALLS
    // LEFT wall boundaries
//    parameter L_WALL_L = 32;    
//    parameter L_WALL_R = 39;    // 8 pixels wide
    // TOP wall boundaries
    parameter T_WALL_T = 0;    
    parameter T_WALL_B = 7;    // 8 pixels wide
    // BOTTOM wall boundaries
    parameter B_WALL_T = 472;    
    parameter B_WALL_B = 479;    // 8 pixels wide
    
    
    
    // PADDLE
    // paddle horizontal boundaries
    parameter X_PAD_L = 600;
    parameter X_PAD_R = 603;    // 4 pixels wide
    
    parameter X_PAD_L2 = 50;
    parameter X_PAD_R2 = 53;    // 4 pixels wide
    // paddle vertical boundary signals
    wire [9:0] y_pad_t, y_pad_b;
    wire [9:0] y_pad_t2, y_pad_b2;
    parameter PAD_HEIGHT = 72;  // 72 pixels high
    // register to track top boundary and buffer
    reg [9:0] y_pad_reg = 204;      // Paddle starting position
    reg [9:0] y_pad_next;
    reg [9:0] y_pad_reg2 = 204;      // Paddle starting position
    reg [9:0] y_pad_next2;
    // paddle moving velocity when a button is pressed
    parameter PAD_VELOCITY = 3;     // change to speed up or slow down paddle movement
    
    
    // BALL
    // square rom boundaries
    parameter BALL_SIZE = 8;
    // ball horizontal boundary signals
    wire [9:0] x_ball_l, x_ball_r;
    // ball vertical boundary signals
    wire [9:0] y_ball_t, y_ball_b;
    // register to track top left position
    reg [9:0] y_ball_reg, x_ball_reg;
    // signals for register buffer
    wire [9:0] y_ball_next, x_ball_next;
    // registers to track ball speed and buffers
    reg [9:0] x_delta_reg, x_delta_next;
    reg [9:0] y_delta_reg, y_delta_next;
    // positive or negative ball velocity
    parameter BALL_VELOCITY_POS = 1;    // ball speed positive pixel direction(down, right)
    parameter BALL_VELOCITY_NEG = -1;   // ball speed negative pixel direction(up, left)
    parameter BALL_VELOCITY_POS2 = 2;    // ball speed positive pixel direction(down, right)
    parameter BALL_VELOCITY_NEG2 = -2;   // ball speed negative pixel direction(up, left)
    // round ball from square image
    wire [2:0] rom_addr, rom_col;   // 3-bit rom address and rom column
    reg [7:0] rom_data;             // data at current rom address
    wire rom_bit;                   // signify when rom data is 1 or 0 for ball rgb control
    

    
    // Register Control
    always @(posedge clk or posedge reset)
        if(reset) begin
            y_pad_reg <= 204;
            y_pad_reg2 <= 204;
            x_ball_reg <= 0;
            y_ball_reg <= 0;
            x_delta_reg <= 10'h002;
            y_delta_reg <= 10'h002;
        end
        else begin
            y_pad_reg <= y_pad_next;
            y_pad_reg2 <= y_pad_next2;
            x_ball_reg <= x_ball_next;
            y_ball_reg <= y_ball_next;
            x_delta_reg <= x_delta_next;
            y_delta_reg <= y_delta_next;
        end
    
    
    // ball rom
    always @*
        case(rom_addr)
            3'b000 :    rom_data = 8'b00111100; //   ****  
            3'b001 :    rom_data = 8'b01111110; //  ******
            3'b010 :    rom_data = 8'b11111111; // ********
            3'b011 :    rom_data = 8'b11111111; // ********
            3'b100 :    rom_data = 8'b11111111; // ********
            3'b101 :    rom_data = 8'b11111111; // ********
            3'b110 :    rom_data = 8'b01111110; //  ******
            3'b111 :    rom_data = 8'b00111100; //   ****
        endcase
        
//     assign BALL_VELOCITY_POS = vel_switch? 2:1;
//     assign BALL_VELOCITY_NEG = vel_switch? -2:-1;
    
    
    // OBJECT STATUS SIGNALS
    wire l_wall_on, t_wall_on, b_wall_on, pad_on, sq_ball_on, ball_on;
    wire [11:0] wall_rgb, pad_rgb, ball_rgb, bg_rgb;
    
    
    // pixel within wall boundaries
//    assign l_wall_on = ((L_WALL_L <= x) && (x <= L_WALL_R)) ? 1 : 0;
    assign t_wall_on = ((T_WALL_T <= y) && (y <= T_WALL_B)) ? 1 : 0;
    assign b_wall_on = ((B_WALL_T <= y) && (y <= B_WALL_B)) ? 1 : 0;
    
    
    // assign object colors
assign wall_rgb   = 12'h000;    //  walls
assign pad_rgb    = 12'h000;    //  paddle
assign ball_rgb   = 12'h000;    //  ball
assign bg_rgb     = 12'h0ff;    //  background
    
    
    // paddle 
    assign y_pad_t = y_pad_reg;                             // paddle top position
    assign y_pad_t2 = y_pad_reg2;    
    assign y_pad_b = y_pad_t + PAD_HEIGHT - 1;              // paddle bottom position
    assign y_pad_b2 = y_pad_t2 + PAD_HEIGHT - 1;              // paddle bottom position
    assign pad_on = (X_PAD_L2 <= x) && (x <= X_PAD_R2) && (y_pad_t2 <= y) && (y <= y_pad_b2) || (X_PAD_L <= x) && (x <= X_PAD_R) &&     // pixel within paddle boundaries
                    (y_pad_t <= y) && (y <= y_pad_b);
       
                    
    // Paddle Control
    always @* begin
        y_pad_next = y_pad_reg;     // no move
        y_pad_next2 = y_pad_reg2;     // no move
        
        if(refresh_tick)
            //right paddle
            if(btn[1] & (y_pad_b < (B_WALL_T - 1 - PAD_VELOCITY)))
                y_pad_next = y_pad_reg + PAD_VELOCITY;  // move down
                
            else if(btn[0] & (y_pad_t > (T_WALL_B - 1 - PAD_VELOCITY)))
                y_pad_next = y_pad_reg - PAD_VELOCITY;  // move up
            
            //left paddle
            else if(btn[2] & (y_pad_b2 < (B_WALL_T - 1 - PAD_VELOCITY)))
                y_pad_next2 = y_pad_reg2 + PAD_VELOCITY;  // move down
                
            else if(btn[3] & (y_pad_t2 > (T_WALL_B - 1 - PAD_VELOCITY)))
                y_pad_next2 = y_pad_reg2 - PAD_VELOCITY;  // move up
    end
    
    
    // rom data square boundaries
    assign x_ball_l = x_ball_reg;
    assign y_ball_t = y_ball_reg;
    assign x_ball_r = x_ball_l + BALL_SIZE - 1;
    assign y_ball_b = y_ball_t + BALL_SIZE - 1;
    // pixel within rom square boundaries
    assign sq_ball_on = (x_ball_l <= x) && (x <= x_ball_r) &&
                        (y_ball_t <= y) && (y <= y_ball_b);
    // map current pixel location to rom addr/col
    assign rom_addr = y[2:0] - y_ball_t[2:0];   // 3-bit address
    assign rom_col = x[2:0] - x_ball_l[2:0];    // 3-bit column index
    assign rom_bit = rom_data[rom_col];         // 1-bit signal rom data by column
    // pixel within round ball
    assign ball_on = sq_ball_on & rom_bit;      // within square boundaries AND rom data bit == 1
 
  
    // new ball position
    assign x_ball_next = (gra_still) ? X_MAX / 2 :
                         (refresh_tick) ? x_ball_reg + x_delta_reg : x_ball_reg;
    assign y_ball_next = (gra_still) ? Y_MAX / 2 :
                         (refresh_tick) ? y_ball_reg + y_delta_reg : y_ball_reg;
    
    // change ball direction after collision
    always @* begin
        missl = 1'b0;
        missr = 1'b0;
        x_delta_next = x_delta_reg;
        y_delta_next = y_delta_reg;
        
        if(gra_still) begin
        
            if (vel_switch) begin
            x_delta_next = BALL_VELOCITY_NEG2;
            y_delta_next = BALL_VELOCITY_POS2;
            end
            else if (!vel_switch) begin
            x_delta_next = BALL_VELOCITY_NEG;
            y_delta_next = BALL_VELOCITY_POS;
            end
        end
        
        else if(y_ball_t < T_WALL_B) begin                   // reach top
            if (vel_switch) begin
            y_delta_next = BALL_VELOCITY_POS2;
            end
            else if (!vel_switch) begin
            y_delta_next = BALL_VELOCITY_POS;
            end
        end
        else if(y_ball_b > (B_WALL_T)) begin        // reach bottom wall
              if (vel_switch) begin
            y_delta_next = BALL_VELOCITY_NEG2;
            end
            else if (!vel_switch) begin
            y_delta_next = BALL_VELOCITY_NEG;
            end
        end
//        else if(x_ball_l <= L_WALL_R)           // reach left wall
//            x_delta_next = BALL_VELOCITY_POS;   // move right
        
        else if((X_PAD_L <= x_ball_r) && (x_ball_r <= X_PAD_R) &&
                (y_pad_t <= y_ball_b) && (y_ball_t <= y_pad_b)) 
                begin
                if (vel_switch) begin
                x_delta_next = BALL_VELOCITY_NEG2;
            end
            else if (!vel_switch) begin
                x_delta_next = BALL_VELOCITY_NEG;
            end
                    
                end
        else if((X_PAD_R2 >= x_ball_l) &&
                (x_ball_r >= X_PAD_L2) &&
                (y_pad_t2 <= y_ball_b) && 
                (y_ball_t <= y_pad_b2)) 
                begin
                if (vel_switch) begin
                x_delta_next = BALL_VELOCITY_POS2;
                end
                else if (!vel_switch) begin
                x_delta_next = BALL_VELOCITY_POS;
             end
                 end  
        
        else if(x_ball_r > X_MAX)
            missr = 1; //if we collide with right wall, we increment the left counter
//            miss = 1'b1; //useless
        else if(x_ball_l < 2)
            missl = 1;
    end                    
    
    // output status signal for graphics 
    assign graph_on = l_wall_on | t_wall_on | b_wall_on | pad_on | ball_on;
    
    
    // rgb multiplexing circuit
    always @*
        if(~video_on)
            graph_rgb = 12'h000;      // no value, blank
        else
            if(l_wall_on | t_wall_on | b_wall_on)
                graph_rgb = wall_rgb;     // wall color
            else if(pad_on)
                graph_rgb = pad_rgb;      // paddle color
            else if(ball_on)
                graph_rgb = ball_rgb;     // ball color
            else
                graph_rgb = bg_rgb;       // background
       
endmodule
