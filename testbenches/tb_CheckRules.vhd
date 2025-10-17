library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CheckRules_tb is
end CheckRules_tb;

architecture Behavioral of CheckRules_tb is

    -- Component declaration
    component CheckRules
        Port (
            clk        : in  STD_LOGIC;
            rst        : in  STD_LOGIC;
            data_ready : in  STD_LOGIC;
            fw_out_in     : in  STD_LOGIC_VECTOR(1 downto 0);
            src_ip     : in  STD_LOGIC_VECTOR(31 downto 0);
            dst_ip     : in  STD_LOGIC_VECTOR(31 downto 0);
            protocol   : in  STD_LOGIC_VECTOR(7 downto 0);
            src_port   : in  STD_LOGIC_VECTOR(15 downto 0);
            dst_port   : in  STD_LOGIC_VECTOR(15 downto 0);
            fw_result  : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;

    -- Signals for testing
    signal clk        : STD_LOGIC := '0';
    signal rst        : STD_LOGIC := '0';
    signal data_ready : STD_LOGIC := '0';
    signal fw_out_in     : STD_LOGIC_VECTOR(1 downto 0) := (others => '0');
    signal src_ip     : STD_LOGIC_VECTOR(31 downto 0);
    signal dst_ip     : STD_LOGIC_VECTOR(31 downto 0);
    signal protocol   : STD_LOGIC_VECTOR(7 downto 0);
    signal src_port   : STD_LOGIC_VECTOR(15 downto 0);
    signal dst_port   : STD_LOGIC_VECTOR(15 downto 0);
    signal fw_result  : STD_LOGIC_VECTOR(1 downto 0);

    constant clk_period : time := 10 ns;

begin

    -- Instantiate the unit under test
    uut: CheckRules
        port map (
            clk        => clk,
            rst        => rst,
            data_ready => data_ready,
            fw_out_in     => fw_out_in,
            src_ip     => src_ip,
            dst_ip     => dst_ip,
            protocol   => protocol,
            src_port   => src_port,
            dst_port   => dst_port,
            fw_result  => fw_result
        );

    -- Clock process
    clk_process : process
    begin
        while now < 400 ns loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';

        -- Test 1: Match rule 0 (BLOCK) + valid FCS
        src_ip     <= x"C0A80101";
        dst_ip     <= x"C0A80102";
        protocol   <= x"06"; -- tcp specific block
        src_port   <= x"1F90";
        dst_port   <= x"0050";
        data_ready <= '1';
        wait for clk_period;
        data_ready <= '0';

        -- Simulate FCS ready and valid after a few cycles
        wait for 2 * clk_period;
        fw_out_in <= "10";  -- fw_out_in(1) = 1 (ready), fw_out_in(0) = 0 (FCS OK)
        wait for clk_period;
        fw_out_in <= "00";

        -- Test 2: Match rule 1 (ALLOW) + invalid FCS
        wait for clk_period;
        src_ip     <= x"C0A8002C";
        dst_ip     <= x"C0A80004";
        protocol   <= x"11"; --udp specific allow
        src_port   <= x"0400";
        dst_port   <= x"0400";
        data_ready <= '1';
        wait for clk_period;
        data_ready <= '0';

        wait for 2 * clk_period;
        fw_out_in <= "11";  -- fw_out_in(1) = 1 (ready), fw_out_in(0) = 1 (FCS ERROR)
        wait for clk_period;
        fw_out_in <= "00";

        -- Test 3: No match (default DENY) + valid FCS
        wait for clk_period;
        src_ip     <= x"C0A80032";  -- 192.168.0.50
        dst_ip     <= x"C0A80064";  -- 192.168.0.100
        protocol   <= x"11";        -- UDP (11)
        src_port   <= x"1388";      -- 5000 (Decimal)
        dst_port   <= x"0035";      -- 53 (Decimal, DNS)

        data_ready <= '1';
        wait for clk_period;
        data_ready <= '0';

        wait for 2 * clk_period;
        fw_out_in <= "10";  -- FCS OK
        wait for clk_period;
        fw_out_in <= "00";

        -- Test 4: Match rule 2 (ALLOW) + valid FCS
        wait for clk_period;
        src_ip     <= x"C0A8002C";
        dst_ip     <= x"C0A80004"; -- udp specific allow
        protocol   <= x"11";
        src_port   <= x"0400";
        dst_port   <= x"0400";
        data_ready <= '1';
        wait for clk_period;
        data_ready <= '0';

        wait for 2 * clk_period;
        fw_out_in <= "10";  -- FCS OK
        wait for clk_period;
        fw_out_in <= "00";
		  
		  -- Test 5: Allow TCP general packet + valid FCS
        wait for clk_period;
        src_ip     <= x"C0A80103";
        dst_ip     <= x"C0A80104";
        protocol   <= x"06"; -- tcp general allow
        src_port   <= x"1F90";
        dst_port   <= x"0050";
        data_ready <= '1';
        wait for clk_period;
        data_ready <= '0';

        wait for 2 * clk_period;
        fw_out_in <= "10";  -- FCS OK
        wait for clk_period;
        fw_out_in <= "00";

        wait;
    end process;

end Behavioral;

