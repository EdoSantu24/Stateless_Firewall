-- Testbench for the Top Level Entity: 

	-- sending a packet that matches an allowing rule and FCS correct --> fw_result should be: 11
	-- sending a packet that matches a blocking rule with FCS correct --> fw_result should be: 10
	-- sending a packet with errors (FCS check fails) --> fw_result should be: 10

-- Firewall table in CheckRules block is:

	-- (x"C0A80101", x"C0A80102", x"11", x"1F90", x"0050", '0') -- block
  -- (x"C0A8002C", x"C0A80004", x"11", x"0400", x"0400", '1') -- allow
  -- (x"C0A80101", x"C0A80102", x"06", x"1F90", x"0050", '1') -- allow --> THIS IS THE PACKET WE ARE TESTING IN THIS TESTBENCH
	-- (x"00000000", x"00000000", x"06", x"0000", x"0000", '1') -- allow 
  
-- To test different packets, change the fields of src ip, dest ip, protocol, src port, dst port in the packet 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_TopPackCheck is
end tb_TopPackCheck;

architecture Behavioral of tb_TopPackCheck is

    component TopPackCheck
        Port (
            rst              : in  STD_LOGIC;
            clk              : in  std_logic;
            reset            : in  std_logic;
            valid            : in  std_logic;
            data_in          : in  std_logic_vector(7 downto 0);
            frame_length     : in  std_logic_vector(15 downto 0);
            fifo_write_enable: in  std_logic;
            fw_result        : out STD_LOGIC_VECTOR(1 downto 0);
            read_data        : out STD_LOGIC_VECTOR(7 downto 0);
            dummy_data       : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    signal clk                : std_logic := '0';
    signal reset              : std_logic := '1';
    signal valid              : std_logic := '0';
    signal data_in            : std_logic_vector(7 downto 0) := (others => '0');
    signal frame_length       : std_logic_vector(15 downto 0) := (others => '0');
    signal fw_result          : STD_LOGIC_VECTOR(1 downto 0);
    signal rst                : std_logic := '0';
    signal fifo_write_enable  : STD_LOGIC := '0';
    signal read_data          : STD_LOGIC_VECTOR(7 downto 0);
    signal dummy_data         : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Clock generation
    constant clk_period : time := 10 ns;
    signal done : boolean := false;

    -- Frame to test (72 bytes = 8 preamble + 60 dati + 4 CRC)
    type frame_array is array (0 to 71) of std_logic_vector(7 downto 0);
    constant test_frame : frame_array := (
        x"55", x"55", x"55", x"55", x"55", x"55", x"55", x"51", -- Preamble
        x"00", x"10", x"A4", x"7B", x"EA", x"80", -- Dest MAC
        x"00", x"12", x"34", x"56", x"78", x"90", -- Src MAC
        x"08", x"00",                             -- EtherType: IPv4
        x"45", x"00", x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", -- IP header start
        x"11",                                     -- Byte 23: Protocol (UDP = 17 = x"11")
        x"05", x"40",                             -- Checksum etc.
        x"C0", x"A8", x"00", x"2C",               -- Src IP
        x"C0", x"A8", x"00", x"04",               -- Dst IP
        x"04", x"00",                             -- Src Port
        x"04", x"00",                             -- Dst Port
        x"00", x"1A", x"2D", x"E8",               -- Payload
        x"00", x"01", x"02", x"03", x"04", x"05", x"06", x"07",
        x"08", x"09", x"0A", x"0B", x"0C", x"0D", x"0E", x"0F",
        x"10", x"11",                             -- More payload
        x"E6", x"C5", x"3D", x"B2"                -- FCS
    );

begin

    -- Instantiate the TopPackCheck module
    uut: TopPackCheck
        port map (
            rst              => rst,
            clk              => clk,
            reset            => reset,
            valid            => valid,
            data_in          => data_in,
            frame_length     => frame_length,
            fifo_write_enable => fifo_write_enable,
            fw_result        => fw_result,
            read_data        => read_data,
            dummy_data       => dummy_data
        );

    -- Clock generation process
    clk_process : process
    begin
        while not done loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stimulus : process
    begin
        wait for 20 ns;
        reset <= '0';
        rst <= '0';
        wait for 20 ns;
        frame_length <= std_logic_vector(to_unsigned(test_frame'length, 16));
        valid <= '1';

        for i in 0 to 71 loop
            data_in <= test_frame(i);
            wait for clk_period;
            
            if i = 1 then
                fifo_write_enable <= '1';
            end if;
            
            if i = 71 then
                valid <= '0';
            end if;
        end loop;

        wait for clk_period;
        reset <= '1';
        wait for clk_period;
        
        reset <= '0';
        wait for clk_period;
        fifo_write_enable <= '0';
        wait for 800 ns;
        done <= true;
        wait;
    end process;

end Behavioral;


