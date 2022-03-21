library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.MATH_REAL;

entity top_tagMem is
    generic (
        ATAG_WIDTH      : integer := 5;
        AINDEX_WIDTH    : integer := 7
    );
end top_tagMem;

architecture top_tagMem_arch of top_tagMem is
    component tagMem
        generic (
            ATAG_WIDTH      : integer;
            AINDEX_WIDTH    : integer
        );
        port (
            clk     : in    std_logic;
            reset_n : in    std_logic;
            
            addr    : in    std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH - 1 downto 0);
            wr      : in    std_logic;
            hit     : out   std_logic
        );
    end component;
    
    signal clk     :     std_logic := '0';
    signal reset_n :     std_logic := '0';
    signal addr    :     std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH - 1 downto 0) := (others => '0');
        alias aTag      : std_logic_vector(ATAG_WIDTH - 1 downto 0)
            is addr(ATAG_WIDTH + AINDEX_WIDTH - 1 downto AINDEX_WIDTH);
        alias aIndex    : std_logic_vector(AINDEX_WIDTH - 1 downto 0)
            is addr(AINDEX_WIDTH - 1 downto 0);
    signal wr      :     std_logic := '0';
    signal hit     :     std_logic;
begin
    tagMem_inst: tagMem
        generic map(
            ATAG_WIDTH => ATAG_WIDTH,
            AINDEX_WIDTH => AINDEX_WIDTH
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            addr => addr,
            wr => wr,
            hit => hit
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
        aTag <= conv_std_logic_vector(0,ATAG_WIDTH);
        aIndex <= conv_std_logic_vector(0,AINDEX_WIDTH);
        wr <= '0';
        wait for 20 ns;
        --check init
        wait on clk until clk = '0';
        assert hit = '0' report "ERROR: hit after reset" severity error;
        --write first time
        aTag <= conv_std_logic_vector(0,ATAG_WIDTH);
        aIndex <= conv_std_logic_vector(0,AINDEX_WIDTH);
        wr <= '1';
        wait on clk until clk = '0';
        assert hit = '1' report "ERROR: unexpected miss" severity error;
        --miss other tag
        aTag <= conv_std_logic_vector(1,ATAG_WIDTH);
        wr <= '0';
        wait on clk until clk = '0';
        assert hit = '0' report "ERROR: unexpected hit" severity error;
        --hit old
        aTag <= conv_std_logic_vector(0,ATAG_WIDTH);
        wait on clk until clk = '0';
        assert hit = '1' report "ERROR: unexpected miss" severity error;
        --another index - write
        aTag <= conv_std_logic_vector(2,ATAG_WIDTH);
        aIndex <= conv_std_logic_vector(1,AINDEX_WIDTH);
        wr <= '1';
        wait on clk until clk = '0';
        assert hit = '1' report "ERROR: unexpected miss" severity error;
        --check if old is unchanged
        aTag <= conv_std_logic_vector(0,ATAG_WIDTH);
        aIndex <= conv_std_logic_vector(0,AINDEX_WIDTH);
        wr <= '0';
        wait on clk until clk = '0';
        assert hit = '1' report "ERROR: unexpected miss" severity error;
        --change it
        aTag <= conv_std_logic_vector(3,ATAG_WIDTH);
        wr <= '1';
        wait on clk until clk = '0';
        assert hit = '1' report "ERROR: unexpected miss" severity error;
        --check new one for misses
        aIndex <= conv_std_logic_vector(1,AINDEX_WIDTH);
        wr <= '0';
        wait on clk until clk = '0';
        assert hit = '0' report "ERROR: unexpected hit" severity error;
        report("END");
        wait;
    end process;


end top_tagMem_arch;
