library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MAC_RX is
    Port ( 
        -- GMII Interface
        GMII_RX_CLK    : in std_logic;
        GMII_RXD       : in std_logic_vector(7 downto 0);
        GMII_RX_DV     : in std_logic;
        GMII_RX_RESET  : in std_logic;
        TOTAL_LENGTH   : in std_logic_vector(15 downto 0);  -- Total packet length input at runtime

        -- MAC RX Interface
        MAC_RX_CLK     : out std_logic;
        MAC_RXD        : out std_logic_vector(7 downto 0);
        MAC_RX_VALID   : out std_logic;
        MAC_RX_FIRST   : out std_logic;
        MAC_RX_LAST    : out std_logic;
        MAC_RX_RESET   : out std_logic
    );
end MAC_RX;

architecture Behavioral of MAC_RX is

    signal byte_count      : integer range 0 to 65535 := 0;
    signal preamble_done   : std_logic := '0';

begin

    -- Forward GMII clock and reset to MAC
    MAC_RX_CLK   <= GMII_RX_CLK;
    MAC_RX_RESET <= GMII_RX_RESET;

    process(GMII_RX_CLK)
        variable total_len : integer := 0;
    begin
        if rising_edge(GMII_RX_CLK) then

            total_len := to_integer(unsigned(TOTAL_LENGTH));

            if GMII_RX_DV = '1' then
                

                -- Handle preamble end detection (first 8 bytes)
                if byte_count = 6 then
                    preamble_done <= '1';
                end if;

                -- Set MAC_RX_FIRST at first byte after preamble
                if byte_count = 8 then
                    MAC_RX_FIRST <= '1';
                else
                    MAC_RX_FIRST <= '0';
                end if;

                -- Set MAC_RX_VALID for bytes after preamble until last byte
                if byte_count > total_len - 5 then
                    MAC_RX_VALID <= '1';
                end if;

                -- Increment byte counter or reset after last byte
                if byte_count = total_len - 1 then
                    byte_count    <= 0;
                    preamble_done <= '0';
                else
                    byte_count <= byte_count + 1;
                end if;
		MAC_RXD <= GMII_RXD;

                -- Set MAC_RX_LAST only for the final byte
                if byte_count = total_len - 1 then
                    MAC_RX_LAST  <= '1';
                else
                    MAC_RX_LAST <= '0';
                end if;
            else
                -- No valid data; reset signals
                MAC_RX_VALID <= '0';	
                MAC_RX_FIRST <= '0';
                MAC_RX_LAST  <= '0';
                byte_count   <= 0;
                preamble_done <= '0';
            end if;

        end if;
    end process;

end Behavioral;


