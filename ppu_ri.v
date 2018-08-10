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
*  Picture processing unit register block.
***************************************************************************************************/

module ppu_ri
( 
    input wire        clock_in,                         
    input wire        reset_in,                     
    input wire        enable_in,                        
    input wire        read_or_write_select_in,         
    input wire        vblank_in,                        
    input wire [2:0]  register_select_in,
    input wire [7:0]  data_in,
    input wire [13:0] vram_address_in,
    input wire [7:0]  vram_data_in,
    input wire [7:0]  palette_ram_data_in,
    input wire [7:0]  sprite_ram_data_in,
    input wire        sprite_overflow_in,
    input wire        sprite_0_hit_in,
    //$2000
    output wire [1:0] nametable_select_out,
    output wire       increment_address_amount_out,
    output wire       sprite_pattern_table_select_out,
    output wire       pattern_table_select_out,
    output wire       sprite_size_out,
    output wire       nvbl_out,
    //$2001
    output wire       background_display_out,
    output wire       sprite_display_out,
    output wire       clip_background_left_out, 
    output wire       clip_sprite_left_out,
    //$2002
    output wire       vblank_out,
    //$2003 $2004
    output wire [7:0] sprite_ram_address_out,
    output wire [7:0] data_out,
    //$2005 $2006
    output wire [2:0] fine_X_out,
    output wire [2:0] fine_Y_out,
    output wire [4:0] coarse_X_out,
    output wire [4:0] coarse_Y_out,
    //$2007
    output wire       update_counter_out, 
    output reg        increment_address_out,
    output reg [7:0]  vram_data_out,
    output reg [7:0]  sprite_ram_data_out,
    output reg        vram_read_or_write_out,
    output reg        palette_ram_read_or_write_out,    
    output reg        sprite_ram_read_or_write_out
);

//define reg 
//q---the final output, consistent of d and input   d---store the last period value, always change
//$2000
reg [1:0] q_nametable_select,       d_nametable_select;                 //$2000[1:0]
reg q_increment_address_amount,     d_increment_address_amount;         //$2000[2]
reg q_sprite_pattern_table_select,  d_sprite_pattern_table_select;      //$2000[3]
reg q_pattern_table_select,         d_pattern_table_select;             //$2000[4]
reg q_sprite_size,                  d_sprite_size;                      //$2000[5]
reg q_nvbl,                         d_nvbl;                             //$2000[7]
//$2001
reg q_background_display,       d_background_display;                   //$2001[1]
reg q_sprite_display,           d_sprite_display;                       //$2001[2]
reg q_clip_sprite_left,         d_clip_sprite_left;                     //$2001[3]
reg q_clip_background_left,     d_clip_background_left;                 //$2001[4]
//$2002
reg q_vblank,               d_vblank;   
reg q_read_or_write_time,   d_read_or_write_time;                     
//$2003 $2004
reg [7:0] q_sprite_ram_address,     d_sprite_ram_address;
reg [7:0] q_data_out,               d_data_out;
//$2005 $2006
reg [2:0] q_fine_X,     d_fine_X;
reg [2:0] q_fine_Y,     d_fine_Y;
reg [4:0] q_coarse_X,   d_coarse_X;
reg [4:0] q_coarse_Y,   d_coarse_Y;
//$2007  
reg q_update_counter_out,               d_update_counter_out;  
reg [7:0] q_vram_data_out,              d_vram_data_out;
reg [7:0] q_buffer,                     d_buffer;
reg q_buffer_update,                    d_buffer_update;

reg q_enable_in;                  
reg q_vblank_in;               

//set default value
always @(posedge clock_in)
begin  
    if (reset_in)
    begin
        q_nametable_select              <= 2'b00;
        q_increment_address_amount      <= 1'b0;
        q_sprite_pattern_table_select   <= 1'b0;
        q_pattern_table_select          <= 1'b0;
        q_sprite_size                   <= 1'b0;
        q_nvbl                          <= 1'b0;
        q_background_display            <= 1'b0;
        q_sprite_display                <= 1'b0;       
        q_clip_background_left          <= 1'b0;
        q_clip_sprite_left              <= 1'b0;
        q_vblank                        <= 1'b0;
        q_read_or_write_time            <= 1'b0;
        q_sprite_ram_address            <= 8'h00;
        q_data_out                      <= 8'h00;
        q_fine_X                        <= 3'b000;
        q_fine_Y                        <= 3'b000;
        q_coarse_X                      <= 5'b00000;
        q_coarse_Y                      <= 5'b00000;
        q_update_counter_out            <= 1'b0;                                                        
        q_enable_in                     <= 1'b1;
        q_vblank_in                     <= 1'b0;
        q_buffer                        <= 8'h00;
        q_buffer_update                 <= 1'b0;
    end
    else
    begin
        q_nametable_select              <= d_nametable_select;
        q_increment_address_amount      <= d_increment_address_amount;
        q_sprite_pattern_table_select   <= d_sprite_pattern_table_select;
        q_pattern_table_select          <= d_pattern_table_select;
        q_sprite_size                   <= d_sprite_size;
        q_nvbl                          <= d_nvbl;
        q_background_display            <= d_background_display;
        q_sprite_display                <= d_sprite_display;
        q_clip_background_left          <= d_clip_background_left;
        q_clip_sprite_left              <= d_clip_sprite_left;
        q_vblank                        <= d_vblank;
        q_read_or_write_time            <= d_read_or_write_time;
        q_sprite_ram_address            <= d_sprite_ram_address;
        q_data_out                      <= d_data_out;
        q_fine_X                        <= d_fine_X;
        q_fine_Y                        <= d_fine_Y;
        q_coarse_X                      <= d_coarse_X;
        q_coarse_Y                      <= d_coarse_Y;
        q_update_counter_out            <= d_update_counter_out; 
        q_enable_in                     <= enable_in;
        q_vblank_in                     <= vblank_in;
        q_buffer                        <= d_buffer;
        q_buffer_update                 <= d_buffer_update;
    end
