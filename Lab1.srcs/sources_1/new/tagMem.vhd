library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity tagMem is
    generic (
        ATAG_WIDTH      : integer := 5;
        AINDEX_WIDTH    : integer := 7
    );
    port (
        clk     : in    std_logic;
        reset_n : in    std_logic;
        
        addr    : in    std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH - 1 downto 0);
        wr      : in    std_logic;
        hit     : out   std_logic
    );
end tagMem;

architecture tagMem_arch of tagMem is
    component tagMemChannel
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

begin
    tagMemChannel_inst: tagMemChannel
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

end tagMem_arch;
