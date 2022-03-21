library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;

entity fakeRAM is
    generic (
        A_WIDTH : integer := 5+7;
        D_WIDTH : integer := 16*8
    );
    port (
        clk     : in    std_logic;
        reset_n : in    std_logic;
        addr    : in    std_logic_vector(A_WIDTH - 1 downto 0);
        wdata   : in    std_logic_vector(D_WIDTH - 1 downto 0);
        rdata   : out   std_logic_vector(D_WIDTH - 1 downto 0);
        wr      : in    std_logic;
        rd      : in    std_logic;
        ack     : out    std_logic
    );
    
--  Port ( );
end fakeRAM;

architecture fakeRAM_arch of fakeRAM is
    type dataMem_t is array (natural range <>) of std_logic_vector (D_WIDTH - 1 downto 0);
    signal mem: dataMem_t (2**A_WIDTH - 1 downto 0) := (others => (others => 'U'));
    
    signal rnw: boolean;
    signal cnt: integer;
begin
    fake: process (clk, reset_n)
    begin
        if reset_n = '0' then
            mem <= (others => (others => 'U'));
            cnt <= 0;
            rdata <= (others => 'U');
        elsif clk'event and clk = '1' then
            --ifs or states
            if cnt = 0 then
                if wr = '1' then
                    rnw <= false;
                    cnt <= 1;
                elsif rd = '1' then
                    rnw <= true;
                    cnt <= 1;
                end if;
            elsif cnt > 0 and cnt < 4 then
                ack <= '0';
                cnt <= cnt + 1;
            elsif cnt = 4 then --action
                ack <= '1';
                if rnw then
                    rdata <= mem(conv_integer(addr));
                else
                    mem(conv_integer(addr)) <= wdata;
                end if;
                cnt <= 5;
            else --show our result for 1 clock
                --if (wr = '0' and rd = '0') then
                    ack <= '0';
                    rdata <= (others => 'U');
                    cnt <= 0;
                --end if;
            end if;
        end if;
    end process fake;

end fakeRAM_arch;
