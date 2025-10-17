library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TopPackCheck is
    Port (
        rst              : in  STD_LOGIC;
        clk              : in  std_logic;
        reset            : in  std_logic;
        valid            : in  std_logic;
        data_in          : in  std_logic_vector(7 downto 0);
        frame_length     : in  std_logic_vector(15 downto 0);
        fifo_write_enable: in  STD_LOGIC;
        fw_result        : out STD_LOGIC_VECTOR(1 downto 0);
        read_data        : out STD_LOGIC_VECTOR(7 downto 0);
        dummy_data       : out STD_LOGIC_VECTOR(7 downto 0)
    );
end TopPackCheck;

architecture Behavioral of TopPackCheck is


    --signals between MAC_RX and FCS
    signal mac_rx_reset          : std_logic;
    signal mac_rx_clk            : std_logic;
    signal mac_rx_valid_1        : std_logic;
    signal mac_rx_start_of_frame : std_logic;
    signal mac_rx_end_of_frame   : std_logic;
    signal mac_rx_data_out       : std_logic_vector(7 downto 0);

    -- signals between FCS and MAC_RX_CONTROL
    signal fcs_error_signal : std_logic_vector(1 downto 0);
    --signal reset	       : std_logic;
    --signal valid	       : std_logic;
    signal fcs_last	       : std_logic;
    signal fcs_first	       : std_logic;
    signal fcs_data_out     : std_logic_vector(7 downto 0);

    -- signals between MAC_RX_CONTROL and PacketAnalyzer
    signal line_number    : STD_LOGIC_VECTOR(15 downto 0);
    signal fw_out         : STD_LOGIC_VECTOR(1 downto 0);
    signal data_in_1      : STD_LOGIC_VECTOR(7 downto 0);
    signal mac_end	     : std_logic;
    signal mac_start	     : std_logic;
    signal mac_rxd	     : STD_LOGIC_VECTOR(7 downto 0);
    signal mac_rx_valid	  : std_logic;
    signal mac_rx_last    : std_logic;
    signal mac_rx_err     : std_logic_vector(1 downto 0);

    -- PacketAnalyzer -> CheckRules
    signal src_ip_sig     : STD_LOGIC_VECTOR(31 downto 0);
    signal dst_ip_sig     : STD_LOGIC_VECTOR(31 downto 0);
    signal protocol_sig   : STD_LOGIC_VECTOR(7 downto 0);
    signal src_port_sig   : STD_LOGIC_VECTOR(15 downto 0);
    signal dst_port_sig   : STD_LOGIC_VECTOR(15 downto 0);
    signal data_ready_sig : STD_LOGIC;
    signal fw_out_sig     : STD_LOGIC_VECTOR(1 downto 0);  -- Output from PacketAnalyzer

    -- PacketAnalyzer -> FIFO
    signal fifo_data      : STD_LOGIC_VECTOR(7 downto 0);
    signal fifo_sof       : STD_LOGIC;
    signal fifo_eof       : STD_LOGIC;

    -- FIFO -> Top level
    signal fifo_read_data_out   : STD_LOGIC_VECTOR(7 downto 0);
    signal fifo_dummy_data_out  : STD_LOGIC_VECTOR(7 downto 0);
    
	 -- Internal firewall result signal
	 signal fw_result_sig        : STD_LOGIC_VECTOR(1 downto 0);

begin

	 --mac_rc istance
    mac_rx : entity work.MAC_RX
     port map (
      	GMII_RX_CLK    => clk,
      	GMII_RXD       => data_in,
      	GMII_RX_DV     => valid,
      	GMII_RX_RESET  => reset,
      	TOTAL_LENGTH   => frame_length,


      	MAC_RX_RESET   => mac_rx_reset,
         MAC_RX_CLK     => mac_rx_clk,
         MAC_RX_VALID   => mac_rx_valid_1,
         MAC_RX_FIRST   => mac_rx_start_of_frame,
         MAC_RX_LAST    => mac_rx_end_of_frame,
         MAC_RXD        => mac_rx_data_out
       );
		 
	 -- FCS istance
    fcs_inst : entity work.fcs
     port map (
      	clk            => mac_rx_clk,
      	reset          => mac_rx_reset,
      	valid	         => mac_rx_valid_1,
      	start_of_frame => mac_rx_start_of_frame,
      	end_of_frame   => mac_rx_end_of_frame,
      	data_in        => mac_rx_data_out,

      	fcs_error      => fcs_error_signal,
         last_of_frame  => fcs_last,
         first_of_frame => fcs_first,
         data_out       => fcs_data_out
       );

    -- MAC_RX_CONTROL instance
    MAC_RX_CONTROL_inst : entity work.MAC_RX_CONTROL
        port map (
            MAC_RX_CLK     => clk,
            MAC_RXD        => fcs_data_out,
            MAC_RX_VALID   => fcs_first,
            MAC_RX_LAST    => fcs_last,
            MAC_RX_ERR     => fcs_error_signal,

            LINE_NUMBER    => line_number,
            DATA           => data_in_1,
            FW_OUT         => fw_out,               
            START_OF_FRAME => mac_start,
            END_OF_FRAME   => mac_end
        );

    -- PacketAnalyzer instance
    PacketAnalyzer_inst : entity work.PacketAnalyzer
        port map (
            mac_rx_clk      => clk,
            line_number     => line_number,
            data_fw         => data_in_1,
            start_of_frame  => mac_start,
            end_of_frame    => mac_end,
            fw_out          => fw_out,             

            source_ip       => src_ip_sig,
            dest_ip         => dst_ip_sig,
            source_port     => src_port_sig,
            dest_port       => dst_port_sig,
            protocol        => protocol_sig,
            data_ready      => data_ready_sig,
            fw_out_check    => fw_out_sig,         
            fifo_data       => fifo_data,
            fifo_sof        => fifo_sof,
            fifo_eof        => fifo_eof
        );

    -- CheckRules instance
    CheckRules_inst : entity work.CheckRules
        port map (
            clk         => clk,
            rst         => rst,
            data_ready  => data_ready_sig,
            src_ip      => src_ip_sig,
            dst_ip      => dst_ip_sig,
            protocol    => protocol_sig,
            src_port    => src_port_sig,
            dst_port    => dst_port_sig,
            fw_out_in   => fw_out_sig,             
            fw_result   => fw_result_sig
        );

    -- FIFO instance
    FIFO_inst : entity work.async_fifo
        port map (
            reset          => rst,
            wclk           => clk,
            rclk           => clk,
	         write_enable   => fifo_write_enable,
            write_data_in  => fifo_data,
            SOP            => fifo_sof,
            EOP            => fifo_eof,
            FW_RESULT      => fw_result_sig,
            fifo_occu_in   => open,
            fifo_occu_out  => open,
            read_data_out  => fifo_read_data_out,
            dummy_data_out => fifo_dummy_data_out,
            fifo_full      => open,
            fifo_empty     => open
        );

    -- Top-level outputs
    read_data  <= fifo_read_data_out;
    dummy_data <= fifo_dummy_data_out;
    fw_result  <= fw_result_sig;

end Behavioral;

