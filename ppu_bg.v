/***************************************************************************************************
** fpga_nes/hw/src/ppu/ppu.v
*
*  Copyright (c) 2012, Brian Bennett
*  All rights reserved.
*
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
*  Picture processing unit background block.
***************************************************************************************************/

module ppu_bg
(
    input wire        clock_in,
    input wire        reset_in,
    input wire        background_display_in,
    input wire        clip_background_left_in,
    input wire [2:0]  fine_Y_in,
    input wire [2:0]  fine_X_in,
    input wire [4:0]  coarse_X_in,
    input wire [4:0]  coarse_Y_in,
    input wire [1:0]  nametable_select_in,
    input wire        pattern_table_select_in,
    input wire [9:0]  current_x_in,
    input wire [9:0]  current_y_in,
    input wire [9:0]  next_y_in,
    input wire        pix_pulse_in,             //if pulse_flag is 1,then you should output the color of the pixel
    input wire [7:0]  vram_data_in,
    input wire        update_counter_in,
    input wire        increment_address_in,
    input wire        increment_address_amount_in,
    output reg [13:0] vram_address_out,
    output wire [3:0] palette_index_out
);

reg [2:0] q_fine_Y,             d_fine_Y;
reg [4:0] q_coarse_X,           d_coarse_X;
reg [4:0] q_coarse_Y,           d_coarse_Y;
reg [1:0] q_nametable_select,   d_nametable_select;

reg [7:0] q_nametable_address,          d_nametable_address;
reg [1:0] q_attribute_table_data,       d_attribute_table_data;
reg [7:0] q_palette_data_0,             d_palette_data_0;
reg [7:0] q_palette_data_1,             d_palette_data_1;

reg [15:0] q_bit_shift_0,   d_bit_shift_0;
reg [15:0] q_bit_shift_1,   d_bit_shift_1;
reg [8:0] q_bit_shift_2,    d_bit_shift_2;
reg [8:0] q_bit_shift_3,    d_bit_shift_3;

reg increment_vertical_counter;     //move to the next scanline
reg update_vertical_counter;        //update, when come to the last line or update_in is set
reg increment_horizontal_counter;   //move to the next tile(render 8 pixels)
reg update_horizontal_counter;      //update, when come to the last column or update_in is set

reg vram_address_select;

wire clip;

always @(posedge clock_in)
begin 
    if (reset_in)
    begin
        q_fine_Y                    <= 3'b000;
        q_coarse_X                  <= 5'b00000;
        q_coarse_Y                  <= 5'b00000;
        q_nametable_select          <= 2'b00;
        q_nametable_address         <= 8'h00;
        q_attribute_table_data      <= 2'b00;
        q_palette_data_0            <= 8'h00;
        q_palette_data_1            <= 8'h00;
        q_bit_shift_0               <= 16'h0000;
        q_bit_shift_1               <= 16'h0000;
        q_bit_shift_2               <= 9'h000;
        q_bit_shift_3               <= 9'h000;
    end
    else
    begin
        q_fine_Y                    <= d_fine_Y;
        q_coarse_X                  <= d_coarse_X;
        q_coarse_Y                  <= d_coarse_Y;
        q_nametable_select          <= d_nametable_select;
        q_nametable_address         <= d_nametable_address;
        q_attribute_table_data      <= d_attribute_table_data;
        q_palette_data_0            <= d_palette_data_0;
        q_palette_data_1            <= d_palette_data_1;
        q_bit_shift_0               <= d_bit_shift_0;
        q_bit_shift_1               <= d_bit_shift_1;
        q_bit_shift_2               <= d_bit_shift_2;
        q_bit_shift_3               <= d_bit_shift_3;
    end
end 

