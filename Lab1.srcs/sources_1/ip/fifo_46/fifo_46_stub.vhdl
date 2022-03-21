-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.1 (win64) Build 2552052 Fri May 24 14:49:42 MDT 2019
-- Date        : Mon Mar 21 13:03:39 2022
-- Host        : DESKTOP-2B79PL0 running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub d:/VivadoProjects/Lab1/Lab1.srcs/sources_1/ip/fifo_46/fifo_46_stub.vhdl
-- Design      : fifo_46
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7z020clg484-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fifo_46 is
  Port ( 
    wr_clk : in STD_LOGIC;
    wr_rst : in STD_LOGIC;
    rd_clk : in STD_LOGIC;
    rd_rst : in STD_LOGIC;
    din : in STD_LOGIC_VECTOR ( 45 downto 0 );
    wr_en : in STD_LOGIC;
    rd_en : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 45 downto 0 );
    full : out STD_LOGIC;
    empty : out STD_LOGIC
  );

end fifo_46;

architecture stub of fifo_46 is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "wr_clk,wr_rst,rd_clk,rd_rst,din[45:0],wr_en,rd_en,dout[45:0],full,empty";
attribute x_core_info : string;
attribute x_core_info of stub : architecture is "fifo_generator_v13_2_4,Vivado 2019.1";
begin
end;
