library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CheckRules is
    Port (
        clk        : in  STD_LOGIC;
        rst        : in  STD_LOGIC;
        data_ready : in  STD_LOGIC;
        fw_out_in  : in  STD_LOGIC_VECTOR(1 downto 0); -- fw_out_in(1) = ready, fw_out_in(0) = fcs_error
        src_ip     : in  STD_LOGIC_VECTOR(31 downto 0);
        dst_ip     : in  STD_LOGIC_VECTOR(31 downto 0);
        protocol   : in  STD_LOGIC_VECTOR(7 downto 0);
        src_port   : in  STD_LOGIC_VECTOR(15 downto 0);
        dst_port   : in  STD_LOGIC_VECTOR(15 downto 0);
        fw_result  : out STD_LOGIC_VECTOR(1 downto 0)  -- fw_result(1) = ready, fw_result(0) = allow
    );
end CheckRules;

architecture Behavioral of CheckRules is

    type rule_t is record
        src_ip         : STD_LOGIC_VECTOR(31 downto 0);
        dst_ip         : STD_LOGIC_VECTOR(31 downto 0);
        protocol       : STD_LOGIC_VECTOR(7 downto 0);
        src_port       : STD_LOGIC_VECTOR(15 downto 0);
        dst_port       : STD_LOGIC_VECTOR(15 downto 0);
        src_ip_mask    : STD_LOGIC_VECTOR(31 downto 0);
        dst_ip_mask    : STD_LOGIC_VECTOR(31 downto 0);
        protocol_mask  : STD_LOGIC_VECTOR(7 downto 0);
        src_port_mask  : STD_LOGIC_VECTOR(15 downto 0);
        dst_port_mask  : STD_LOGIC_VECTOR(15 downto 0);
        allow          : STD_LOGIC;
    end record;

    type rule_array_t is array (0 to 3) of rule_t;

    -- Rule list: block UDP, allow specific UDP, etc.
    constant rules : rule_array_t := (
        -- Block UDP from 192.168.1.1 to 192.168.1.2
        (x"C0A80101", x"C0A80102", x"11", x"1F90", x"0050",
         x"FFFFFFFF", x"FFFFFFFF", x"FF", x"FFFF", x"FFFF",
         '0'),

        -- Allow specific UDP packet
        (x"C0A8002C", x"C0A80004", x"11", x"0400", x"0400",
         x"FFFFFFFF", x"FFFFFFFF", x"FF", x"FFFF", x"FFFF",
         '1'), -- ALLOW

        -- Block TCP from 192.168.1.1 to 192.168.1.2
        (x"C0A80101", x"C0A80102", x"06", x"1F90", x"0050",
         x"FFFFFFFF", x"FFFFFFFF", x"FF", x"FFFF", x"FFFF",
         '0'),

        -- Default allow for TCP (example of lower-priority ALLOW)
        (x"00000000", x"00000000", x"06", x"0000", x"0000",
         x"00000000", x"00000000", x"FF", x"0000", x"0000",
         '1')
    );

    signal rule_result_ready : STD_LOGIC := '0';
    signal rule_result_value : STD_LOGIC := '0';

begin

    process(clk, rst)
        variable matched_allow      : boolean := false;
        variable matched_block      : boolean := false;
        variable allow_match_value  : STD_LOGIC := '0';
    begin
        if rst = '1' then
            rule_result_ready <= '0';
            rule_result_value <= '0';
            fw_result         <= (others => '0');
        elsif rising_edge(clk) then
            -- Step 1: Check rules only when data is ready
            if data_ready = '1' then
                matched_allow := false;
                matched_block := false;

                for i in 0 to rules'high loop
                    if (src_ip and rules(i).src_ip_mask) = (rules(i).src_ip and rules(i).src_ip_mask) and
                       (dst_ip and rules(i).dst_ip_mask) = (rules(i).dst_ip and rules(i).dst_ip_mask) and
                       (protocol and rules(i).protocol_mask) = (rules(i).protocol and rules(i).protocol_mask) and
                       (src_port and rules(i).src_port_mask) = (rules(i).src_port and rules(i).src_port_mask) and
                       (dst_port and rules(i).dst_port_mask) = (rules(i).dst_port and rules(i).dst_port_mask) then
                        
                        if rules(i).allow = '0' then
                            matched_block := true;
                            exit; -- No need to check more rules; block wins
                        elsif not matched_allow then
                            matched_allow := true;
                            allow_match_value := '1'; -- Save allow decision
                        end if;
                    end if;
                end loop;

                if matched_block then
                    rule_result_value <= '0'; -- BLOCK
                elsif matched_allow then
                    rule_result_value <= allow_match_value; -- ALLOW
                else
                    rule_result_value <= '0'; -- Default deny
                end if;

                rule_result_ready <= '1';
            end if;

            -- Step 2: Output result only when FCS is ready
            if fw_out_in(1) = '1' and rule_result_ready = '1' then
                fw_result(1) <= '1'; -- Result ready
                fw_result(0) <= rule_result_value and not fw_out_in(0); -- Apply FCS check
                rule_result_ready <= '0'; -- Reset for next packet
            else
                fw_result(1) <= '0'; -- No result ready
                fw_result(0) <= '0';
            end if;
        end if;
    end process;

end Behavioral;


