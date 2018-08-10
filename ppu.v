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
*  Picture processing unit block.
***************************************************************************************************/

module ppu
(
  input  wire        clk_in,        // 100MHz system clock signal
  input  wire        rst_in,        // reset signal
  input  wire [ 2:0] ri_sel_in,     // register interface reg select
  input  wire        ri_ncs_in,     // register interface enable
  input  wire        ri_r_nw_in,    // register interface read/write select
  input  wire [ 7:0] ri_d_in,       // register interface data in
  input  wire [ 7:0] vram_d_in,     // video memory data bus (input)
  output wire        hsync_out,     // vga hsync signal
  output wire        vsync_out,     // vga vsync signal
  output wire [ 2:0] r_out,         // vga red signal
  output wire [ 2:0] g_out,         // vga green signal
  output wire [ 1:0] b_out,         // vga blue signal
  output wire [ 7:0] ri_d_out,      // register interface data out
  output wire        nvbl_out,      // /VBL (low during vertical blank)
  output wire [13:0] vram_a_out,    // video memory address bus
  output wire [ 7:0] vram_d_out,    // video memory data bus (output)
  output wire        vram_wr_out    // video memory read/write select
);

//
// PPU_VGA: VGA output block.
//
wire [5:0] vga_sys_palette_idx;
wire [9:0] vga_nes_x;
wire [9:0] vga_nes_y;
wire [9:0] vga_nes_y_next;
wire       vga_pix_pulse;
wire       vga_vblank;

ppu_vga ppu_vga_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .sys_palette_idx_in(vga_sys_palette_idx),
  .hsync_out(hsync_out),
  .vsync_out(vsync_out),
  .r_out(r_out),
  .g_out(g_out),
  .b_out(b_out),
  .nes_x_out(vga_nes_x),
  .nes_y_out(vga_nes_y),
  .nes_y_next_out(vga_nes_y_next),
  .pix_pulse_out(vga_pix_pulse),
  .vblank_out(vga_vblank)
);

wire [7:0] register_vram_data_in;
wire [7:0] register_palette_ram_data_in;
wire [7:0] register_sprite_ram_data_in;
wire       register_sprite_overflow;
wire       register_sprite_0_hit;
wire [1:0] register_nametable_select;
wire       register_increment_address_amount;
wire       register_sprite_pattern_table_select;
wire       register_pattern_table_select;
wire       register_sprite_size;
wire       register_nvbl;
wire       register_background_display;
wire       register_sprite_display;
wire       register_clip_sprite_left;
wire       register_clip_background_left;
wire       register_vblank;
wire [7:0] register_sprite_ram_address;
wire [2:0] register_fine_X;
wire [2:0] register_fine_Y;
wire [4:0] register_coarse_X;
wire [4:0] register_coarse_Y;
wire       register_update_counter;
wire       register_increment_address;
wire [7:0] register_sprite_ram_data_out;
wire [7:0] register_vram_data_out;
wire       register_vram_read_or_write_select;
wire       register_palette_ram_read_or_write_select;
wire       register_sprite_ram_read_or_write_select;

