library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity MAC_RX_CONTROL is
    Port (
        MAC_RX_CLK     : in  STD_LOGIC;
        MAC_RXD        : in  STD_LOGIC_VECTOR(7 downto 0);
        MAC_RX_VALID   : in  STD_LOGIC;  -- SOLO 1 ciclo all'inizio del pacchetto
        MAC_RX_LAST    : in  STD_LOGIC;
        MAC_RX_ERR     : in  STD_LOGIC_VECTOR(1 downto 0);
        LINE_NUMBER    : out STD_LOGIC_VECTOR(15 downto 0);
        DATA           : out STD_LOGIC_VECTOR(7 downto 0);
        FW_OUT         : out STD_LOGIC_VECTOR(1 downto 0);
        START_OF_FRAME : out STD_LOGIC;
        END_OF_FRAME   : out STD_LOGIC
    );
end MAC_RX_CONTROL;

architecture Behavioral of MAC_RX_CONTROL is
    signal line_counter : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal in_packet    : STD_LOGIC := '0';  -- stato interno: siamo nel pacchetto?
    signal sop 		: STD_LOGIC;
begin
	
    process (MAC_RX_CLK)
    begin
        if rising_edge(MAC_RX_CLK) then
            -- Default outputs
            START_OF_FRAME <= MAC_RX_VALID;
            END_OF_FRAME   <= MAC_RX_LAST;
	    FW_OUT       <= MAC_RX_ERR;
	    DATA         <= MAC_RXD;
	    if in_packet = '0' then
		line_counter <= (others => '0');
	    end if;
	    	
		if sop = '1' then
	    		LINE_NUMBER <= line_counter + 1;
		end if;

            -- Inizio pacchetto: MAC_RX_VALID è 1 SOLO un ciclo
            if MAC_RX_VALID = '1' then
		sop <= '1';
                line_counter <= (others => '0');
                --START_OF_FRAME <= '1';
                in_packet    <= '1';  -- ora siamo nel pacchetto
            elsif in_packet = '1' then
                -- Stiamo ricevendo il pacchetto
                line_counter <= line_counter + 1;
		
                -- Se questo è l'ultimo byte
                if MAC_RX_LAST = '1' then
                    --END_OF_FRAME <= '1';
                    in_packet    <= '0';  -- fine pacchetto
		    sop <= '0';
                end if;
            end if;
		if MAC_RX_VALID = '1' then
	   		LINE_NUMBER <= line_counter;
		end if;
        end if;
    end process;

end Behavioral;
