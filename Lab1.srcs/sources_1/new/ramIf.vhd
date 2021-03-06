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
    --latched inputs
    signal addr_latch   : std_logic_vector(A_WIDTH - 1 downto 0);
    --CU states
    type State_Type is (IDLE, WAIT_READ, WRITE_ADDR, WRITE_DATA, READ_DATA, SHOW_ACK);
    --extra ADWAIT_RD to avoid storing RnW info
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
    signal wr_cmd_cleared   : std_logic := '1'; --for clearing rnw and avalid after 1 clock
    signal wr_fifo_din      : std_logic_vector(45 downto 0);
        alias wr_in_data    : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_din((RAM_D_WIDTH + A_WIDTH + 2) - 1 downto A_WIDTH + 2);
        alias wr_in_addr    : std_logic_vector(A_WIDTH - 1 downto 0)
            is wr_fifo_din((A_WIDTH + 2) - 1 downto 2);
        alias wr_in_avalid  : std_logic
            is wr_fifo_din(1);
        alias wr_in_rnw     : std_logic
            is wr_fifo_din(0);
    signal wr_fifo_dout     : std_logic_vector(45 downto 0);
        alias wr_out_data   : std_logic_vector(RAM_D_WIDTH - 1 downto 0)
            is wr_fifo_dout((RAM_D_WIDTH + A_WIDTH + 2) - 1 downto A_WIDTH + 2);
        alias wr_out_addr   : std_logic_vector(A_WIDTH - 1 downto 0)
            is wr_fifo_dout((A_WIDTH + 2) - 1 downto 2);
        alias wr_out_avalid : std_logic
            is wr_fifo_dout(1);
        alias wr_out_rnw    : std_logic
            is wr_fifo_dout(0);
            
    signal wr_shiftReg  : std_logic_vector(D_WIDTH - 1 downto 0) := (others => 'U');
    signal wr_sr_load   : std_logic;
    signal wr_sr_shift  : std_logic;
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
    wr_fifo_rd_en   <= not wr_fifo_empty;
    wr_in_data      <= wr_shiftReg(RAM_D_WIDTH - 1 downto 0);
    ram_wdata <= wr_out_data;
    ram_addr <= wr_out_addr;
    ram_avalid <= wr_out_avalid;
    ram_rnw <= wr_out_rnw;
    
    --obvious assignments - read side
    rd_fifo_rd_rst  <= not reset_n;
    rd_fifo_wr_rst  <= not ram_reset_n;
    rd_fifo_wr_en   <= ram_ack; --directly
    rd_fifo_din <= ram_rdata;
    rdata <= rd_shiftReg;
    
    --shift regs
    wr_sr_p: process(clk)
    begin
        if clk'event and clk = '1' then
            if wr_sr_load = '1' then
                wr_shiftReg <= wdata;
            elsif wr_sr_shift = '1' then -- cycle shift because why not
                wr_shiftReg <= wr_shiftReg(RAM_D_WIDTH - 1 downto 0) & wr_shiftReg(D_WIDTH - 1 downto RAM_D_WIDTH);
            end if;
        end if;
    end process wr_sr_p;
    
    rd_sr_p: process(clk)
    begin
        if clk'event and clk = '1' and rd_sr_shift = '1' then -- cycle shift because why not
            rd_shiftReg <= rd_fifo_dout & rd_shiftReg(D_WIDTH - 1 downto RAM_D_WIDTH);
        end if;
    end process rd_sr_p;
    
    --state machine - next state. also sets the counter
    sm_next: process(state, rd, wr, rw_cnt, rd_fifo_empty, wr_fifo_full)
    begin
        case state is
            when IDLE =>
                if rd = '1' then
                    if wr_fifo_full = '0' then
                        next_state <= WAIT_READ; --can write address immediately
                    else
                        next_state <= WRITE_ADDR;
                    end if;
                elsif wr = '1' then
                    next_state <= WRITE_DATA;
                else
                    next_state <= IDLE;
                end if;
                
            when WRITE_ADDR =>
                if wr_fifo_full = '0' then
                    next_state <= WAIT_READ; --wrote address, wait for data
                else
                    next_state <= WRITE_ADDR;
                end if;
                
            when WRITE_DATA =>
                if rw_cnt = D_WIDTH / RAM_D_WIDTH - 1 and wr_fifo_full = '0' then --if last byte and can write
                    next_state <= SHOW_ACK;
                else
                    next_state <= WRITE_DATA;
                end if;
                
            when WAIT_READ =>
                if rd_fifo_empty = '0' then --got ack, show it
                    next_state <= READ_DATA;
                else
                    next_state <= WAIT_READ;
                end if;
                
            when READ_DATA =>
                if rw_cnt = D_WIDTH / RAM_D_WIDTH - 1 then --if last byte and ACK
                    next_state <= SHOW_ACK;
                else
                    next_state <= WAIT_READ;
                end if;
                
            when SHOW_ACK =>
                next_state <= IDLE; --back to idle anyway
        end case;
    end process sm_next;
    
    sm_change: process(clk, reset_n, ram_reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            rw_cnt <= 0;
        elsif clk'event and clk = '1' then
            --counter, it's related (though order doesn't matter)
            if state = READ_DATA or (state = WRITE_DATA and wr_fifo_full = '0') then
                rw_cnt <= rw_cnt + 1;
            elsif state = SHOW_ACK or state = IDLE then
                rw_cnt <= 0;
            end if;
            --actual state change
            state <= next_state;
        end if;
    end process sm_change;
    
    sm_control_sync: process(clk, reset_n, ram_reset_n)
    begin
        if reset_n = '0' then
            addr_latch <= (others => 'U');
            wr_cmd_cleared <= '1';
        elsif clk'event and clk = '1' then
            --address latching
            if state = IDLE and (wr = '1' or rd = '1') then
                addr_latch <= addr; --remember address to show with data 0
            end if;
            --marking ram command for clearing
            if ((state = IDLE and rd = '1') or state = WRITE_ADDR) and wr_fifo_full = '0' then
                wr_cmd_cleared <= '0'; --clear cmd at the next clock
            elsif wr_fifo_full = '0' then
                wr_cmd_cleared <= '1'; --cleared
            end if;
        end if;
    end process sm_control_sync;

    --sm actions - comb
    sm_control: process(state, rd, wr, rw_cnt, addr, addr_latch, rd_fifo_empty, wr_fifo_full, wr_cmd_cleared)
    begin
        --defaults - will it work?
        wr_in_rnw <= '0';
        wr_in_avalid <= '0';
        wr_in_addr <= (others => 'U');
        wr_sr_load <= '0';
        wr_sr_shift <= '0';
        wr_fifo_wr_en <= '0';
        rd_fifo_rd_en <= '0';
        rd_sr_shift <= '0';
        ack <= '0';
        --clear ram cmd after sending
        if wr_cmd_cleared = '0' and wr_fifo_full = '0' then
            wr_in_rnw <= '0';
            wr_in_avalid <= '0';
            wr_in_addr <= (others => 'U');
            wr_fifo_wr_en <= '1';
        end if;
        --changes
        case state is
            when IDLE =>
                if rd = '1' and wr_fifo_full = '0' then --if full, do nothing
                    wr_in_rnw <= '1';
                    wr_in_avalid <= '1';
                    wr_in_addr <= addr;
                    wr_fifo_wr_en <= '1';
                elsif wr = '1' then
                    wr_sr_load <= '1';
                    --need to latch the data, so nothing special here
                    --can speed up, but too lazy to implement it
                end if;
            
            when WRITE_ADDR =>
                if wr_fifo_full = '0' then --if full, do nothing
                    wr_in_rnw <= '1';
                    wr_in_avalid <= '1';
                    wr_in_addr <= addr_latch; --use latched addr
                    wr_fifo_wr_en <= '1';
                end if;
                
            when WRITE_DATA =>
                --write addr with byte 0
                if rw_cnt = 0 then
                    wr_in_rnw <= '0';
                    wr_in_avalid <= '1';
                    wr_in_addr <= addr_latch;
                else
                    wr_in_addr <= (others => 'U');
                    wr_in_avalid <= '0';
                end if;
                if wr_fifo_full = '0' then
                    wr_fifo_wr_en <= '1';
                    wr_sr_shift <= '1';
                end if;
                
            when WAIT_READ =>
                rd_fifo_rd_en <= not rd_fifo_empty; --write to reg
                
            when READ_DATA =>
                rd_sr_shift <= '1'; --write to reg
                
            when SHOW_ACK =>
                ack <= '1';
                rd_fifo_rd_en <= not rd_fifo_empty; --eat it
        end case;
        --type State_Type is (IDLE, WRITE_ADDR, WAIT_ACK, WRITE_DATA, READ_DATA, SHOW_ACK);
    end process sm_control;

end ramIf_arch;
