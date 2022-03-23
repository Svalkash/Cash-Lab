library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."log2";
use IEEE.math_real."ceil";

entity cash is
    generic (
        ATAG_WIDTH      : integer := 5;
        AINDEX_WIDTH    : integer := 7;
        ADISP_WIDTH     : integer := 4;
        D_WIDTH         : integer := 32;
        RAM_D_WIDTH     : integer := 32
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
end cash;

architecture cash_arch of cash is
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
            ramRd   : out   std_logic;
            lock    : out   std_logic
        );
    end component;
    component dataMem
        generic (
            A_WIDTH : integer;
            D_WIDTH : integer
        );
        port (
            clk     : in    std_logic;
            reset_n : in    std_logic;
            addr    : in    std_logic_vector(A_WIDTH - 1 downto 0);
            wdata   : in    std_logic_vector(D_WIDTH - 1 downto 0);
            rdata   : out   std_logic_vector(D_WIDTH - 1 downto 0);
            wr      : in    std_logic
        );
    end component;
    component ramIf
        generic (
            A_WIDTH : integer;
            D_WIDTH : integer;
            RAM_D_WIDTH : integer --can't be changed
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
    end component;
    --aliases
    alias aTag      : std_logic_vector(ATAG_WIDTH - 1 downto 0)
        is addr(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto AINDEX_WIDTH + ADISP_WIDTH);
    alias aIndex    : std_logic_vector(AINDEX_WIDTH - 1 downto 0)
        is addr(AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH);
    alias aDisp     : std_logic_vector(ADISP_WIDTH - 1 downto 0)
        is addr(ADISP_WIDTH - 1 downto 0);
    --new control signal
    signal lock         : std_logic := '0'; --if '1', latches are locked
    --latches for CPU interface
    signal addr_latch   : std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0) := (others => '0');
    signal wr_latch     : std_logic := '0';
    signal rd_latch     : std_logic := '0';
    signal bval_latch   : std_logic_vector(2**ADISP_WIDTH * 8 / D_WIDTH - 1 downto 0) := (others => '0'); --128/32 = 4
    signal wdata_latch  : std_logic_vector(D_WIDTH - 1 downto 0);
    --current signals for CU and others
    signal addr_c   : std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0) := (others => '0');
    signal wr_c     : std_logic := '0';
    signal rd_c     : std_logic := '0';
    signal bval_c   : std_logic_vector(2**ADISP_WIDTH * 8 / D_WIDTH - 1 downto 0) := (others => '0'); --128/32 = 4
    signal wdata_c  : std_logic_vector(D_WIDTH - 1 downto 0);
    --tagMem signals
    signal hit  : std_logic := '0';
    signal tWr  : std_logic := '0'; --tag write
    --CU signals
    signal dWr      : std_logic := '0'; --data write
    signal dSel     : std_logic := '0'; --data selection, 0 - wdata+cash, 1 - ram
    signal ramWr    : std_logic := '0'; --ram write
    signal ramRd    : std_logic := '0'; --ram read
    signal ramAck   : std_logic := '0'; --ram ack
    --dataMem signals
    signal dMem_wData : std_logic_vector(2**ADISP_WIDTH * 8 - 1 downto 0) := (others => '0');
    signal dMem_rData : std_logic_vector(2**ADISP_WIDTH * 8 - 1 downto 0) := (others => '0');
    --ramIf signals
    signal ramIf_wData  : std_logic_vector(2**ADISP_WIDTH * 8 - 1 downto 0) := (others => '0');
    signal ramIf_rData  : std_logic_vector(2**ADISP_WIDTH * 8 - 1 downto 0) := (others => '0');
