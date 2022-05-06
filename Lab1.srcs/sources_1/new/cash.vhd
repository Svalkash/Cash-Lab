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
        RAM_D_WIDTH     : integer := 32;
        BVAL_WIDTH      : integer := 4
    );
    port (
        cpu_clk : in    std_logic;
        clk     : in    std_logic;
        cpu_reset_n : in    std_logic;
        reset_n : in    std_logic;
        
        addr    : in    std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0);
        
        wr      : in    std_logic;
        rd      : in    std_logic;
        ack     : out    std_logic;
        
        bval    : in    std_logic_vector(BVAL_WIDTH - 1 downto 0); --128/32 = 4
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
            fifoEmpty:in   std_logic;
            fifoRd  : out   std_logic
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
    COMPONENT fifo_54_reset
      PORT (
        wr_clk : IN STD_LOGIC;
        wr_rst : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        rd_rst : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(53 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(53 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END COMPONENT;
    COMPONENT fifo_33_reset
      PORT (
        wr_clk : IN STD_LOGIC;
        wr_rst : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        rd_rst : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(32 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(32 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
      );
    END COMPONENT;
    --fifo stuff - write side (CPU -> cash)
    signal wr_fifo_wr_rst   : std_logic;
    signal wr_fifo_rd_rst   : std_logic;
    signal wr_fifo_wr_en    : std_logic;
    signal wr_fifo_rd_en    : std_logic;
    signal wr_fifo_full     : std_logic;
    signal wr_fifo_empty    : std_logic;
    signal wr_fifo_din      : std_logic_vector(53 downto 0);
        alias wr_in_addr    : std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0)
            is wr_fifo_din(53 downto (D_WIDTH + BVAL_WIDTH + 2));
        alias wr_in_wdata   : std_logic_vector(D_WIDTH - 1 downto 0)
            is wr_fifo_din((D_WIDTH + BVAL_WIDTH + 2) - 1 downto (BVAL_WIDTH + 2));
        alias wr_in_bval    : std_logic_vector(BVAL_WIDTH - 1 downto 0)
            is wr_fifo_din((BVAL_WIDTH + 2) - 1 downto 2);
        alias wr_in_wr      : std_logic
            is wr_fifo_din(1);
        alias wr_in_rd      : std_logic
            is wr_fifo_din(0);
    signal wr_fifo_dout     : std_logic_vector(53 downto 0);
        alias wr_out_addr   : std_logic_vector(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto 0)
            is wr_fifo_dout(53 downto (D_WIDTH + BVAL_WIDTH + 2));
        alias wr_out_wdata  : std_logic_vector(D_WIDTH - 1 downto 0)
            is wr_fifo_dout((D_WIDTH + BVAL_WIDTH + 2) - 1 downto (BVAL_WIDTH + 2));
        alias wr_out_bval   : std_logic_vector(BVAL_WIDTH - 1 downto 0)
            is wr_fifo_dout((BVAL_WIDTH + 2) - 1 downto 2);
        alias wr_out_wr     : std_logic
            is wr_fifo_dout(1);
        alias wr_out_rd     : std_logic
            is wr_fifo_dout(0);
    signal wr_cleared       : std_logic := '1';
    signal wr_out_mask      : std_logic := '1';
    signal wr_out_wr_masked : std_logic;
    signal wr_out_rd_masked : std_logic;
    --read side:
    signal rd_fifo_wr_rst   : std_logic;
    signal rd_fifo_rd_rst   : std_logic;
    signal rd_fifo_wr_en    : std_logic;
    signal rd_fifo_rd_en    : std_logic;
    signal rd_fifo_full     : std_logic;
    signal rd_fifo_empty    : std_logic;
    signal rd_fifo_din      : std_logic_vector(32 downto 0);
        alias rd_in_rdata   : std_logic_vector(D_WIDTH - 1 downto 0)
            is rd_fifo_din(32 downto 1);
        alias rd_in_ack     : std_logic
            is rd_fifo_din(0);
    signal rd_fifo_dout     : std_logic_vector(32 downto 0);
        alias rd_out_rdata  : std_logic_vector(D_WIDTH - 1 downto 0)
            is rd_fifo_dout(32 downto 1);
        alias rd_out_ack    : std_logic
            is rd_fifo_dout(0);
    signal rd_cleared       : std_logic := '1';
    signal rd_out_mask     : std_logic := '0';
    
    --aliases
    alias aTag      : std_logic_vector(ATAG_WIDTH - 1 downto 0)
        is wr_out_addr(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto AINDEX_WIDTH + ADISP_WIDTH);
    alias aIndex    : std_logic_vector(AINDEX_WIDTH - 1 downto 0)
        is wr_out_addr(AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH);
    alias aDisp     : std_logic_vector(ADISP_WIDTH - 1 downto 0)
        is wr_out_addr(ADISP_WIDTH - 1 downto 0);
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
    --FIFO instances
    wr_fifo: fifo_54_reset
        port map (
            wr_clk  => cpu_clk,
            rd_clk  => clk,
            wr_rst  => wr_fifo_wr_rst,
            rd_rst  => wr_fifo_rd_rst,
            wr_en   => wr_fifo_wr_en,
            rd_en   => wr_fifo_rd_en,
            full    => wr_fifo_full,
            empty   => wr_fifo_empty,
            din     => wr_fifo_din,
            dout    => wr_fifo_dout
        );
    rd_fifo: fifo_33_reset
        port map (
            wr_clk  => clk,
            rd_clk  => cpu_clk,
            wr_rst  => rd_fifo_wr_rst,
            rd_rst  => rd_fifo_rd_rst,
            wr_en   => rd_fifo_wr_en,
            rd_en   => rd_fifo_rd_en,
            full    => rd_fifo_full,
            empty   => rd_fifo_empty,
            din     => rd_fifo_din,
            dout    => rd_fifo_dout
        );
    --obvious assignments
    wr_fifo_wr_rst <= not cpu_reset_n;
    wr_fifo_rd_rst <= not reset_n;
    wr_fifo_wr_en <= ((wr or rd) or (not wr_cleared)) and not wr_fifo_full; --write when cmd or need to clear
    process(cpu_clk)
    begin
        if cpu_clk'event and cpu_clk = '1' and wr_fifo_full = '0' then
            if wr = '1' or rd = '1' then
                wr_cleared <= '0';
            elsif wr_cleared = '0' then
                wr_cleared <= '1';
            end if;
        end if;
    end process;
    wr_in_addr <= addr;
    wr_in_wdata <= wdata;
    wr_in_bval <= bval;
    wr_in_wr <= wr;
    wr_in_rd <= rd;
    process(clk)
    begin
        if clk'event and clk = '1' then
            if (wr_out_wr = '1' or wr_out_rd = '1') and rd_in_ack = '1' then
                wr_out_mask <= '0';
            else
                wr_out_mask <= '1';
            end if;
        end if;
    end process;
    wr_out_wr_masked <= wr_out_wr and wr_out_mask;
    wr_out_rd_masked <= wr_out_rd and wr_out_mask;
    
    --read side
    rd_fifo_wr_en <= (rd_in_ack or (not rd_cleared)) and not rd_fifo_full; --write when cmd or need to clear
    process(clk)
    begin
        if clk'event and clk = '1' and rd_fifo_full = '0' then
            if rd_in_ack = '1' then
                rd_cleared <= '0';
            elsif rd_cleared = '0' then
                rd_cleared <= '1';
            end if;
        end if;
    end process;
    rd_fifo_wr_rst <= not reset_n;
    rd_fifo_rd_rst <= not cpu_reset_n;
    rd_fifo_rd_en <= not rd_fifo_empty;
    rdata <= rd_out_rdata;
    --big kostyl'
    process(cpu_clk)
    begin
        if cpu_clk'event and cpu_clk = '1' then
            if rd_out_ack = '1' then
                rd_out_mask <= '0';
            else
                rd_out_mask <= '1';
            end if;
        end if;
    end process;
    ack <= rd_out_ack and rd_out_mask;
    --parts
    tagMem_inst: tagMem
        generic map(
            ATAG_WIDTH => ATAG_WIDTH,
            AINDEX_WIDTH => AINDEX_WIDTH
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            addr => wr_out_addr(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
            wr => tWr,
            hit => hit
        );
    controlUnit_inst: controlUnit
        port map(
            clk => clk,
            reset_n => reset_n,
            wr => wr_out_wr_masked,
            rd => wr_out_rd_masked,
            hit => hit,
            ramAck => ramAck,
            ack => rd_in_ack,
            tWr => tWr,
            dWr => dWr,
            dSel => dSel,
            ramWr => ramWr,
            ramRd => ramRd,
            fifoEmpty => wr_fifo_empty,
            fifoRd => wr_fifo_rd_en
        );
    dataMem_inst: dataMem
        generic map(
            A_WIDTH => AINDEX_WIDTH,
            D_WIDTH => 2**ADISP_WIDTH * 8
        )
        port map(
            clk => clk,
            reset_n => reset_n,
            addr => wr_out_addr(AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
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
            addr        => wr_out_addr(ATAG_WIDTH + AINDEX_WIDTH + ADISP_WIDTH - 1 downto ADISP_WIDTH),
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
    
    --CC1 - dataMem output
    CC1: process (dMem_rData, wr_out_addr(ADISP_WIDTH - 1 downto 2))
        variable byteAddr : natural;
    begin
        --because binary shift is terrible here, and i JUST NEED TO MULTIPLY
        byteAddr := conv_integer(wr_out_addr(ADISP_WIDTH - 1 downto 2)) * BVAL_WIDTH * 8;
        rd_in_rdata <= dMem_rData(byteAddr + D_WIDTH - 1 downto byteAddr);
    end process CC1;
    
    --CC2 - ram write input AND dataMem write (before CC3)
    CC2: process(dMem_rData, wr_out_wdata, wr_out_bval, dSel, wr_out_addr(ADISP_WIDTH - 1 downto 2))
        variable wordAddr, byteAddr : natural;
        variable dMem_rData_filt: std_logic_vector(D_WIDTH - 1 downto 0);
    begin
        --rounded address to insert to
        wordAddr := conv_integer(wr_out_addr(ADISP_WIDTH - 1 downto 2)) * BVAL_WIDTH * 8;
        --original data
        ramIf_wData <= dMem_rData; --hope it works this way
        --compose
        for i in 0 to BVAL_WIDTH - 1 loop
            byteAddr := wordAddr + 8 * i;
            if wr_out_bval(i) = '1' then
                ramIf_wData(byteAddr + 7 downto byteAddr) <= wr_out_wdata(8 * i + 7 downto 8 * i);
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
