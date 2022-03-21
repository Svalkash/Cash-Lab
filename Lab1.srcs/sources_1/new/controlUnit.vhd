library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity controlUnit is
    port (
        clk     : in    std_logic;
        reset_n : in    std_logic;
        wr      : in    std_logic;
        rd      : in    std_logic;
        hit     : in    std_logic;
        ramAck  : in    std_logic;
        ack     : out   std_logic;
        tWr     : out   std_logic;
        dWr     : out   std_logic;
        dSel    : out   std_logic;
        ramWr   : out   std_logic;
        ramRd   : out   std_logic;
        lock    : out   std_logic
    );
end controlUnit;

architecture controlUnit_arch of controlUnit is
    type State_Type is (IDLE, RD_HIT, WR_HIT, WR_DONE, RAM_RD);
    signal state        : State_Type := IDLE;
    signal next_state   : State_Type;
begin
-- state machine logic
    next_state_p: process(state, wr, rd, hit, ramAck)
    begin
        case state is
            when IDLE =>
                if hit = '1' and rd = '1' then
                    next_state <= RD_HIT;
                elsif hit = '1' and wr = '1' then
                    next_state <= WR_HIT;
                elsif hit = '0' and (wr = '1' or rd = '1') then
                    next_state <= RAM_RD;
                else
                    next_state <= IDLE;
                end if;
                
            when RD_HIT =>
                next_state <= IDLE;
                
            when WR_HIT =>
                if ramAck = '1' then
                    next_state <= WR_DONE;
                else
                    next_state <= WR_HIT;
                end if;
                
            when WR_DONE =>
                next_state <= IDLE;
                
            when RAM_RD =>
                if ramAck = '1' and rd = '1' then
                    next_state <= RD_HIT;
                elsif ramAck = '1' and wr = '1' then
                    next_state <= WR_HIT;
                else
                    next_state <= RAM_RD;
                end if;
        end case;
    end process next_state_p;
    
-- state machine step
    state_change: process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
        elsif clk'event and clk = '1' then
            state <= next_state;
        end if;
    end process state_change;
    
-- state-dependent logic
    controls: process (state)
    begin
        case state is
            when IDLE =>
                ack <= '0';
                tWr <= '0';
                dWr <= '0';
                ramWr <= '0';
                ramRd <= '0';
                lock <= '0';
            when RD_HIT =>
                ack <= '1';
                tWr <= '0';
                dWr <= '0';
                ramWr <= '0';
                ramRd <= '0';
                lock <= '1'; --not needed, but why not?
            when WR_HIT =>
                ack <= '0';
                tWr <= '0';
                dWr <= '1';
                dSel <= '0'; --WData + cash
                ramWr <= '1';
                ramRd <= '0';
                lock <= '1'; --not needed, but why not?
            when WR_DONE =>
                ack <= '1';
                tWr <= '0';
                dWr <= '0';
                ramWr <= '0';
                ramRd <= '0';
                lock <= '1'; --not needed, but why not?
            when RAM_RD =>
                ack <= '0'; --still not ready!
                tWr <= '1'; --fix the tag after miss
                dWr <= '1'; --writing, don't care. Right BEFORE state switching, it'll be written properly?
                dSel <= '1'; --RAM
                ramWr <= '0';
                ramRd <= '1';
                lock <= '1';
        end case;
    end process controls;
end controlUnit_arch;