ppu_ri ppu_register
(
    .clock_in(clk_in),
    .reset_in(rst_in),
    .enable_in(ri_ncs_in),
    .read_or_write_select_in(ri_r_nw_in),
    .vblank_in(vga_vblank),
    .register_select_in(ri_sel_in),
    .data_in(ri_d_in),
    .vram_address_in(vram_a_out),
    .vram_data_in(register_vram_data_in),
    .palette_ram_data_in(register_palette_ram_data_in),
    .sprite_ram_data_in(register_sprite_ram_data_in),
    .sprite_overflow_in(register_sprite_overflow),
    .sprite_0_hit_in(register_sprite_0_hit),
    .nametable_select_out(register_nametable_select),
    .increment_address_amount_out(register_increment_address_amount),
    .sprite_pattern_table_select_out(register_sprite_pattern_table_select),
    .pattern_table_select_out(register_pattern_table_select),
    .sprite_size_out(register_sprite_size),
    .nvbl_out(register_nvbl),
    .background_display_out(register_background_display),
    .sprite_display_out(register_sprite_display),
    .clip_background_left_out(register_clip_sprite_left),
    .clip_sprite_left_out(register_clip_background_left),
    .vblank_out(register_vblank),
    .sprite_ram_address_out(register_sprite_ram_address),
    .data_out(ri_d_out),
    .fine_X_out(register_fine_X),
    .fine_Y_out(register_fine_Y),
    .coarse_X_out(register_coarse_X),
    .coarse_Y_out(register_coarse_Y),
    .update_counter_out(register_update_counter),
    .increment_address_out(register_increment_address),
    .vram_data_out(register_vram_data_out),
    .sprite_ram_data_out(register_sprite_ram_data_out),
    .vram_read_or_write_out(register_vram_read_or_write_select),
    .palette_ram_read_or_write_out(register_palette_ram_read_or_write_select),
    .sprite_ram_read_or_write_out(register_sprite_ram_read_or_write_select)
);
/*ppu_ri ppu_ri_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .sel_in(ri_sel_in),
  .ncs_in(ri_ncs_in),
  .r_nw_in(ri_r_nw_in),
  .cpu_d_in(ri_d_in),
  .vram_a_in(vram_a_out),
  .vram_d_in(register_vram_data_in),
  .pram_d_in(register_palette_ram_data_in),
  .vblank_in(vga_vblank),
  .spr_ram_d_in(register_sprite_ram_data_in),
  .spr_overflow_in(register_sprite_overflow),
  .spr_pri_col_in(register_sprite_0_hit),
  .cpu_d_out(ri_d_out),
  .vram_d_out(register_vram_data_out),
  .vram_wr_out(register_vram_read_or_write_select),
  .pram_wr_out(register_palette_ram_read_or_write_select),
  .fv_out(register_fine_Y),
  .vt_out(register_coarse_Y),
  .v_out(register_nametable_select[1]),
  .fh_out(register_fine_X),
  .ht_out(register_coarse_X),
  .h_out(register_nametable_select[0]),
  .s_out(register_pattern_table_select),
  .inc_addr_out(register_increment_address),
  .inc_addr_amt_out(register_increment_address_amount),
  .nvbl_en_out(register_nvbl),
  .vblank_out(register_vblank),
  .bg_en_out(register_background_display),
  .spr_en_out(register_sprite_display),
  .bg_ls_clip_out(register_clip_background_left),
  .spr_ls_clip_out(register_clip_sprite_left),
  .spr_h_out(register_sprite_size),
  .spr_pt_sel_out(register_sprite_pattern_table_select),
  .upd_cntrs_out(register_update_counter),
  .spr_ram_a_out(register_sprite_ram_address),
  .spr_ram_d_out(register_sprite_ram_data_out),
  .spr_ram_wr_out(register_sprite_ram_read_or_write_select)
);*/

wire [13:0] background_vram_address;
wire [3:0]  background_palette_index;

ppu_bg ppu_background(
  .clock_in(clk_in),
  .reset_in(rst_in),
  .background_display_in(register_background_display),
  .clip_background_left_in(register_clip_background_left),
  .fine_Y_in(register_fine_Y),
  .fine_X_in(register_fine_X),
  .coarse_X_in(register_coarse_X),
  .coarse_Y_in(register_coarse_Y),
  .nametable_select_in(register_nametable_select),
  .pattern_table_select_in(register_pattern_table_select),
  .current_x_in(vga_nes_x),
  .current_y_in(vga_nes_y),
  .next_y_in(vga_nes_y_next),
  .pix_pulse_in(vga_pix_pulse),
  .vram_data_in(vram_d_in),
  .update_counter_in(register_update_counter),
  .increment_address_in(register_increment_address),
  .increment_address_amount_in(register_increment_address_amount),
  .vram_address_out(background_vram_address),
  .palette_index_out(background_palette_index)
);

/*wire [13:0] bg_vram_a;
wire [ 3:0] bg_palette_idx;

ppu_bg ppu_bg_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(register_background_display),
  .ls_clip_in(register_clip_background_left),
  .fv_in(register_fine_Y),
  .vt_in(register_coarse_Y),
  .v_in(register_nametable_select[1]),
  .fh_in(register_fine_X),
  .ht_in(register_coarse_X),
  .h_in(register_nametable_select[0]),
  .s_in(register_pattern_table_select),
  .nes_x_in(vga_nes_x),
  .nes_y_in(vga_nes_y),
  .nes_y_next_in(vga_nes_y_next),
  .pix_pulse_in(vga_pix_pulse),
  .vram_d_in(vram_d_in),
  .ri_upd_cntrs_in(register_update_counter),
  .ri_inc_addr_in(register_increment_address),
  .ri_inc_addr_amt_in(register_increment_address_amount),
  .vram_a_out(bg_vram_a),
  .palette_idx_out(bg_palette_idx)
);*/


//
// PPU_SPR: PPU sprite generator block.
//
wire  [3:0] spr_palette_idx;
wire        spr_primary;
wire        spr_priority;
wire [13:0] spr_vram_a;
wire        spr_vram_req;

