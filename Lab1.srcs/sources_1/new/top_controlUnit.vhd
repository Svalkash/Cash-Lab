library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top_controlUnit is
end top_controlUnit;

architecture top_controlUnit_arch of top_controlUnit is
    component controlUnit
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
            ramRd   : out   std_logic
        );
    end component;
    
    signal clk      :     std_logic := '0';
    signal reset_n  :     std_logic := '0';
    signal wr       :     std_logic := '0';
    signal rd       :     std_logic := '0';
    signal hit      :     std_logic := '0';
    signal ramAck   :     std_logic := '0';
    signal ack      :     std_logic;
    signal tWr      :     std_logic;
    signal dWr      :     std_logic;
    signal dSel     :     std_logic;
    signal ramWr    :     std_logic;
    signal ramRd    :     std_logic;
begin
    controlUnit_inst: controlUnit
        port map(
            clk => clk,
            reset_n => reset_n,
            wr => wr,
            rd => rd,
            hit => hit,
            ramAck => ramAck,
            ack => ack,
            tWr => tWr,
            dWr => dWr,
            dSel => dSel,
            ramWr => ramWr,
            ramRd => ramRd
        );

    drive_clk: process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;
    
    test: process
    begin
        wait for 20 ns;
        report("unreset");
        reset_n <= '1';
        wr <= '0';
        rd <= '0';
        hit <= '0';
        ramAck <= '0';
        wait for 20 ns;
        --
        -- check init
        --
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --
        -- Read hit
        --
        --RD-HIT
        hit <= '1';
        rd <= '1';
        wait on clk until clk = '0';
        assert ack = '1' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not RD_HIT" severity error;
        --IDLE
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --
        -- Write hit
        --
        --WR-HIT
        rd <= '0';
        wr <= '1';
        hit <= '1';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '1' and dSel = '0' and ramWr = '1' and ramRd = '0'
            report "ERROR: not WR_HIT" severity error;
        --still WR-HIT
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '1' and dSel = '0' and ramWr = '1' and ramRd = '0'
            report "ERROR: not WR_HIT" severity error;
        --WR-DONE
        ramAck <= '1';
        wait on clk until clk = '0';
        assert ack = '1' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not WR_DONE" severity error;
        --IDLE
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --
        -- Read miss
        --
        --RAM_RD
        wr <= '0';
        rd <= '1';
        hit <= '0';
        ramAck <= '0';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '1' and dWr = '1' and dSel = '1' and ramWr = '0' and ramRd = '1'
            report "ERROR: not RAM_RD" severity error;
        --still RAM_RD
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '1' and dWr = '1' and dSel = '1' and ramWr = '0' and ramRd = '1'
            report "ERROR: not RAM_RD" severity error;
        --RD-HIT
        ramAck <= '1';
        wait on clk until clk = '0';
        assert ack = '1' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not RD_HIT" severity error;
        --IDLE
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --
        -- Write miss
        --
        --RAM_RD
        wr <= '1';
        rd <= '0';
        hit <= '0';
        ramAck <= '0';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '1' and dWr = '1' and dSel = '1' and ramWr = '0' and ramRd = '1'
            report "ERROR: not RAM_RD" severity error;
        --still RAM_RD
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '1' and dWr = '1' and dSel = '1' and ramWr = '0' and ramRd = '1'
            report "ERROR: not RAM_RD" severity error;
        --WR-HIT
        ramAck <= '1';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '1' and dSel = '0' and ramWr = '1' and ramRd = '0'
            report "ERROR: not WR_HIT" severity error;
        --still WR-HIT
        ramAck <= '0';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '1' and dSel = '0' and ramWr = '1' and ramRd = '0'
            report "ERROR: not WR_HIT" severity error;
        --WR-DONE
        ramAck <= '1';
        wait on clk until clk = '0';
        assert ack = '1' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not WR_DONE" severity error;
        --IDLE
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --forever IDLE
        wr <= '0';
        rd <= '0';
        hit <= '0';
        ramAck <= '0';
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        wait on clk until clk = '0';
        assert ack = '0' and tWr = '0' and dWr = '0' and ramWr = '0' and ramRd = '0'
            report "ERROR: not IDLE" severity error;
        --end
        report("END");
        wait;
    end process;


end top_controlUnit_arch;
