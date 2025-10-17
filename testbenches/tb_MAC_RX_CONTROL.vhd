library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MAC_RX_CONTROL_tb is
end MAC_RX_CONTROL_tb;

architecture test of MAC_RX_CONTROL_tb is
    -- Component Declaration
    component MAC_RX_CONTROL
        Port (
            MAC_RX_CLK   : in  STD_LOGIC;
            MAC_RXD      : in  STD_LOGIC_VECTOR(7 downto 0);
            MAC_RX_VALID : in  STD_LOGIC;
            MAC_RX_LAST  : in  STD_LOGIC;
            MAC_RX_ERR   : in  STD_LOGIC;
            LINE_NUMBER  : out STD_LOGIC_VECTOR(15 downto 0);
            DATA_FW      : out STD_LOGIC_VECTOR(7 downto 0);
            FW_OUT       : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;

    -- Signals for Testbench
    signal clk        : STD_LOGIC := '0';
    signal data_in    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal valid      : STD_LOGIC := '0';
    signal last       : STD_LOGIC := '0';
    signal err        : STD_LOGIC := '0';
    
    signal line_num   : STD_LOGIC_VECTOR(15 downto 0);
    signal data_fw    : STD_LOGIC_VECTOR(7 downto 0);
    signal fw_out     : STD_LOGIC_VECTOR(1 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    -- Pacchetto in formato array
    type packet_array is array (natural range <>) of STD_LOGIC_VECTOR(7 downto 0);
    constant test_packet : packet_array := (
        x"00", x"10", x"A4", x"7B", x"EA", x"80",
        x"00", x"12", x"34", x"56", x"78", x"90",
        x"08", x"00",
        x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
        x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8", x"00", x"04",
        x"04", x"00", x"04", x"00", x"00", x"1A", x"2D", x"E8",
        x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07",
        x"08", x"09", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F",
        x"10", x"11", x"E6", x"C5", x"3D", x"B2"
    );
begin

    -- Instanza del modulo da testare
    uut: MAC_RX_CONTROL
        port map (
            MAC_RX_CLK   => clk,
            MAC_RXD      => data_in,
            MAC_RX_VALID => valid,
            MAC_RX_LAST  => last,
            MAC_RX_ERR   => err,
            LINE_NUMBER  => line_num,
            DATA_FW      => data_fw,
            FW_OUT       => fw_out
        );

    -- Clock generation
    clk_process: process
    begin
        while now < 1000 ns loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Stimolo
    stimulus: process
    begin
        wait for 20 ns;
        valid <= '1';

        for i in 0 to test_packet'length - 1 loop
            data_in <= test_packet(i);
            if i = test_packet'length - 1 then
                last <= '1';
            else
                last <= '0';
            end if;
            wait for CLK_PERIOD;
        end loop;

        valid <= '0';
        last <= '0';
        wait;
    end process;

end test;