ppu_spr ppu_spr_blk(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .en_in(register_sprite_display),
  .ls_clip_in(register_clip_sprite_left),
  .spr_h_in(register_sprite_size),
  .spr_pt_sel_in(register_sprite_pattern_table_select),
  .oam_a_in(register_sprite_ram_address),
  .oam_d_in(register_sprite_ram_data_out),
  .oam_wr_in(register_sprite_ram_read_or_write_select),
  .nes_x_in(vga_nes_x),
  .nes_y_in(vga_nes_y),
  .nes_y_next_in(vga_nes_y_next),
  .pix_pulse_in(vga_pix_pulse),
  .vram_d_in(vram_d_in),
  .oam_d_out(register_sprite_ram_data_in),
  .overflow_out(register_sprite_overflow),
  .palette_idx_out(spr_palette_idx),
  .primary_out(spr_primary),
  .priority_out(spr_priority),
  .vram_a_out(spr_vram_a),
  .vram_req_out(spr_vram_req)
);

reg  [5:0] palette_ram [31:0];  // internal palette RAM.  32 entries, 6-bits per entry.
`define PRAM_A(addr) ((addr & 5'h03) ? addr :  (addr & 5'h0f)) //the mirror of address
//when rendering, the access to memory is inavailable, so store the palette there
always @(posedge clk_in)
begin
    if (rst_in)
    begin
        palette_ram[`PRAM_A(5'h00)] <= 6'h09;
        palette_ram[`PRAM_A(5'h01)] <= 6'h01;
        palette_ram[`PRAM_A(5'h02)] <= 6'h00;
        palette_ram[`PRAM_A(5'h03)] <= 6'h01;
        palette_ram[`PRAM_A(5'h04)] <= 6'h00;
        palette_ram[`PRAM_A(5'h05)] <= 6'h02;
        palette_ram[`PRAM_A(5'h06)] <= 6'h02;
        palette_ram[`PRAM_A(5'h07)] <= 6'h0d;
        palette_ram[`PRAM_A(5'h08)] <= 6'h08;
        palette_ram[`PRAM_A(5'h09)] <= 6'h10;
        palette_ram[`PRAM_A(5'h0a)] <= 6'h08;
        palette_ram[`PRAM_A(5'h0b)] <= 6'h24;
        palette_ram[`PRAM_A(5'h0c)] <= 6'h00;
        palette_ram[`PRAM_A(5'h0d)] <= 6'h00;
        palette_ram[`PRAM_A(5'h0e)] <= 6'h04;
        palette_ram[`PRAM_A(5'h0f)] <= 6'h2c;
        palette_ram[`PRAM_A(5'h11)] <= 6'h01;
        palette_ram[`PRAM_A(5'h12)] <= 6'h34;
        palette_ram[`PRAM_A(5'h13)] <= 6'h03;
        palette_ram[`PRAM_A(5'h15)] <= 6'h04;
        palette_ram[`PRAM_A(5'h16)] <= 6'h00;
        palette_ram[`PRAM_A(5'h17)] <= 6'h14;
        palette_ram[`PRAM_A(5'h19)] <= 6'h3a;
        palette_ram[`PRAM_A(5'h1a)] <= 6'h00;
        palette_ram[`PRAM_A(5'h1b)] <= 6'h02;
        palette_ram[`PRAM_A(5'h1d)] <= 6'h20;
        palette_ram[`PRAM_A(5'h1e)] <= 6'h2c;
        palette_ram[`PRAM_A(5'h1f)] <= 6'h08;
    end
    else if (register_palette_ram_read_or_write_select)
        palette_ram[`PRAM_A(vram_a_out[4:0])] <= register_vram_data_out[5:0];
end

assign register_vram_data_in = vram_d_in;
assign register_palette_ram_data_in = palette_ram[`PRAM_A(vram_a_out[4:0])];

assign vram_a_out  = (spr_vram_req) ? spr_vram_a : background_vram_address;
assign vram_d_out  = register_vram_data_out;
assign vram_wr_out = register_vram_read_or_write_select;

//
// Multiplexer.  Final system palette index derivation.
//
reg  q_pri_obj_col;
wire d_pri_obj_col;

always @(posedge clk_in)
  begin
    if (rst_in)
      q_pri_obj_col <= 1'b0;
    else
      q_pri_obj_col <= d_pri_obj_col;
  end

wire spr_foreground;
wire spr_trans;
wire bg_trans;

assign spr_foreground  = ~spr_priority;
assign spr_trans       = ~|spr_palette_idx[1:0];
assign bg_trans        = ~|background_palette_index[1:0];

assign d_pri_obj_col = (vga_nes_y_next == 0)                    ? 1'b0 :
                       (spr_primary && !spr_trans && !bg_trans) ? 1'b1 : q_pri_obj_col;

assign vga_sys_palette_idx =
  ((spr_foreground || bg_trans) && !spr_trans) ? palette_ram[{ 1'b1, spr_palette_idx }] :
  (!bg_trans)                                  ? palette_ram[{ 1'b0, background_palette_index }]  :
                                                 palette_ram[5'h00];

assign register_sprite_0_hit = q_pri_obj_col;

//
// Assign miscellaneous output signals.
//
assign nvbl_out = ~(register_vblank & register_nvbl);

endmodule