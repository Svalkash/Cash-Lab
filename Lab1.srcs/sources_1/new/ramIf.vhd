----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.03.2022 11:30:49
-- Design Name: 
-- Module Name: ramIf - ramIf_arch
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ramIf is
    generic (
        A_WIDTH     : integer := 5+7;
        D_WIDTH     : integer := 16*8;
        RAM_D_WIDTH : integer := 32 --can't be changed
    );
    port (
        clk     : in    std_logic;
        reset_n : in    std_logic;
        addr    : in    std_logic_vector(A_WIDTH - 1 downto 0);
        wdata   : in    std_logic_vector(D_WIDTH - 1 downto 0);
        wr      : in    std_logic;
        rd      : in    std_logic;
        
        ack     : out   std_logic;
        rdata   : out   std_logic_vector(D_WIDTH - 1 downto 0);
        
        ram_clk     : in   std_logic;
        ram_reset_n : in   std_logic;
        ram_ack     : in   std_logic;
        ram_rdata   : in   std_logic_vector(RAM_D_WIDTH - 1 downto 0);
        
        ram_wdata   : out   std_logic_vector(RAM_D_WIDTH - 1 downto 0);
        ram_addr    : out   std_logic_vector(A_WIDTH - 1 downto 0);
        ram_avalid  : out   std_logic;
        ram_rnw     : out   std_logic
    );
end ramIf;

architecture ramIf_arch of ramIf is
    --generated FIFO - works for both directions
    COMPONENT fifo_32
      PORT (
        wr_clk : IN STD_LOGIC;
        wr_rst : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        rd_rst : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END COMPONENT;
    COMPONENT fifo_46
      PORT (
        wr_clk : IN STD_LOGIC;
        wr_rst : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        rd_rst : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(45 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(45 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END COMPONENT;
    --CU states
    type State_Type is (IDLE);
    signal state        : State_Type := IDLE;
    signal next_state   : State_Type;
    signal rw_cnt       : integer;
    --write side:
    signal wr_fifo_wr_rst   : std_logic;
    signal wr_fifo_rd_rst   : std_logic;
    signal wr_fifo_wr_en    : std_logic;
    signal wr_fifo_rd_en    : std_logic;
    signal wr_fifo_full     : std_logic;
    signal wr_fifo_empty    : std_logic;
    signal wr_fifo_din      : std_logic_vector(45 downto 0);
        alias wr_in_data    : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_din((RAM_D_WIDTH + A_WIDTH + 2) - 1 downto A_WIDTH + 2);
        alias wr_in_addr    : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_din((A_WIDTH + 2) - 1 downto 2);
        alias wr_in_avalid  : std_logic
            is wr_fifo_din(1);
        alias wr_in_rnw     : std_logic
            is wr_fifo_din(0);
    signal wr_fifo_dout     : std_logic_vector(45 downto 0);
        alias wr_out_data   : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_dout((RAM_D_WIDTH + A_WIDTH + 2) - 1 downto A_WIDTH + 2);
        alias wr_out_addr   : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_dout((A_WIDTH + 2) - 1 downto 2);
        alias wr_out_avalid : std_logic
            is wr_fifo_dout(1);
        alias wr_out_rnw    : std_logic
            is wr_fifo_dout(0);
            
    signal wr_shiftReg  : std_logic_vector(D_WIDTH - 1 downto 0) := (others => 'U');
    signal wr_sr_load   : std_logic;
    signal wr_sr_shift  : std_logic := '0';
    
    --read side:
    signal rd_fifo_wr_rst   : std_logic;
    signal rd_fifo_rd_rst   : std_logic;
    signal rd_fifo_wr_en    : std_logic;
    signal rd_fifo_rd_en    : std_logic;
    signal rd_fifo_full     : std_logic;
    signal rd_fifo_empty    : std_logic;
    signal rd_fifo_din      : std_logic_vector(31 downto 0);
    signal rd_fifo_dout     : std_logic_vector(31 downto 0);
    
    signal rd_shiftReg  : std_logic_vector(D_WIDTH - 1 downto 0) := (others => 'U');
    signal rd_sr_shift  : std_logic := '0';
    --write part:
    --get wr=1
    --wait for place in fifo
    --write 1
    --wait for place
    --write 2
    --...
    --wait for ack from ram (=any not empty? read it then?)
    --ack cache
    --
    --read part:
    --get rd=1
    --(wait for place)
    --write addr to fifo
    --(wait for ack = read not empty)
    --read 1
    --(wait for ack = read not empty)
    --read 2
    --...
    --ack immediately when shiftreg is ready (last clock?)
    --ah fuck it, i'll use counters instead
begin
    --FIFO instances
    wr_fifo: fifo_46
        port map (
            wr_clk  => clk,
            rd_clk  => ram_clk,
            wr_rst  => wr_fifo_wr_rst,
            rd_rst  => wr_fifo_rd_rst,
            wr_en   => wr_fifo_wr_en,
            rd_en   => wr_fifo_rd_en,
            full    => wr_fifo_full,
            empty   => wr_fifo_empty,
            din     => wr_fifo_din,
            dout    => wr_fifo_dout
        );
    rd_fifo: fifo_32
        port map (
            wr_clk  => ram_clk,
            rd_clk  => clk,
            wr_rst  => rd_fifo_wr_rst,
            rd_rst  => rd_fifo_rd_rst,
            wr_en   => rd_fifo_wr_en,
            rd_en   => rd_fifo_rd_en,
            full    => rd_fifo_full,
            empty   => rd_fifo_empty,
            din     => rd_fifo_din,
            dout    => rd_fifo_dout
        );
    --obvious assignments - write side
    wr_fifo_wr_rst  <= not reset_n;
    wr_fifo_rd_rst  <= not ram_reset_n;
    wr_fifo_rd_en   <= not rd_fifo_empty;
    wr_in_data      <= wr_shiftReg(RAM_D_WIDTH - 1 downto 0);
    --obvious assignments - read side
    rd_fifo_rd_rst  <= not reset_n;
    rd_fifo_wr_rst  <= not ram_reset_n;
    rd_fifo_wr_en   <= ram_ack; --directly
    rdata <= rd_shiftReg;
    
    --shift regs
    wr_sr_p: process(clk)
        if clk'event and clk = '1' then
            if wr_sr_load = '1' then
                wr_shiftReg <= wdata;
            elsif wr_sr_shift = '1' then -- cycle shift because why not
                wr_shiftReg <= wr_shiftReg(RAM_D_WIDTH - 1 downto 0) & wr_shiftReg(D_WIDTH - 1 downto RAM_D_WIDTH);
            end if;
        end if;
    end process: wr_sr_p
    
    rd_sr_p: process(clk)
        if clk'event and clk = '1' and wr_sr_shift = '1' then -- cycle shift because why not
            wr_shiftReg <= rd_fifo_dout & rd_shiftReg(D_WIDTH - 1 downto RAM_D_WIDTH));
        end if;
    end process: wr_sr_p
    
    --state machine - next state
    sm_next: process(state)
        
    end process: sm_next

end ramIf_arch;
