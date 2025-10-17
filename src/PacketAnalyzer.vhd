library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PacketAnalyzer is
    Port (
        mac_rx_clk     : in  STD_LOGIC;
        line_number    : in  STD_LOGIC_VECTOR(15 downto 0);
        data_fw        : in  STD_LOGIC_VECTOR(7 downto 0);
        start_of_frame : in  STD_LOGIC;
        end_of_frame   : in  STD_LOGIC;
        fw_out         : in  STD_LOGIC_VECTOR(1 downto 0);  -- input dal FCS

        -- Output verso CheckRules
        source_ip      : out STD_LOGIC_VECTOR(31 downto 0);
        dest_ip        : out STD_LOGIC_VECTOR(31 downto 0);
        source_port    : out STD_LOGIC_VECTOR(15 downto 0);
        dest_port      : out STD_LOGIC_VECTOR(15 downto 0);
        protocol       : out STD_LOGIC_VECTOR(7 downto 0);
        data_ready     : out STD_LOGIC;
        fw_out_check   : out STD_LOGIC_VECTOR(1 downto 0);  -- rinominato

        -- Output verso FIFO
        fifo_data      : out STD_LOGIC_VECTOR(7 downto 0);
        fifo_sof       : out STD_LOGIC;
        fifo_eof       : out STD_LOGIC
    );
end PacketAnalyzer;

architecture Behavioral of PacketAnalyzer is
    type state_type is (IDLE, CAPTURING, READY);
    signal current_state : state_type := IDLE;

    signal src_ip_reg    : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal dst_ip_reg    : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal src_port_reg  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal dst_port_reg  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal protocol_reg  : STD_LOGIC_VECTOR(7 downto 0)  := (others => '0');
    signal ready_reg     : STD_LOGIC := '0';
begin

    process(mac_rx_clk)
    begin
        if rising_edge(mac_rx_clk) then
            -- Forward dati al FIFO
            fifo_data     <= data_fw;
            fifo_sof      <= start_of_frame;
            fifo_eof      <= end_of_frame;

            -- Inoltra fw_out a CheckRules
            fw_out_check  <= fw_out;

            -- FSM per catturare i campi del pacchetto
            case current_state is
                when IDLE =>
                    ready_reg <= '0';
                    if start_of_frame = '1' then
                        current_state <= CAPTURING;
                    end if;

                when CAPTURING =>
                    case line_number is
                        when X"0017" => protocol_reg <= data_fw;
                        when X"001A" => src_ip_reg(31 downto 24) <= data_fw;
                        when X"001B" => src_ip_reg(23 downto 16) <= data_fw;
                        when X"001C" => src_ip_reg(15 downto 8)  <= data_fw;
                        when X"001D" => src_ip_reg(7 downto 0)   <= data_fw;
                        when X"001E" => dst_ip_reg(31 downto 24) <= data_fw;
                        when X"001F" => dst_ip_reg(23 downto 16) <= data_fw;
                        when X"0020" => dst_ip_reg(15 downto 8)  <= data_fw;
                        when X"0021" => dst_ip_reg(7 downto 0)   <= data_fw;
                        when X"0022" => src_port_reg(15 downto 8) <= data_fw;
                        when X"0023" => src_port_reg(7 downto 0)  <= data_fw;
                        when X"0024" => dst_port_reg(15 downto 8) <= data_fw;
                        when X"0025" => dst_port_reg(7 downto 0)  <= data_fw;
                        when others => null;
                    end case;

                    if line_number = X"0025" then
                        current_state <= READY;
                    end if;

                when READY =>
                    ready_reg <= '1';
                    current_state <= IDLE;
            end case;
        end if;
    end process;

    -- Output dei registri
    source_ip    <= src_ip_reg;
    dest_ip      <= dst_ip_reg;
    source_port  <= src_port_reg;
    dest_port    <= dst_port_reg;
    protocol     <= protocol_reg;
    data_ready   <= ready_reg;

end Behavioral;
