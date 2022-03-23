----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.03.2022 21:29:53
-- Design Name: 
-- Module Name: fakeExtRam - fakeExtRam_arch
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity fakeExtRam is
    generic (
        A_WIDTH : integer := 5+7;
        D_WIDTH : integer := 32;
        LINE_WIDTH : integer := 16*8
    );
    port (
        clk     : in   std_logic;
        reset_n : in   std_logic;
        
        wdata   : in   std_logic_vector(D_WIDTH - 1 downto 0);
        addr    : in   std_logic_vector(A_WIDTH - 1 downto 0);
        avalid  : in   std_logic;
        rnw     : in   std_logic;
        
        ack     : out  std_logic;
        rdata   : out  std_logic_vector(D_WIDTH - 1 downto 0)
    );
end fakeExtRam;

architecture fakeExtRam_arch of fakeExtRam is
    type dataMem_t is array (natural range <>) of std_logic_vector (LINE_WIDTH - 1 downto 0);
    signal mem: dataMem_t (2**A_WIDTH - 1 downto 0) := (others => (others => '0'));
    signal addr_buf: integer;
    signal rw_cnt: integer := 0;
    signal rd: boolean := false;
    signal wr: boolean := false;
begin
    betterFake: process (clk, reset_n)
        variable aindex_slv: std_logic_vector (D_WIDTH - 1 downto 0);
    begin
        if (reset_n = '0') then
            rd <= false;
            wr <= false;
            ack <= '0';
            rw_cnt <= 0;
            for i in 0 to 2**A_WIDTH - 1 loop
                aindex_slv := std_logic_vector(to_unsigned(i, D_WIDTH));
                for j in 0 to 3 loop
                    mem(i)(D_WIDTH*(j+1) - 1 downto D_WIDTH*j) <= aindex_slv;
                end loop;
            end loop;
        elsif clk'event and clk = '1' then
            if (not rd) and (not wr) then
                ack <= '0';
                rdata <= (others => 'U');
                if avalid = '1' then
                    if rnw = '1' then
                        rd <= true;
                        rw_cnt <= -2; --delay before data
                    else
                        wr <= true;
                        mem(conv_integer(addr))(D_WIDTH - 1 downto 0) <= wdata;
                        rw_cnt <= 1; --because 0 is written HERE
                    end if;
                    addr_buf <= conv_integer(addr);
                end if;
            elsif wr then
                rdata <= (others => 'U');
                if rw_cnt < LINE_WIDTH / D_WIDTH then
                    mem(addr_buf)(D_WIDTH * (rw_cnt+1) - 1 downto D_WIDTH * rw_cnt) <= wdata;
                    rw_cnt <= rw_cnt + 1;
                    ack <= '0';
                else
                    ack <= '1';
                    rw_cnt <= 0;
                    wr <= false;
                end if;
            elsif rd then
                if rw_cnt < 0 then
                    ack <= '0';
                    rdata <= (others => 'U');
                    rw_cnt <= rw_cnt + 1;
                else
                    rdata <= mem(addr_buf)(D_WIDTH * (rw_cnt+1) - 1 downto D_WIDTH * rw_cnt);
                    ack <= '1';
                    if rw_cnt < LINE_WIDTH / D_WIDTH - 1 then
                        rw_cnt <= rw_cnt + 1;
                    else
                        rw_cnt <= 0;
                        rd <= false;
                    end if;
                end if;
            end if;
        end if;
    end process betterFake;

end fakeExtRam_arch;
