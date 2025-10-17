library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PacketAnalyzer_tb is
end PacketAnalyzer_tb;

architecture tb of PacketAnalyzer_tb is
    signal mac_rx_clk      : STD_LOGIC := '0';
    signal line_number     : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal data_fw         : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal start_of_frame  : STD_LOGIC := '0';
    signal end_of_frame    : STD_LOGIC := '0';
    signal fw_out          : STD_LOGIC_VECTOR(1 downto 0);  -- input dal FCS

    signal source_ip       : STD_LOGIC_VECTOR(31 downto 0);
    signal dest_ip         : STD_LOGIC_VECTOR(31 downto 0);
    signal source_port     : STD_LOGIC_VECTOR(15 downto 0);
    signal dest_port       : STD_LOGIC_VECTOR(15 downto 0);
    signal protocol        : STD_LOGIC_VECTOR(7 downto 0);
    signal data_ready      : STD_LOGIC;
	 signal fw_out_check    : STD_LOGIC_VECTOR(1 downto 0);  -- rinominato


    signal fifo_data       : STD_LOGIC_VECTOR(7 downto 0);
    signal fifo_sof        : STD_LOGIC;
    signal fifo_eof        : STD_LOGIC;

    component PacketAnalyzer is
        Port (
            mac_rx_clk   : in  STD_LOGIC;
            line_number  : in  STD_LOGIC_VECTOR(15 downto 0);
            data_fw      : in  STD_LOGIC_VECTOR(7 downto 0);
            start_of_frame : in STD_LOGIC;
            end_of_frame   : in STD_LOGIC;
            fw_out         : in STD_LOGIC_VECTOR(1 downto 0);

            source_ip     : out STD_LOGIC_VECTOR(31 downto 0);
            dest_ip       : out STD_LOGIC_VECTOR(31 downto 0);
            source_port   : out STD_LOGIC_VECTOR(15 downto 0);
            dest_port     : out STD_LOGIC_VECTOR(15 downto 0);
            protocol      : out STD_LOGIC_VECTOR(7 downto 0);
            data_ready    : out STD_LOGIC;
				fw_out_check  : out STD_LOGIC_VECTOR(1 downto 0);

            fifo_data     : out STD_LOGIC_VECTOR(7 downto 0);
            fifo_sof      : out STD_LOGIC;
            fifo_eof      : out STD_LOGIC
        );
    end component;

    -- Example packet (including only relevant bytes for brevity)
    type byte_array is array (natural range <>) of STD_LOGIC_VECTOR(7 downto 0);
    constant test_packet : byte_array := (
        x"01", x"10", x"A4", x"7B", x"EA", x"80", -- Dest MAC
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

    constant CLK_PERIOD : time := 10 ns;

begin
    -- DUT Instantiation
    uut: PacketAnalyzer port map (
        mac_rx_clk   => mac_rx_clk,
        line_number  => line_number,
        data_fw      => data_fw,
        start_of_frame => start_of_frame,
        end_of_frame   => end_of_frame,
        fw_out         => fw_out,

        source_ip     => source_ip,
        dest_ip       => dest_ip,
        source_port   => source_port,
        dest_port     => dest_port,
        protocol      => protocol,
        data_ready    => data_ready,
		  fw_out_check  => fw_out_check,

        fifo_data     => fifo_data,
        fifo_sof      => fifo_sof,
        fifo_eof      => fifo_eof
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

    -- Stimulus process
    stim_proc: process
    begin
        -- Fase iniziale di inattività
        wait for 3 * CLK_PERIOD;

        -- Inizia la trasmissione: imposta primo byte e start_of_frame insieme
        for i in 0 to test_packet'length - 1 loop
            -- Imposta segnali prima del fronte attivo del clock
            data_fw <= test_packet(i);
            line_number <= std_logic_vector(to_unsigned(i, 16));
            fw_out <= "00";  -- inizialmente 00 durante la ricezione

            -- Imposta start_of_frame solo nel primo ciclo
            if i = 0 then
                start_of_frame <= '1';
            else
                start_of_frame <= '0';
            end if;

            -- Imposta end_of_frame solo all'ultimo ciclo
            if i = test_packet'length - 1 then
                end_of_frame <= '1';
            else
                end_of_frame <= '0';
            end if;

            wait for CLK_PERIOD;
        end loop;

        -- Dopo la fine della trasmissione, inviamo il risultato FCS
        start_of_frame <= '0';
        end_of_frame <= '0';
        data_fw <= (others => '0');

        -- Aspetta 1 ciclo di clock per simulare tempo di calcolo FCS
        wait for CLK_PERIOD;
        fw_out <= "10";  -- FCS segnala che il pacchetto è valido

        -- Attendi che `data_ready` venga settato
        wait for 100 ns;

        wait;
    end process;


end tb;