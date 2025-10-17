library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_MAC_RX is
end tb_MAC_RX;

architecture sim of tb_MAC_RX is

    -- Component declaration
    component MAC_RX
        Port (
            GMII_RX_CLK    : in std_logic;
            GMII_RXD       : in std_logic_vector(7 downto 0);
            GMII_RX_DV     : in std_logic;
            GMII_RX_RESET  : in std_logic;
            TOTAL_LENGTH   : in std_logic_vector(15 downto 0);

            MAC_RX_CLK     : out std_logic;
            MAC_RXD        : out std_logic_vector(7 downto 0);
            MAC_RX_VALID   : out std_logic;
            MAC_RX_FIRST   : out std_logic;
            MAC_RX_LAST    : out std_logic;
            MAC_RX_RESET   : out std_logic
        );
    end component;

    -- Signals
    signal clk            : std_logic := '0';
    signal rst            : std_logic := '0';
    signal rx_dv          : std_logic := '0';
    signal rx_d           : std_logic_vector(7 downto 0) := (others => '0');
    signal total_len      : std_logic_vector(15 downto 0) := (others => '0');

    signal mac_clk        : std_logic;
    signal mac_d          : std_logic_vector(7 downto 0);
    signal mac_valid      : std_logic;
    signal mac_first      : std_logic;
    signal mac_last       : std_logic;
    signal mac_reset      : std_logic;

    -- Clock generation (125 MHz typical for GMII)
    constant clk_period : time := 8 ns;

begin

    -- Instantiate DUT
    uut: MAC_RX
        Port map (
            GMII_RX_CLK    => clk,
            GMII_RXD       => rx_d,
            GMII_RX_DV     => rx_dv,
            GMII_RX_RESET  => rst,
            TOTAL_LENGTH   => total_len,

            MAC_RX_CLK     => mac_clk,
            MAC_RXD        => mac_d,
            MAC_RX_VALID   => mac_valid,
            MAC_RX_FIRST   => mac_first,
            MAC_RX_LAST    => mac_last,
            MAC_RX_RESET   => mac_reset
        );

    -- Clock process
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    -- Stimulus process
    stimulus : process
        procedure send_packet(packet_len : integer) is
        begin
            total_len <= std_logic_vector(to_unsigned(packet_len, 16));
            rx_dv <= '1';
            for i in 0 to packet_len - 1 loop
                rx_d <= std_logic_vector(to_unsigned(i mod 256, 8));
                wait for clk_period;
            end loop;
            rx_dv <= '0';
            wait for clk_period * 5;  -- Idle period between packets
        end procedure;
    begin
        -- Reset
        rst <= '1';
        wait for clk_period * 2;
        rst <= '0';

        -- Send 3 packets: 72, 64, and 80 bytes long
        wait for clk_period * 5;
        send_packet(72);
        send_packet(64);
        send_packet(80);

        -- Finish
        wait for clk_period * 20;
        assert false report "Simulation finished" severity failure;
    end process;

end sim;

