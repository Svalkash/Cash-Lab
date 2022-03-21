library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity tagMemChannel is
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
end tagMemChannel;

architecture tagMemChannel_arch of tagMemChannel is
    constant MEM_SIZE   : integer := 2**AINDEX_WIDTH; --line number
    constant MEM_WIDTH  : integer := ATAG_WIDTH + 1; --line widths, tag+val
    constant TAG_LSB    : integer := 1;
    constant VAL_BIT    : integer := 0;
    
    alias aTag      : std_logic_vector(ATAG_WIDTH - 1 downto 0)
        is addr(ATAG_WIDTH + AINDEX_WIDTH - 1 downto AINDEX_WIDTH);
    alias aIndex    : std_logic_vector(AINDEX_WIDTH - 1 downto 0)
        is addr(AINDEX_WIDTH - 1 downto 0);
        
    type tagMem_t is array (natural range <>) of std_logic_vector (MEM_WIDTH - 1 downto 0);
    signal tagMem : tagMem_t (MEM_SIZE - 1 downto 0) := (others => (others => 'U'));
    
    signal tagMemOut    : std_logic_vector(MEM_WIDTH - 1 downto 0);
        alias moTag     : std_logic_vector(ATAG_WIDTH - 1 downto 0)
            is tagMemOut(MEM_WIDTH - 1 downto TAG_LSB);
        alias moVal     : std_logic
            is tagMemOut(VAL_BIT);
            
    signal tagMemIn     : std_logic_vector(MEM_WIDTH - 1 downto 0);
        alias miTag     : std_logic_vector(ATAG_WIDTH - 1 downto 0)
            is tagMemIn(MEM_WIDTH - 1 downto TAG_LSB);
        alias miVal     : std_logic
            is tagMemIn(VAL_BIT);
    
    --signal hitBuf   : std_logic;

begin
    miTag <= aTag   when wr = '1' else moTag;
    miVal <= '1'    when wr = '1' else moVal;
    
    tagMem_write: process (clk, reset_n)
        variable rstIn : std_logic_vector (MEM_WIDTH - 1 downto 0);
    begin
        rstIn := (others => 'U');
        rstIn(VAL_BIT) := '0';
        if reset_n = '0' then --trying to make it async
            tagMem <= (others => rstIn);
        elsif clk'event and clk = '1' then
            tagMem(conv_integer(aIndex)) <= tagMemIn;
        end if;
    end process tagMem_write;
    
    tagMemOut <= tagMem(conv_integer(aIndex)) after 1 ns;
    --hitBuf <= '1' when moTag = aTag and moVal = '1' else '0';
    --don't need any hitbuf since ce (we) function is simpler
    hit <= '1' when moTag = aTag and moVal = '1' else '0';
end tagMemChannel_arch;
