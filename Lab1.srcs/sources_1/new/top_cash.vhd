library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;


entity top_cash is
    generic (
        ATAG_WIDTH      : integer := 5;
        AINDEX_WIDTH    : integer := 7;
        ADISP_WIDTH     : integer := 4;
        D_WIDTH         : integer := 32;
        RAM_D_WIDTH     : integer := 32
    );
end top_cash;

architecture top_cash_arch of top_cash is
    component cash
        generic (
            ATAG_WIDTH      : integer;
            AINDEX_WIDTH    : integer;
            ADISP_WIDTH     : integer;
            D_WIDTH         : integer;
            RAM_D_WIDTH     : integer
        );
        port (
            clk     : in    std_logic;
            reset_n : in    std_logic;
            
            addr    : in    std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0);
            
            wr      : in    std_logic;
            rd      : in    std_logic;
            ack     : out    std_logic;
            
            bval    : in    std_logic_vector(2**ADISP_WIDTH * 8 / D_WIDTH - 1 downto 0); --128/32 = 4
            wdata   : in    std_logic_vector(D_WIDTH - 1 downto 0);
            rdata   : out   std_logic_vector(D_WIDTH - 1 downto 0);
            
            ram_clk     : in   std_logic;
            ram_reset_n : in   std_logic;
            ram_ack     : in   std_logic;
            ram_rdata   : in   std_logic_vector(RAM_D_WIDTH - 1 downto 0);
            
            ram_wdata   : out   std_logic_vector(RAM_D_WIDTH - 1 downto 0);
            ram_addr    : out   std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH - 1 downto 0);
            ram_avalid  : out   std_logic;
            ram_rnw     : out   std_logic
        );
    end component;
    component fakeExtRam
        generic (
            A_WIDTH : integer;
            D_WIDTH : integer;
            LINE_WIDTH : integer
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
    end component;
    
    signal clk      :     std_logic := '0';
    signal reset_n  :     std_logic := '0';
    signal wr       :     std_logic := '0';
    signal rd       :     std_logic := '0';
    signal ack      :     std_logic := '0';
    signal bval     :     std_logic_vector(2**ADISP_WIDTH * 8 / D_WIDTH - 1 downto 0); --128/32 = 4
    signal wdata    :     std_logic_vector(D_WIDTH - 1 downto 0);
    signal rdata    :     std_logic_vector(D_WIDTH - 1 downto 0);
    signal addr     :     std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0);
    
    signal ram_clk     : std_logic := '0';
    signal ram_reset_n : std_logic := '0';
    signal ram_ack     : std_logic;
    signal ram_rdata   : std_logic_vector(RAM_D_WIDTH - 1 downto 0);
    
    signal ram_wdata   : std_logic_vector(RAM_D_WIDTH - 1 downto 0);
    signal ram_addr    : std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH - 1 downto 0);
    signal ram_avalid  : std_logic;
    signal ram_rnw     : std_logic;
    
begin
    cash_inst: cash
        generic map (
            ATAG_WIDTH      => ATAG_WIDTH,
            AINDEX_WIDTH    => AINDEX_WIDTH,
            ADISP_WIDTH     => ADISP_WIDTH,
            D_WIDTH         => D_WIDTH,
            RAM_D_WIDTH     => RAM_D_WIDTH
        )
        port map(
            clk         => clk,
            reset_n     => reset_n,
            addr        => addr,
            wr          => wr,
            rd          => rd,
            ack         => ack,
            bval        => bval,
            wdata       => wdata,
            rdata       => rdata,
            ram_clk     => ram_clk,
            ram_reset_n => ram_reset_n,
            ram_ack     => ram_ack,
            ram_rdata   => ram_rdata,
            ram_wdata   => ram_wdata,
            ram_addr    => ram_addr,
            ram_avalid  => ram_avalid,
            ram_rnw     => ram_rnw
        );
    ram: fakeExtRam
        generic map (
            A_WIDTH => ATAG_WIDTH + AINDEX_WIDTH,
            D_WIDTH => RAM_D_WIDTH,
            LINE_WIDTH => 2**ADISP_WIDTH * 8
        )
        port map (
            clk => ram_clk,
            reset_n => ram_reset_n,
            wdata => ram_wdata,
            addr => ram_addr,
            avalid => ram_avalid,
            rnw => ram_rnw,
            ack => ram_ack,
            rdata => ram_rdata
        );

    drive_clk: process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end process;

    drive_ram_clk: process
    begin
        ram_clk <= '0';
        wait for 10 ns;
        ram_clk <= '1';
        wait for 10 ns;
    end process;
        
    test: process
        variable seed1 : positive := 1;
        variable seed2 : positive := 2;
        --random logic
        impure function rand_logic return std_logic is
            variable r : real;
        begin
            uniform(seed1, seed2, r);
            if (r > 0.5) then
                return '1';
            else
                return '0';
            end if;
        end function;
        --random slv
        impure function rand_slv(len : integer) return std_logic_vector is
            variable r : real;
            variable slv : std_logic_vector(len - 1 downto 0);
        begin
            for i in slv'range loop
                uniform(seed1, seed2, r);
                if (r > 0.5) then
                    slv(i) := '1';
                else
                    slv(i) := '0';
                end if;
            end loop;
            return slv;
        end function;
        --real params
        constant repeats : integer := 100;
    begin
        wait for 20 ns;
        report("unreset");
        reset_n <= '1';
        ram_reset_n <= '1';
        wr <= '0';
        rd <= '0';
        addr <= (others => 'U');
        wdata <= (others => 'U');
        wait for 20 ns;
        wait on clk until clk = '0';
        --loop
        for i in 1 to repeats loop
            --select operation
            if (rand_logic = '1') then
                wr <= '1';
                rd <= '0';
            else
                wr <= '0';
                rd <= '1';
            end if;
            bval <= rand_slv(4);
            addr <= "000" & rand_slv(2) & "00000" & rand_slv(2) & rand_slv(1) & "000";
            wdata <= rand_slv(32);
            --reset ALL - hard test
            wait on clk until clk = '0';
            wr <= '0';
            rd <= '0';
            addr <= (others => 'U');
            wdata <= (others => 'U');
            --wait till acked
            if (ack = '0') then --special case for read-hit, it's ready after 1 clock
                wait on clk until clk = '0' and ack = '1';
            end if;
            --wait 1 more clock to let the cash change to IDLE
            wait on clk until clk = '0';
        end loop;
    end process;

end top_cash_arch;
