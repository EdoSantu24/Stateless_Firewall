library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity async_fifo is
    generic (
        FIFO_DEPTH : integer := 1522;
        PTR_WIDTH  : integer := 11
    );
    port (
        reset          : in std_logic;
        wclk           : in std_logic;
        rclk           : in std_logic;
        write_enable   : in std_logic;
        write_data_in  : in std_logic_vector(7 downto 0);
        SOP            : in std_logic;
        EOP            : in std_logic;
        FW_RESULT      : in std_logic_vector(1 downto 0); -- (0) = send to real, (1) = valid
        fifo_occu_in   : out std_logic_vector(PTR_WIDTH - 1 downto 0);
        fifo_occu_out  : out std_logic_vector(PTR_WIDTH - 1 downto 0);
        read_data_out  : out std_logic_vector(7 downto 0);
        dummy_data_out : out std_logic_vector(7 downto 0);
        fifo_full      : out std_logic;
        fifo_empty     : out std_logic
    );
end async_fifo;

architecture Behavioral of async_fifo is

    type memory_array is array (0 to FIFO_DEPTH - 1) of std_logic_vector(7 downto 0);
    signal mem : memory_array := (others => (others => '0'));

    -- Pointers
    signal wptr_bin  : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rptr_bin  : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal wptr_gray : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal rptr_gray : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');

    -- Sync
    signal rptr_gray_sync1, rptr_gray_sync2 : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');
    signal wptr_gray_sync1, wptr_gray_sync2 : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');

    -- Flags
    signal full_flag, empty_flag : std_logic := '0';

    -- Packet state
    signal packet_ready    : std_logic := '0';
    signal packet_result   : std_logic := '0'; -- 1: real output, 0: dummy
    signal packet_end_ptr  : std_logic_vector(PTR_WIDTH - 1 downto 0) := (others => '0');

    signal reading         : std_logic := '0';

    -- New FW_RESULT flag and value storage
    signal fw_result_active : std_logic := '0';  -- New flag to track FW_RESULT
    signal fw_result_value  : std_logic := '0';  -- Store FW_RESULT(0)

    -- Functions
    function bin2gray(bin : std_logic_vector) return std_logic_vector is
        variable gray : std_logic_vector(bin'range);
    begin
        gray(bin'high) := bin(bin'high);
        for i in bin'high - 1 downto bin'low loop
            gray(i) := bin(i+1) xor bin(i);
        end loop;
        return gray;
    end function;

    function gray2bin(gray : std_logic_vector) return std_logic_vector is
        variable bin : std_logic_vector(gray'range);
    begin
        bin(bin'high) := gray(bin'high);
        for i in bin'high - 1 downto bin'low loop
            bin(i) := bin(i+1) xor gray(i);
        end loop;
        return bin;
    end function;

begin

    -- WRITE
    process(wclk, reset)
    begin
        if reset = '1' then
            wptr_bin  <= (others => '0');
            wptr_gray <= (others => '0');
        elsif rising_edge(wclk) then
            -- Handle end of packet (EOP)
            if EOP = '1' then
                packet_end_ptr <= wptr_bin;
            end if;

            -- Write operation occurs when SOP = '1' and write_enable is also '1'
            if write_enable = '1' and full_flag = '0' then
                mem(to_integer(unsigned(wptr_bin))) <= write_data_in;
                wptr_bin  <= std_logic_vector(unsigned(wptr_bin) + 1);
                wptr_gray <= bin2gray(std_logic_vector(unsigned(wptr_bin) + 1));
            end if;
        end if;
    end process;

    -- READ
    process(rclk, reset)
    begin
        if reset = '1' then
            rptr_bin         <= (others => '0');
            rptr_gray        <= (others => '0');
            packet_ready     <= '0';
            packet_result    <= '0';
            reading          <= '0';
            fw_result_active <= '0';  -- Clear the FW_RESULT flag on reset
            fw_result_value  <= '0';  -- Clear the FW_RESULT value on reset
        elsif rising_edge(rclk) then

            -- Capture FW_RESULT when it becomes valid (FW_RESULT(1) = 1)
            if FW_RESULT(1) = '1' then
                fw_result_active <= '1';
                fw_result_value  <= FW_RESULT(0);  -- Store FW_RESULT(0)
            end if;

            -- Accept FW_RESULT if a packet is waiting
            if packet_ready = '0' and FW_RESULT(1) = '1' then
                packet_ready <= '1';
                packet_result <= FW_RESULT(0);

                reading <= '1';
            end if;

            -- Read if allowed
            if reading = '1' and empty_flag = '0' then
                if packet_result = '1' then
                    read_data_out <= mem(to_integer(unsigned(rptr_bin)));
                else
                    dummy_data_out <= mem(to_integer(unsigned(rptr_bin)));
                end if;

                rptr_bin  <= std_logic_vector(unsigned(rptr_bin) + 1);
                rptr_gray <= bin2gray(std_logic_vector(unsigned(rptr_bin) + 1));

                -- End of packet reading
                if rptr_bin = packet_end_ptr then
                    reading <= '0';
                    packet_ready <= '0';
                    fw_result_active <= '0';  -- Reset fw_result_active after reading the packet
                end if;
            end if;
        end if;
    end process;

    -- SYNC pointers
    process(wclk)
    begin
        if rising_edge(wclk) then
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end if;
    end process;

    process(rclk)
    begin
        if rising_edge(rclk) then
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end if;
    end process;

    -- STATUS flags
    process(wptr_gray, rptr_gray_sync2)
    begin
        if (bin2gray(std_logic_vector(unsigned(wptr_bin) + 1)) = rptr_gray_sync2) then
            full_flag <= '1';
        else
            full_flag <= '0';
        end if;
    end process;

    process(rptr_gray, wptr_gray_sync2)
    begin
        if rptr_gray = wptr_gray_sync2 then
            empty_flag <= '1';
        else
            empty_flag <= '0';
        end if;
    end process;

    -- OUTPUTS
    fifo_occu_in  <= std_logic_vector(to_unsigned(to_integer(unsigned(wptr_bin)) - to_integer(unsigned(gray2bin(rptr_gray_sync2))), PTR_WIDTH));
    fifo_occu_out <= std_logic_vector(to_unsigned(to_integer(unsigned(gray2bin(wptr_gray_sync2))) - to_integer(unsigned(rptr_bin)), PTR_WIDTH));
    fifo_full     <= full_flag;
    fifo_empty    <= empty_flag;

end Behavioral;
