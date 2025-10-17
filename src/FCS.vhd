library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use ieee.std_logic_textio.all;

entity fcs is
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
end fcs;

architecture behavioral of fcs is

  signal R           : std_logic_vector(31 downto 0);
  signal data        : std_logic_vector(7 downto 0);
  signal fcs_done    : std_logic;
  signal one_more    : std_logic;
  signal actived    : std_logic;
  
  signal byte_count  :  unsigned(2 downto 0);

  
  function slv_to_string(slv : std_logic_vector) return string is
  variable l : line;
  variable result : string(1 to slv'length);
begin
  write(l, slv);
  read(l, result);
  return result;
end function;

function int_to_str(n : integer) return string is
    variable temp : integer := n;
    variable str : string(1 to 11); -- abbastanza lunga per un int32
    variable i   : integer := 11;
    variable is_negative : boolean := false;
begin
    if n = 0 then
        return "0";
    end if;

    if n < 0 then
        is_negative := true;
        temp := -n;
    end if;

    while temp > 0 loop
        str(i) := character'val(character'pos('0') + (temp mod 10));
        temp := temp / 10;
        i := i - 1;
    end loop;

    if is_negative then
        str(i) := '-';
        i := i - 1;
    end if;

    return str(i+1 to 11);
end function;




begin
 
--Complementation of first 4 and last 4 bytes
 process (byte_count, start_of_frame, valid, data_in)
 begin
 	if (byte_count < 4) or (start_of_frame = '1') or (valid = '1') then
 		data <= not data_in;
	else
		data <= data_in;
 	end if;
 end process;


  --Main CRC computation
  process (clk, reset)
    --variable R_next : std_logic_vector(31 downto 0);
  begin
	
    if reset = '1' then
      R           <= (others => '0'); -- Initial value: 0xFFFFFFFF
      fcs_error   <= "01";
      fcs_done    <= '0';
      actived     <= '0';
	
    elsif rising_edge(clk) then
	last_of_frame <= end_of_frame;
        first_of_frame <= start_of_frame;
        data_out <= data_in;
	
      if start_of_frame = '1' then
        R           <= (others => '0'); -- Reset CRC on new frame
        fcs_done    <= '0';
	one_more    <= '0';
        fcs_error   <= "01";
	actived     <= '1';
      end if;


	if (start_of_frame = '1')or (valid = '1') then
 		byte_count <= (others => '0');
 	elsif byte_count < 4 then
 		byte_count <= byte_count + 1;
 	end if;

      if actived ='1' then
        -- CRC matrix calculation
        R(0) <= data(0)xor R(24)xor R(30);
	R(1) <= data(1)xor R(24)xor R(25)xor R(30)xor R(31);
	R(2) <= data(2)xor R(24)xor R(25)xor R(26)xor R(30)xor R(31);
	R(3) <= data(3)xor R(25)xor R(26)xor R(27)xor R(31);
 	R(4) <= data(4)xor R(24)xor R(26)xor R(27)xor R(28)xor R(30);
 	R(5) <= data(5)xor R(24)xor R(25)xor R(27)xor R(28)xor R(29)xor R(30)xor R(31);
 	R(6) <= data(6)xor R(25)xor R(26)xor R(28)xor R(29)xor R(30)xor R(31);
	R(7) <= data(7)xor R(24)xor R(26)xor R(27)xor R(29)xor R(31);
	R(8) <= R(0) xor R(24) xor R(25) xor R(27) xor R(28);
 	R(9) <= R(1) xor R(25) xor R(26) xor R(28) xor R(29);
	R(10) <= R(2) xor R(24) xor R(26) xor R(27) xor R(29);
	R(11) <=R(3) xor R(24) xor R(25) xor R(27) xor R(28);
	R(12) <=R(4) xor R(24) xor R(25) xor R(26) xor R(28) xor R(29) xor R(30);
	R(13) <=R(5) xor R(25) xor R(26) xor R(27) xor R(29) xor R(30) xor R(31);
	R(14) <=R(6) xor R(26) xor R(27) xor R(28) xor R(30) xor R(31);
	R(15) <=R(7) xor R(27) xor R(28) xor R(29) xor R(31);
	R(16) <=R(8) xor R(24) xor R(28) xor R(29);
	R(17) <=R(9) xor R(25) xor R(29) xor R(30);
	R(18) <=R(10) xor R(26) xor R(30) xor R(31);
	R(19) <=R(11) xor R(27) xor R(31);
	R(20) <=R(12) xor R(28);
	R(21) <=R(13) xor R(29);
	R(22) <=R(14) xor R(24);
	R(23) <=R(15) xor R(24) xor R(25) xor R(30);
	R(24) <=R(16) xor R(25) xor R(26) xor R(31);
	R(25) <=R(17) xor R(26) xor R(27);
	R(26) <=R(18) xor R(24) xor R(27) xor R(28) xor R(30);
	R(27) <=R(19) xor R(25) xor R(28) xor R(29) xor R(31);
	R(28) <=R(20) xor R(26) xor R(29) xor R(30);
	R(29) <=R(21) xor R(27) xor R(30) xor R(31);
	R(30) <=R(22) xor R(28) xor R(31);
	R(31) <=R(23) xor R(29);
       end if;
	report "Data in        = " & slv_to_string(data);
	report "R (at some point)        = " & slv_to_string(R);
	--report "byte_count        = " & valid;
	if end_of_frame = '1' then
        one_more <= '1';
      end if;
	if one_more = '1' then
        fcs_done <= '1';
      end if;
	
      end if;

      -- End of frame handling
	--report "R (before final xor)        = " & slv_to_string(R);

        -- Check CRC result (with final XOR 0xFFFFFFFF)
       if  (R = x"00000000") and (fcs_done = '1') then 
        	fcs_error <= "10"; -- No error
		fcs_done    <= '0';
		one_more <= '0';
       elsif (R /= x"00000000") and (fcs_done = '1')   then
       		fcs_error <= "11";
		fcs_done    <= '0';
		one_more <= '0';
       else
          	fcs_error <= "01"; -- Error
       end if;

	
  end process;

end behavioral;