//Visible scanlines (0-239)
//1.Cycles 1-256
//The data for each tile is fetched during this phase. 
//Each memory access takes 2 PPU cycles to complete, and 4 must be performed per tile:
//  Nametable byte
//  Attribute table byte
//  Tile bitmap low
//  Tile bitmap high (+8 bytes from tile bitmap low)
//2.Cycles 257-320
//The tile data for the sprites on the next scanline are fetched here. 
//Again, each memory access takes 2 PPU cycles to complete, and 4 are performed for each of the 8 sprites:
//  Garbage nametable byte
//  Garbage nametable byte
//  Tile bitmap low
//  Tile bitmap high (+8 bytes from tile bitmap low)
//3.Cycles 321-336
//This is where the first two tiles for the next scanline are fetched, and loaded into the shift registers. 
//Again, each memory access takes 2 PPU cycles to complete, and 4 are performed for the two tiles:
//  Nametable byte
//  Attribute table byte
//  Tile bitmap low
//  Tile bitmap high (+8 bytes from tile bitmap low)
//4.Cycles 337-340
//Two bytes are fetched, but the purpose for this is unknown. These fetches are 2 PPU cycles each.
//  Nametable byte
//  Nametable byte

always @*
begin
    d_nametable_address     = q_nametable_select;
    d_attribute_table_data  = q_attribute_table_data;
    d_palette_data_0        = q_palette_data_0;
    d_palette_data_1        = q_palette_data_1;
    d_bit_shift_0           = q_bit_shift_0;
    d_bit_shift_1           = q_bit_shift_1;
    d_bit_shift_2           = q_bit_shift_2;
    d_bit_shift_3           = q_bit_shift_3;
    vram_address_select     = 3'b100;
    if (background_display_in)
    begin
        if((current_y_in < 239) || (next_y_in == 0))
        begin
            if ((current_x_in < 256) || ((current_x_in >= 320 && current_x_in < 336)))
            begin
                 //cycle 1-256 and cycle 320-336
                //need to read the Nametable byte, Attribute table byte, Tile bitmap low, Tile bitmap high
                //2 16-bit shift registers - These contain the bitmap data for two tiles. 
                //Every 8 cycles, the bitmap data for the next tile is loaded into the upper 8 bits of this shift register. 
                //Meanwhile, the pixel to render is fetched from one of the lower 8 bits.
                //2 8-bit shift registers - These contain the palette attributes for the lower 8 pixels of the 16-bit shift register. 
                //These registers are fed by a latch which contains the palette attribute for the next tile. 
                //Every 8 cycles, the latch is loaded with the palette attribute for the next tile.
                if (pix_pulse_in)
                begin//shift the upper 8 bits to the lower 8 bits
                    d_bit_shift_0 = {1'b0, q_bit_shift_0[15:1]};
                    d_bit_shift_1 = {1'b0, q_bit_shift_1[15:1]};
                    d_bit_shift_2 = {q_bit_shift_2[8], q_bit_shift_2[8:1]};
                    d_bit_shift_3 = {q_bit_shift_3[8], q_bit_shift_3[8:1]};       
                    if (current_x_in[2:0] == 3'h7)//every cycle(render 8 pixels) renew the value of register, move to the next tile
                    begin
                        //bitmap data for the next tile loaded into the upper 8 bits
                        //4(2*2)tile's palette number is the same
                        d_bit_shift_0[15]   = q_palette_data_0[0];
                        d_bit_shift_0[14]   = q_palette_data_0[1];                  //the order is opposite:
                        d_bit_shift_0[13]   = q_palette_data_0[2];                  //the coordinate
                        d_bit_shift_0[12]   = q_palette_data_0[3];                  // 0 ----------> 
                        d_bit_shift_0[11]   = q_palette_data_0[4];                  //the bit count
                        d_bit_shift_0[10]   = q_palette_data_0[5];                  // <---------- 0
                        d_bit_shift_0[ 9]   = q_palette_data_0[6];
                        d_bit_shift_0[ 8]   = q_palette_data_0[7];
                        d_bit_shift_1[15]   = q_palette_data_1[0];
                        d_bit_shift_1[14]   = q_palette_data_1[1];
                        d_bit_shift_1[13]   = q_palette_data_1[2];
                        d_bit_shift_1[12]   = q_palette_data_1[3];
                        d_bit_shift_1[11]   = q_palette_data_1[4];
                        d_bit_shift_1[10]   = q_palette_data_1[5];
                        d_bit_shift_1[ 9]   = q_palette_data_1[6];
                        d_bit_shift_1[ 8]   = q_palette_data_1[7];
                        d_bit_shift_2[8]    = q_attribute_table_data[0];
                        d_bit_shift_3[8]    = q_attribute_table_data[1]; 
                    end                
                end
                case (current_x_in[2:0])
                3'b000:
                begin
                    vram_address_select = 3'b000;
                    d_nametable_address = vram_data_in;
                end
                3'b001:
                begin
                    vram_address_select     = 3'b001;
                    d_attribute_table_data  = vram_data_in >> {q_coarse_Y[1], q_coarse_X[1], 1'b0};
                    //value = (topleft << 0) | (topright << 2) | (bottomleft << 4) | (bottomright << 6)
                    //7654 3210
                    //|||| ||++- Color bits 3-2 for top left quadrant of this byte
                    //|||| ++--- Color bits 3-2 for top right quadrant of this byte
                    //||++------ Color bits 3-2 for bottom left quadrant of this byte
                    //++-------- Color bits 3-2 for bottom right quadrant of this byte
                end
                3'b010:
                begin
                    vram_address_select = 3'b010;
                    d_palette_data_0    = vram_data_in;
                end
                3'b011:
                begin
                    vram_address_select = 3'b011;
                    d_palette_data_1    = vram_data_in;
                end
                endcase
            end
        end
    end
end
    
always @*
begin
    update_vertical_counter         = 1'b0;
    increment_vertical_counter      = 1'b0;
    update_horizontal_counter       = 1'b0;
    increment_horizontal_counter    = 1'b0;
    if (background_display_in)
    begin
        if ((current_y_in < 239) || (next_y_in == 0))
        begin
            if (pix_pulse_in && (current_x_in == 319))
            begin
                update_horizontal_counter = 1'b1;
                if (next_y_in != current_y_in)
                begin
                    if (next_y_in == 0)
                        update_vertical_counter = 1'b1;
                    else
                        increment_vertical_counter = 1'b1;
                end
            end
            if (pix_pulse_in && (current_x_in[2:0] == 3'h7))
            begin
                increment_horizontal_counter = 1'b1;
            end
        end
    end
end

//change the coordinate
always @*
begin
    d_fine_Y            = q_fine_Y;
    d_coarse_X          = q_coarse_X;
    d_coarse_Y          = q_coarse_Y;
    d_nametable_select  = q_nametable_select;
    if (increment_address_in)
    begin
        if (increment_address_amount_in)//add 32
        begin 
            {d_fine_Y, d_nametable_select, d_coarse_Y} = {q_fine_Y, q_nametable_select, q_coarse_Y} + 10'b001;
        end
        else//add 1
        begin
            {d_fine_Y, d_nametable_select, d_coarse_Y, d_coarse_X} = {q_fine_Y, q_nametable_select, q_coarse_Y, q_coarse_X} + 15'h0001;
        end
    end
    else
    begin
        if (increment_horizontal_counter)
        begin
            {d_nametable_select[0], d_coarse_X} = {q_nametable_select[0], q_coarse_X} + 6'b000001;
        end
        if (increment_vertical_counter)
        begin
            if (q_coarse_Y == 5'b11101 && q_fine_Y == 3'b111)//the last line
            begin
                d_fine_Y                = 3'b000;
                d_nametable_select[1]   = ~q_nametable_select[1];
                d_nametable_select[0]   = q_nametable_select[0];
                d_coarse_X              = q_coarse_X;
                d_coarse_Y              = 5'b00000;
            end
            else
                {d_nametable_select[1], d_coarse_Y, d_fine_Y} = {q_nametable_select[1], q_coarse_Y, q_fine_Y} + 9'h001;
        end
        if (update_vertical_counter)
        begin
            d_fine_Y                = fine_Y_in;
            d_coarse_Y              = coarse_Y_in;
            d_nametable_select[1]   = nametable_select_in[1];
        end
        if (update_horizontal_counter)
        begin
            d_coarse_X              = coarse_X_in;
            d_nametable_select[0]   = nametable_select_in[0];
        end
        if (update_counter_in)
        begin
            d_fine_Y                = fine_Y_in;
            d_coarse_X              = coarse_X_in;
            d_coarse_Y              = coarse_Y_in;
            d_nametable_select      = nametable_select_in;
        end
    end
end 

//store the address    
always @*
begin  
    //store the address
    //yyy NN YYYYY XXXXX nametable
    //||| || ||||| +++++ -- coarse X scroll
    //||| || +++++ -------- coarse Y scroll
    //||| ++ -------------- namestable select
    //+++ ----------------- fine Y scroll(it's no use)
    case(vram_address_select)
    3'b000://nametable
    begin
        vram_address_out[13:12] = 2'b10;
        vram_address_out[11:10] = q_nametable_select;
        vram_address_out[9:5]   = q_coarse_Y;
        vram_address_out[4:0]   = q_coarse_X;
    end
    //NN 1111 YYY XXX
    //|| |||| ||| +++-- high 3 bits of coarse X (x/4)
    //|| |||| +++------ high 3 bits of coarse Y (y/4)
    //|| ++++---------- attribute offset (960 bytes)
    //++--------------- nametable select
    3'b001://attribute table
    begin
        vram_address_out[13:12] = 2'b10;
        vram_address_out[11:10] = q_nametable_select;
        vram_address_out[9:6]   = 4'b1111;
        vram_address_out[5:3]   = q_coarse_Y[4:2];
        vram_address_out[2:0]   = q_coarse_X[4:2];
    end
    //0HRRRR CCCCPTTT pattern table
    //|||||| |||||+++ -- Fine Y offset, the row number within a tile 
    //|||||| ||||+ ----- Bit plane (0: "lower"; 1: "upper") 
    //|||||| ++++ ------ Tile column  
    //||++++ ----------- Tile row    
    //|+ --------------- Half of sprite table (0: "left"; 1: "right") 
    //+ ---------------- 0: Pattern table is at $0000-$1FFF
    3'b010://pattern table 0
    begin
        vram_address_out[13]    = 1'b0;
        vram_address_out[12]    = pattern_table_select_in;
        vram_address_out[11:4]  = q_nametable_address;
        vram_address_out[3]     = 1'b0;
        vram_address_out[2:0]   = q_fine_Y;
    end
    3'b011://pattern table 1
    begin
        vram_address_out[13]    = 1'b0;
        vram_address_out[12]    = pattern_table_select_in;
        vram_address_out[11:4]  = q_nametable_address;
        vram_address_out[3]     = 1'b1;
        vram_address_out[2:0]   = q_fine_Y;
    end
    //yyy NN YYYYY XXXXX nametable
    //||| || ||||| +++++ -- coarse X scroll
    //||| || +++++ -------- coarse Y scroll
    //||| ++ -------------- namestable select
    //+++ ----------------- fine Y scroll(it's no use)
    3'b100://rgister
    begin
        vram_address_out[13:12] = q_fine_Y[1:0];
        vram_address_out[11:10] = q_nametable_select;
        vram_address_out[9:5]   = q_coarse_Y;
        vram_address_out[4:0]   = q_coarse_X;
    end
    endcase
end

assign clip = clip_background_left_in && (current_x_in >= 10'h000) && (current_x_in < 10'h008);
assign palette_index_out = (!clip && background_display_in) ? {q_bit_shift_3[fine_X_in], q_bit_shift_2[fine_X_in], q_bit_shift_1[fine_X_in], q_bit_shift_0[fine_X_in]} : 4'b0000;
    
endmodule
