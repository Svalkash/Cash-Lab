// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
// Date        : Mon Mar 21 13:03:39 2022
// Host        : DESKTOP-2B79PL0 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub d:/VivadoProjects/Lab1/Lab1.srcs/sources_1/ip/fifo_46/fifo_46_stub.v
// Design      : fifo_46
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_4,Vivado 2019.1" *)
module fifo_46(wr_clk, wr_rst, rd_clk, rd_rst, din, wr_en, rd_en, 
  dout, full, empty)
/* synthesis syn_black_box black_box_pad_pin="wr_clk,wr_rst,rd_clk,rd_rst,din[45:0],wr_en,rd_en,dout[45:0],full,empty" */;
  input wr_clk;
  input wr_rst;
  input rd_clk;
  input rd_rst;
  input [45:0]din;
  input wr_en;
  input rd_en;
  output [45:0]dout;
  output full;
  output empty;
endmodule
