library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fcs is
end tb_fcs;

architecture sim of tb_fcs is

  -- Component declaration
  component fcs
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      valid          : in  std_logic;
      start_of_frame : in  std_logic;
      end_of_frame   : in  std_logic;
      data_in        : in  std_logic_vector(7 downto 0);
      last_of_frame  : out std_logic;
      first_of_frame : out std_logic;
      data_out       : out  std_logic_vector(7 downto 0);
      fcs_error      : out std_logic_vector(1 downto 0)
    );
  end component;

  signal clk            : std_logic := '0';
  signal reset          : std_logic := '1';
  signal valid          : std_logic := '0';
  signal start_of_frame : std_logic := '0';
  signal end_of_frame   : std_logic := '0';
  signal data_in        : std_logic_vector(7 downto 0) := (others => '0');
  signal fcs_error      : std_logic_vector(1 downto 0) ;

  -- Clock generation
  constant clk_period : time := 10 ns;
  signal done : boolean := false;

  -- Frame to test (64 bytes = 60 dati + 4 CRC)
  type frame_array is array (0 to 63) of std_logic_vector(7 downto 0);
  constant test_frame : frame_array := (
    x"00", x"10", x"A4", x"7B", x"EA", x"80", x"00", x"12",
    x"34", x"56", x"78", x"90", x"08", x"00", x"45", x"00",
    x"00", x"2E", x"B3", x"FE", x"00", x"00", x"80", x"11",
    x"05", x"40", x"C0", x"A8", x"00", x"2C", x"C0", x"A8",
    x"00", x"04", x"04", x"00", x"04", x"00", x"00", x"1A",
    x"2D", x"E8", x"00", x"01", x"02", x"03", x"04", x"05",
    x"06", x"07", x"08", x"09", x"0A", x"0B", x"0C", x"0D",
    x"0E", x"0F", x"10", x"11", -- dati
    x"E6", x"C5", x"35", x"11"   -- FCS 3D B2

  );

begin

  -- Instantiate the fcs module
  uut: fcs
    port map (
      clk            => clk,
      reset          => reset,
      valid          => valid,
      start_of_frame => start_of_frame,
      end_of_frame   => end_of_frame,
      data_in        => data_in,
      fcs_error      => fcs_error
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
    wait for 20 ns;

    start_of_frame <= '1';

    for i in 0 to 63 loop
      data_in <= test_frame(i);
      wait for clk_period;
      if i = 0 then
	wait for clk_period;
        start_of_frame <= '0';
      end if;
      if i >= 59 then
	valid <= '1';
	if i = 63 then
		end_of_frame <= '1';
	end if;
      end if;
    end loop;
    wait for clk_period;
    end_of_frame <= '0';
    reset <='1';
    wait for clk_period;
    
    reset <='0';

    -- Let the simulation run a bit
    wait for 50 ns;
    done <= true;
    wait;
  end process;

end sim;
