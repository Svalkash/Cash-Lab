library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

entity dataMem is
    generic (
        A_WIDTH : integer := 7;
        D_WIDTH : integer := 16*8
    );
    port (
        clk     : in    std_logic;
        reset_n : in    std_logic;
        addr    : in    std_logic_vector(A_WIDTH - 1 downto 0);
        wdata   : in    std_logic_vector(D_WIDTH - 1 downto 0);
        rdata   : out   std_logic_vector(D_WIDTH - 1 downto 0);
        wr      : in    std_logic
    );
end dataMem;

architecture dataMem_arch of dataMem is
    type dataMem_t is array (natural range <>) of std_logic_vector (D_WIDTH - 1 downto 0);
    signal mem: dataMem_t (2**A_WIDTH - 1 downto 0) := (others => (others => 'U'));
begin
    dataMem_write: process (clk, reset_n)
    begin
        if (reset_n = '0') then
            mem <= (others => (others => 'U'));
        elsif clk'event and clk = '1' and wr = '1' then
            mem(conv_integer(addr)) <= wdata;
        end if;
    end process dataMem_write;

    rdata <= mem(conv_integer(addr));

end dataMem_arch;
