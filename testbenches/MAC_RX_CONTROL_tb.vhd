library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MAC_RX_CONTROL_tb is
end MAC_RX_CONTROL_tb;

architecture tb of MAC_RX_CONTROL_tb is
    -- Inputs to DUT
    signal mac_rx_clk   : STD_LOGIC := '0';
    signal mac_rxd      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal mac_rx_valid : STD_LOGIC := '0';
    signal mac_rx_last  : STD_LOGIC := '0';
    signal mac_rx_err   : STD_LOGIC := '0';

    -- Outputs from DUT
    signal line_number    : STD_LOGIC_VECTOR(15 downto 0);
    signal data_fw        : STD_LOGIC_VECTOR(7 downto 0);
    signal fw_out         : STD_LOGIC;
    signal start_of_frame : STD_LOGIC;
    signal end_of_frame   : STD_LOGIC;

    component MAC_RX_CONTROL is
        Port (
            MAC_RX_CLK   : in  STD_LOGIC;
            MAC_RXD      : in  STD_LOGIC_VECTOR(7 downto 0);
            MAC_RX_VALID : in  STD_LOGIC;
            MAC_RX_LAST  : in  STD_LOGIC;
            MAC_RX_ERR   : in  STD_LOGIC;
            LINE_NUMBER  : out STD_LOGIC_VECTOR(15 downto 0);
            DATA         : out STD_LOGIC_VECTOR(7 downto 0);
            FW_OUT       : out STD_LOGIC;
            START_OF_FRAME : out STD_LOGIC;
            END_OF_FRAME   : out STD_LOGIC
        );
    end component;

    constant CLK_PERIOD : time := 10 ns;

    -- Example packet
    type byte_array is array (natural range <>) of STD_LOGIC_VECTOR(7 downto 0);
    constant test_packet : byte_array := (
        x"00", x"10", x"A4", x"7B", x"EA", x"80", -- Dest MAC
        x"00", x"12", x"34", x"56", x"78", x"90", -- Src MAC
        x"08", x"00",                             -- EtherType: IPv4
        x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", -- IP header start
        x"11",                                     -- Byte 23: Protocol (UDP = 17 = x"11")
        x"05", x"40",                             -- Checksum etc.
        x"C0", x"A8", x"00", x"2C",               -- Source IP: 192.168.0.44
        x"C0", x"A8", x"00", x"04",               -- Dest IP:   192.168.0.4
        x"04", x"00",                             -- Source Port: 1024
        x"04", x"00",                             -- Dest Port: 1024
        x"00", x"1A", x"2D", x"E8",               -- Payload...
        x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07",
        x"08", x"09", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F",
        x"10", x"11",                             -- More payload
        x"E6", x"C5", x"3D", x"B2"                -- FCS
    );

begin
    -- DUT instantiation
    uut: MAC_RX_CONTROL
        port map (
            MAC_RX_CLK   => mac_rx_clk,
            MAC_RXD      => mac_rxd,
            MAC_RX_VALID => mac_rx_valid,
            MAC_RX_LAST  => mac_rx_last,
            MAC_RX_ERR   => mac_rx_err,
            LINE_NUMBER  => line_number,
            DATA         => data_fw,
            FW_OUT       => fw_out,
            START_OF_FRAME => start_of_frame,
            END_OF_FRAME   => end_of_frame
        );

    -- Clock generation
    clk_process : process
    begin
        while true loop
            mac_rx_clk <= '0';
            wait for CLK_PERIOD / 2;
            mac_rx_clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Stimulus
    stim_proc : process
    begin
        wait for 20 ns;
        mac_rx_valid <= '1';
        mac_rx_err <= '0';

        for i in 0 to test_packet'length - 1 loop
            mac_rxd <= test_packet(i);
            if i = 0 then
                start_of_frame <= '1';
            else
                start_of_frame <= '0';
            end if;

            if i = test_packet'length - 1 then
                mac_rx_last <= '1';
                end_of_frame <= '1';
            else
                mac_rx_last <= '0';
                end_of_frame <= '0';
            end if;

            wait for CLK_PERIOD;
        end loop;

        mac_rx_valid <= '0';
        mac_rx_last <= '0';
        end_of_frame <= '0';
        wait;
    end process;

end tb;