end

//modify reg
always @*
begin
    d_nametable_select                  = q_nametable_select;
    d_increment_address_amount          = q_increment_address_amount;
    d_sprite_pattern_table_select       = q_sprite_pattern_table_select;
    d_pattern_table_select              = q_pattern_table_select;
    d_sprite_size                       = q_sprite_size;
    d_nvbl                              = q_nvbl;
    d_background_display                = q_background_display;
    d_sprite_display                    = q_sprite_display;
    d_clip_background_left              = q_clip_background_left;
    d_clip_sprite_left                  = q_clip_sprite_left;
    if (vblank_in & ~q_vblank_in)       
        d_vblank = 1'b1;                //         __case2__
    else                                //   case1|         \case3
    begin                               // ______|           \_______
        if(vblank_in)                   // case1: vblank_in == 1; q_vblank_in == 0 ---- d_vblabk = 1
            d_vblank = q_vblank;        // case2: vblank_in == 1; q_vblank_in == 1 ---- d_vblank = q_blank
        else                            // case3: vblank_in == 0; q_vblank_in == 1 ---- d_vblank = 0
            d_vblank = 1'b0;
    end
    d_read_or_write_time                = q_read_or_write_time;
    d_sprite_ram_address                = q_sprite_ram_address;
    d_data_out                          = q_data_out;    
    sprite_ram_data_out                 = 8'h00;
    sprite_ram_read_or_write_out        = 1'b0;
    d_fine_X                            = q_fine_X;
    d_fine_Y                            = q_fine_Y;
    d_coarse_X                          = q_coarse_X;
    d_coarse_Y                          = q_coarse_Y;
    d_update_counter_out                = 1'b0;
    vram_data_out                       = 8'h00;
    increment_address_out               = 1'b0;
    palette_ram_read_or_write_out       = 1'b0;
    vram_read_or_write_out              = 1'b0;
    d_buffer                            = (q_buffer_update) ? vram_data_in : q_buffer;
    d_buffer_update                     = 1'b0;

    if (q_enable_in & ~enable_in)//work when the last periodenable_in is 0 and this period enable_in is 1(this is, trigger in fall edge)
    begin
        //write----get data from data_in then assign to the register  read----get data_out from register
        case (register_select_in)
        //$2000 PPUCRTRL write
        //VPHB SINN
        //|||| ||++- Base nametable address(0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
        //|||| |+--- VRAM address increment per CPU read/write of PPUDATA(0: add 1, going across; 1: add 32, going down)
        //|||| +---- Sprite pattern table address for 8x8 sprites(0: $0000; 1: $1000; ignored in 8x16 mode)
        //|||+------ Background pattern table address (0: $0000; 1: $1000)
        //||+------- Sprite size (0: 8x8; 1: 8x16)
        //|+-------- PPU master/slave select(0: read backdrop from EXT pins; 1: output color on EXT pins)(no use)
        //+--------- Generate an NMI at the start of the vertical blanking interval (0: off; 1: on)
        3'b000:
        begin
            d_nametable_select              = data_in[1:0];
            d_increment_address_amount      = data_in[2];
            d_sprite_pattern_table_select   = data_in[3];
            d_pattern_table_select          = data_in[4];
            d_sprite_size                   = data_in[5];
            d_nvbl                          = data_in[7];
        end
        //$2001 PPUMASK write
        //BGRs bMmG
        //|||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)(no use)
        //|||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
        //|||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
        //|||| +---- 1: Show background
        //|||+------ 1: Show sprites
        //||+------- Emphasize red*(no use)
        //|+-------- Emphasize green*(no use)
        //+--------- Emphasize blue*(no use)
        3'b001:
        begin
            d_background_display    = data_in[1];
            d_sprite_display        = data_in[2];
            d_clip_background_left  = ~data_in[3];
            d_clip_sprite_left      = ~data_in[4];
        end
        //$2002 PPUSTATUS read
        //VSO. ....
        //|||| ||||
        //|||+-++++- Least significant bits previously written into a PPU register (due to register not being updated for this address)
        //||+------- Sprite overflow. 
        //|+-------- Sprite 0 Hit.
        //+--------- Vertical blank has started (0: not in vblank; 1: in vblank).
        3'b010:
        begin
            d_data_out[7]           = q_vblank;
            d_data_out[6]           = sprite_0_hit_in;
            d_data_out[5]           = sprite_overflow_in;
            d_data_out[4:0]         = 5'b00000;
            d_read_or_write_time    = 1'b0;
            d_vblank                = 1'b0;
        end
        //$2003 OAMADDR write
        //Write the address of OAM you want to access, write the address of sprite and store it
        3'b011:
        begin
            d_sprite_ram_address = data_in;
        end
        //$2004 OAMDATA read/write
        //Write OAM data here. Writes will increment OAMADDR after the write
        //reads during vertical or forced blanking return the value from OAM at that address but do not increment.
        3'b100:
        begin
            if (~read_or_write_select_in)//write, write the data of sprite and store it, increment OAMADDR
            begin
                sprite_ram_data_out           = data_in;
                sprite_ram_read_or_write_out  = 1'b1;
                d_sprite_ram_address            = q_sprite_ram_address + 8'b00000001;
            end
            else//read
            begin
                d_data_out = sprite_ram_data_in;
            end
        end
        //$2005 PPUSCROLL write*2
        //write the horizontal and vertical scroll offsets here just before turning on the screen
        3'b101:
        begin
            d_read_or_write_time = ~q_read_or_write_time;
            if (d_read_or_write_time)//the first time(horizontal scroll, X)
            begin
                d_fine_X    = data_in[2:0];
                d_coarse_X  = data_in[7:3];
            end
            else// the second time(vertical scroll, Y)
            begin
                d_fine_Y    = data_in[2:0];
                d_coarse_Y  = data_in[7:3];
            end
        end
        //$2006 PPUADDR write*2
        //After reading PPUSTATUS to reset the address latch, write the 16-bit address of VRAM you want to access here, upper byte first.
        //actually, it has only 14 bits, so the first time write the upper 6 bits and then write the lower 8 bits
        //yyy NN YYYYY XXXXX
        //||| || ||||| +++++ -- coarse X scroll
        //||| || +++++ -------- coarse Y scroll
        //||| ++ -------------- namestable select
        //+++ ----------------- fine Y scroll(it's no use)
        3'b110:
        begin
            d_read_or_write_time = ~q_read_or_write_time;                 
            if (d_read_or_write_time)// the first time(the upper 6 bits)                          
            begin                              
                d_coarse_Y[4:3]     = data_in[1:0];
                d_nametable_select  = data_in[3:2];
                d_fine_Y[2]         = 1'b0;
                d_fine_Y[1:0]       = data_in[5:4];
            end
            else
            begin//the second time(the lower 8 bits)
                d_coarse_X              = data_in[4:0];
                d_coarse_Y[2:0]         = data_in[7:5];
                d_update_counter_out    = 1'b1;
            end
        end
        //$2007 PPUDATA read/write
        //VRAM read/write data register. After access, the video memory address will increment by an amount determined by $2000:2.
        //$0-$3EFF VRAM address, the read will return the contents of an internal read buffer, This internal buffer is updated only when reading PPUDATA,
        //$3F00-$3FFF reading palette data.Reading the palettes still updates the internal buffer though, but the data placed in it is the mirrored nametable data that would appear "underneath" the palette
        3'b111:
        begin
            if (~read_or_write_select_in)//write
            begin
                vram_data_out = data_in;
                increment_address_out = 1'b1;
                if (vram_address_in[13:8] == 6'b111111)//palette data
                    palette_ram_read_or_write_out = 1'b1;
                else
                    vram_read_or_write_out = 1'b1;
            end
            else//read
            begin
                if (vram_address_in[13:8] == 6'b111111)
                    d_data_out = palette_ram_data_in;
                else
                    //d_data_out = vram_data_in;
                    d_data_out = q_buffer;
                d_buffer_update         = 1'b1;
                increment_address_out   = 1'b1;
            end
        end
        endcase
    end
end

//modify wire out
assign nametable_select_out             = q_nametable_select;
assign increment_address_amount_out     = q_increment_address_amount;
assign sprite_pattern_table_select_out  = q_sprite_pattern_table_select;
assign pattern_table_select_out         = q_pattern_table_select;
assign sprite_size_out                  = q_sprite_size;
assign nvbl_out                         = q_nvbl;
assign background_display_out           = q_background_display;
assign sprite_display_out               = q_sprite_display;
assign clip_background_left_out         = q_clip_background_left;
assign clip_sprite_left_out             = q_clip_sprite_left;
assign vblank_out                       = q_vblank;
assign sprite_ram_address_out           = q_sprite_ram_address;
assign data_out                         = (~enable_in & read_or_write_select_in) ? q_data_out : 8'h00;
assign fine_X_out                       = q_fine_X;
assign fine_Y_out                       = q_fine_Y;
assign coarse_X_out                     = q_coarse_X;
assign coarse_Y_out                     = q_coarse_Y;
assign update_counter_out               = q_update_counter_out;

endmodule