begin
    tagMem_inst: tagMem
        generic map(
            ATAG_WIDTH => ATAG_WIDTH,
            AINDEX_WIDTH => AINDEX_WIDTH
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            addr => addr_c(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
            wr => tWr,
            hit => hit
        );
    controlUnit_inst: controlUnit
        port map(
            clk => clk,
            reset_n => reset_n,
            wr => wr_c,
            rd => rd_c,
            hit => hit,
            ramAck => ramAck,
            ack => ack,
            tWr => tWr,
            dWr => dWr,
            dSel => dSel,
            ramWr => ramWr,
            ramRd => ramRd,
            lock => lock
        );
    dataMem_inst: dataMem
        generic map(
            A_WIDTH => AINDEX_WIDTH,
            D_WIDTH => 2**ADISP_WIDTH * 8
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            addr => addr_c(AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
            wdata => dMem_wData,
            rdata => dMem_rData,
            wr => dWr
        );
    ramIf_inst: ramIf
        generic map(
            A_WIDTH => ATAG_WIDTH + AINDEX_WIDTH,
            D_WIDTH => 2**ADISP_WIDTH * 8,
            RAM_D_WIDTH => RAM_D_WIDTH
        )
        port map(
            clk         => clk,
            reset_n     => reset_n,
            addr        => addr_c(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
            wdata       => ramIf_wData,
            wr          => ramWr,
            rd          => ramRd,
            ack         => ramAck,
            rdata       => ramIf_rData,
            ram_clk     => ram_clk,
            ram_reset_n => ram_reset_n,
            ram_ack     => ram_ack,
            ram_rdata   => ram_rdata,
            ram_wdata   => ram_wdata,
            ram_addr    => ram_addr,
            ram_avalid  => ram_avalid,
            ram_rnw     => ram_rnw
        );
    
    -- latches - CPU interface
    -- if locked, use latched logic, otherwise - inputs
    cpu_if: process (clk, reset_n, lock)
    begin
        if (reset_n = '0') then
            addr_latch <= (others => '0');
            wr_latch <= '0';
            rd_latch <= '0';
            bval_latch <= (others => '0');
            wdata_latch <= (others => '0');
        elsif clk'event and clk = '1' and lock = '0' then
            addr_latch <= addr;
            wr_latch <= wr;
            rd_latch <= rd;
            bval_latch <= bval;
            wdata_latch <= wdata;
        end if;
    end process cpu_if;
    
    --CC for latches (choose from input and latches)
    cpu_if_cc: process (lock, addr, addr_latch, wr, wr_latch, rd, rd_latch, bval, bval_latch, wdata, wdata_latch)
    begin
        if (lock = '1') then
            addr_c <= addr_latch;
            wr_c <= wr_latch;
            rd_c <= rd_latch;
            bval_c <= bval_latch;
            wdata_c <= wdata_latch;
        else
            addr_c <= addr;
            wr_c <= wr;
            rd_c <= rd;
            bval_c <= bval;
            wdata_c <= wdata;
        end if;
    end process cpu_if_cc;
    
    --CC1 - dataMem output
    --forcefully aligned to 32-bit words
    --WHY THE F IS CLOG SO LONG HERE
    --PARAMETERS ARE FUN
    CC1: process (dMem_rData, addr_c(ADISP_WIDTH - 1 downto integer(ceil(log2(real(2**ADISP_WIDTH * 8 / D_WIDTH - 1))))))
        variable byteAddr : natural;
    begin
        --because binary shift is terrible here, and i JUST NEED TO MULTIPLY
        byteAddr := conv_integer(addr_c(ADISP_WIDTH - 1 downto integer(ceil(log2(real(2**ADISP_WIDTH * 8 / D_WIDTH - 1)))))) * (2**ADISP_WIDTH * 8 / D_WIDTH) * 8;
        rdata <= dMem_rData(byteAddr + D_WIDTH - 1 downto byteAddr);
    end process CC1;
    
    --CC2 - ram write input AND dataMem write (before CC3)
    CC2: process(dMem_rData, wdata_c, bval_c, dSel, addr_c(ADISP_WIDTH - 1 downto integer(ceil(log2(real(2**ADISP_WIDTH * 8 / D_WIDTH - 1))))))
        variable wordAddr, byteAddr : natural;
        variable dMem_rData_filt: std_logic_vector(D_WIDTH - 1 downto 0);
    begin
        --rounded address to insert to
        wordAddr := conv_integer(addr_c(ADISP_WIDTH - 1 downto integer(ceil(log2(real(2**ADISP_WIDTH * 8 / D_WIDTH - 1)))))) * (2**ADISP_WIDTH * 8 / D_WIDTH) * 8;
        --original data
        ramIf_wData <= dMem_rData; --hope it works this way
        --compose
        for i in 0 to (2**ADISP_WIDTH * 8 / D_WIDTH - 1) loop
            byteAddr := wordAddr + 8 * i;
            if bval_c(i) = '1' then
                ramIf_wData(byteAddr + 7 downto byteAddr) <= wdata_c(8 * i + 7 downto 8 * i);
            else
                ramIf_wData(byteAddr + 7 downto byteAddr) <= dMem_rData(byteAddr + 7 downto byteAddr);
            end if;
        end loop;
    end process CC2;
        
    --CC3 - dataMem input
    CC3: process (ramIf_wData, ramIf_rData, dSel)
    begin
        if dSel = '1' then
            dMem_wData <= ramIf_rData;
        else
            dMem_wData <= ramIf_wData;
        end if;
    end process CC3;

end cash_arch;
