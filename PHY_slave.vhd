
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY PHY_slave IS
    GENERIC (
        DATA_SIZE : NATURAL := 16);
    PORT (
        i_sys_clk   : IN std_logic;                                 -- system clock
        i_sys_rst   : IN std_logic;                                 -- system reset
        i_csn       : IN std_logic;                                 -- Slave Enable/select
        i_data      : IN std_logic_vector(DATA_SIZE - 1 DOWNTO 0);  -- Input data
        i_wr        : IN std_logic;                                 -- Active Low Write, Active High Read
        i_rd        : IN std_logic;                                 -- Active Low Write, Active High Read
        o_data      : OUT std_logic_vector(DATA_SIZE - 1 DOWNTO 0); --output data
        o_tx_ready  : OUT std_logic;                                -- Transmitter ready, can write another 
        o_rx_ready  : OUT std_logic;                                -- Receiver ready, can read data
        o_tx_error  : OUT std_logic;                                -- Transmitter error
        o_rx_error  : OUT std_logic;                                -- Receiver error
        i_cpol      : IN std_logic;                                 -- CPOL value - 0 or 1
        i_cpha      : IN std_logic;                                 -- CPHA value - 0 or 1 
        i_lsb_first : IN std_logic;                                 -- lsb first when '1' /msb first when -- '0'
        LVDS_IO     : INOUT std_logic;
        i_ssn       : IN std_logic_vector(1 DOWNTO 0); -- Slave Slect Active low
        i_sclk      : IN std_logic;                    -- Clock from phy Master
        miso_tri_en : OUT std_logic;
        o_tx_ack    : OUT std_logic;
        o_tx_no_ack : OUT std_logic
    );

END PHY_slave;

ARCHITECTURE rtl_arch OF PHY_slave IS
    SIGNAL data_in_reg_i            : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rxdata_reg_i             : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL txdata_reg_i             : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rx_shift_data_pos_sclk_i : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rx_shift_data_neg_sclk_i : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);

    SIGNAL tx_error_i : std_logic;
    SIGNAL rx_error_i : std_logic;
    SIGNAL tx_ready_i : std_logic;
    SIGNAL rx_ready_i : std_logic;

    SIGNAL miso_00_i, miso_01_i, miso_10_i, miso_11_i : std_logic;

    SIGNAL rx_done_pos_sclk_i, rx_done_neg_sclk_i, rx_done_reg1_i, rx_done_reg2_i, rx_done_reg3_i : std_logic;
    SIGNAL tx_done_pos_sclk_i, tx_done_neg_sclk_i, tx_done_reg1_i, tx_done_reg2_i, tx_done_reg3_i : std_logic;
    SIGNAL rx_data_count_pos_sclk_i                                                               : std_logic_vector(5 DOWNTO 0);
    SIGNAL rx_data_count_neg_sclk_i                                                               : std_logic_vector(5 DOWNTO 0);
    SIGNAL tx_data_count_pos_sclk_i                                                               : std_logic_vector(5 DOWNTO 0);
    SIGNAL tx_data_count_neg_sclk_i                                                               : std_logic_vector(5 DOWNTO 0);

    SIGNAL data_valid_i     : std_logic;
    SIGNAL tx_done_pulse_i  : std_logic;
    SIGNAL tx_error_reg_1_i : std_logic;
    SIGNAL rx_error_reg_1_i : std_logic;

BEGIN

    o_tx_ready <= tx_ready_i;
    o_rx_ready <= rx_ready_i;
    o_tx_error <= tx_error_i AND (NOT tx_error_reg_1_i);
    o_rx_error <= rx_error_i AND (NOT rx_error_reg_1_i);

    ----------------------------------------------------------------------------------------------------
    -- Data input latch process
    -- Latched only when slave enabled, Transmitter ready and wr is high.
    ----------------------------------------------------------------------------------------------------
    o_data <= rxdata_reg_i;
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            data_in_reg_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sys_clk) THEN
            IF (i_wr = '1' AND tx_ready_i = '1') THEN
                data_in_reg_i <= i_data;
            END IF;
        END IF;
    END PROCESS;

    --miso_tri_en <= i_ssn;

    ----------------------------------------------------------------------------------------------------
    -- Receive Data Register, mux it based on sampling
    -- Data latched based on Rx Done signal
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rxdata_reg_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sys_clk) THEN
            IF (rx_done_reg1_i = '1' AND rx_done_reg2_i = '0') THEN
                IF ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1')) THEN
                    rxdata_reg_i <= rx_shift_data_pos_sclk_i;
                ELSE
                    rxdata_reg_i <= rx_shift_data_neg_sclk_i;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ---------------------------------------------------------------------------------------------------
    -- Re-register data to be transmitted
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            txdata_reg_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sys_clk) THEN
            txdata_reg_i <= data_in_reg_i;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- Slave Receiver Section  		---------------------------------------------
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    --- input Sampling : Sample at posedge of SCLK for 
    --                  1. i_cpol=0 and i_cpha=0 
    --                  2. i_cpol=1 and i_cpha=1 
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_shift_data_pos_sclk_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sclk) THEN
            IF (i_ssn = "01" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
                IF (i_lsb_first = '1') THEN
                    rx_shift_data_pos_sclk_i <= LVDS_IO & rx_shift_data_pos_sclk_i(DATA_SIZE - 1 DOWNTO 1);
                ELSE
                    rx_shift_data_pos_sclk_i <= rx_shift_data_pos_sclk_i(DATA_SIZE - 2 DOWNTO 0) & LVDS_IO;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_data_count_pos_sclk_i <= (OTHERS => '0');
            rx_done_pos_sclk_i       <= '0';
        ELSIF rising_edge(i_sclk) THEN
            IF (i_ssn = "01" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
                IF (rx_data_count_pos_sclk_i = DATA_SIZE - 1) THEN
                    rx_data_count_pos_sclk_i <= (OTHERS => '0');
                    rx_done_pos_sclk_i       <= '1';
                ELSIF (i_ssn = "01") THEN
                    rx_data_count_pos_sclk_i <= rx_data_count_pos_sclk_i + 1;
                    rx_done_pos_sclk_i       <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    --- input Sampling : Sample at negedge of SCLK for
    -- 1. i_cpol=1 and i_cpha=0
    -- 2. i_cpol=0 and i_cpha=1
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_shift_data_neg_sclk_i <= (OTHERS => '0');
        ELSIF falling_edge(i_sclk) THEN
            IF (i_ssn = "01" AND ((i_cpol = '1' AND i_cpha = '0') OR (i_cpol = '0' AND i_cpha = '1'))) THEN
                IF (i_lsb_first = '1') THEN
                    rx_shift_data_neg_sclk_i <= LVDS_IO & rx_shift_data_neg_sclk_i(DATA_SIZE - 1 DOWNTO 1);
                ELSE
                    rx_shift_data_neg_sclk_i <= rx_shift_data_neg_sclk_i(DATA_SIZE - 2 DOWNTO 0) & LVDS_IO;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_data_count_neg_sclk_i <= (OTHERS => '0');
            rx_done_neg_sclk_i       <= '0';
        ELSIF falling_edge(i_sclk) THEN
            IF (rx_data_count_neg_sclk_i = DATA_SIZE - 1) THEN
                rx_data_count_neg_sclk_i <= (OTHERS => '0');
                rx_done_neg_sclk_i       <= '1';
            ELSIF (i_ssn = "01") THEN
                rx_data_count_neg_sclk_i <= rx_data_count_neg_sclk_i + 1;
                rx_done_neg_sclk_i       <= '0';
            END IF;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------
    --  Slave Receiver Receive Done signal generator
    -- This is based on CPOL and CPHA
    ----------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_done_reg1_i <= '0';
            rx_done_reg2_i <= '0';
            rx_done_reg3_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (i_ssn = "01" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
                rx_done_reg1_i <= rx_done_pos_sclk_i;
            ELSE
                rx_done_reg1_i <= rx_done_neg_sclk_i;
            END IF;
            rx_done_reg2_i <= rx_done_reg1_i;
            rx_done_reg3_i <= rx_done_reg2_i;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------------------------------
    -- Receiver ready at the end of reception.
    -- A valid receive data available at this time
    ----------------------------------------------------------------------------------------------------

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_ready_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (rx_done_reg2_i = '1' AND rx_done_reg3_i = '0') THEN
                rx_ready_i <= '1';
            ELSIF (i_ssn = "11") THEN
                rx_ready_i <= '1';
            ELSIF (i_ssn = "01") THEN
                rx_ready_i <= '0';
            END IF;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------------------------------
    -- Receive error when external interface hasn't read previous data
    -- A new data received, but last received data hasn't been read yet.
    ----------------------------------------------------------------------------------------------------

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_error_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (rx_ready_i = '0' AND i_rd = '1') THEN
                rx_error_i <= '1';
            ELSIF (i_rd = '1') THEN
                rx_error_i <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_error_reg_1_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            rx_error_reg_1_i <= rx_error_i;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------
    -- phy Slave Transmitter section  				      ----
    ----------------------------------------------------------------------------
    ----------------------------------------------------------------------------
    -- cpol=0 and cpha=0: data must be placed before rising edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (txdata_reg_i, tx_data_count_neg_sclk_i, i_lsb_first)
    BEGIN
        IF (i_lsb_first = '1') THEN
            miso_00_i <= txdata_reg_i(conv_integer(tx_data_count_neg_sclk_i));
        ELSE
            miso_00_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_neg_sclk_i - 1));
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------
    -- cpol=1 and cpha=0: data must be placed before falling edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (txdata_reg_i, tx_data_count_pos_sclk_i, i_lsb_first)
    BEGIN
        IF (i_lsb_first = '1') THEN
            miso_10_i <= txdata_reg_i(conv_integer(tx_data_count_pos_sclk_i));
        ELSE
            miso_10_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_pos_sclk_i - 1));
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- cpol=0 and cpha=1: data must be placed at rising edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            miso_01_i <= '1';
        ELSIF rising_edge(i_sclk) THEN
            IF (i_lsb_first = '1') THEN
                miso_01_i <= txdata_reg_i(conv_integer(tx_data_count_pos_sclk_i));
            ELSE
                miso_01_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_pos_sclk_i - 1));
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- cpol=1 and cpha=1: data must be placed at falling edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            miso_11_i <= '1';
        ELSIF falling_edge(i_sclk) THEN
            IF (i_lsb_first = '1') THEN
                miso_11_i <= txdata_reg_i(conv_integer(tx_data_count_neg_sclk_i));
            ELSE
                miso_11_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_neg_sclk_i - 1));
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- Tx count on falling edge of sclk for cpol=0 and cpha=0  -------
    -- and cpol=1 and cpha=1  				   -------
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_data_count_neg_sclk_i <= (OTHERS => '0');
            tx_done_neg_sclk_i       <= '0';
        ELSIF falling_edge(i_sclk) THEN
            IF (tx_data_count_neg_sclk_i = DATA_SIZE - 1) THEN
                tx_data_count_neg_sclk_i <= (OTHERS => '0');
                tx_done_neg_sclk_i       <= '1';
            ELSIF (i_ssn = "10") THEN
                tx_data_count_neg_sclk_i <= tx_data_count_neg_sclk_i + 1;
                tx_done_neg_sclk_i       <= '0';
            END IF;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------
    -- Tx count on rising edge of sclk for cpol=1 and cpha=0  -------
    -- and cpol=0 and cpha=1  				  -------
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_data_count_pos_sclk_i <= (OTHERS => '0');
            tx_done_pos_sclk_i       <= '0';
        ELSIF rising_edge(i_sclk) THEN
            IF (tx_data_count_pos_sclk_i = DATA_SIZE - 1) THEN
                tx_data_count_pos_sclk_i <= (OTHERS => '0');
                tx_done_pos_sclk_i       <= '1';
            ELSIF (i_ssn = "10") THEN
                tx_data_count_pos_sclk_i <= tx_data_count_pos_sclk_i + 1;
                tx_done_pos_sclk_i       <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_ssn, i_cpol, i_cpha, miso_00_i, miso_01_i, miso_10_i, miso_11_i)
    BEGIN
        IF (i_ssn = "10") THEN
            IF (i_cpol = '0' AND i_cpha = '0') THEN
                LVDS_IO <= miso_00_i;
            ELSIF (i_cpol = '0' AND i_cpha = '1') THEN
                LVDS_IO <= miso_01_i;
            ELSIF (i_cpol = '1' AND i_cpha = '0') THEN
                LVDS_IO <= miso_10_i;
            ELSE
                LVDS_IO <= miso_11_i;
            END IF;
        ELSE
            LVDS_IO <= 'Z';
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------------------
    -- Transmit done generation
    -- Muxed based on CPOL and CPHA
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_done_reg1_i <= '0';
            tx_done_reg2_i <= '0';
            tx_done_reg3_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            -- if (i_cpol = '0' and i_cpha = '0') or (i_cpol = '1' and i_cpha = '1')  then
            IF (i_cpol = '1' AND i_cpha = '0') OR (i_cpol = '0' AND i_cpha = '1') THEN
                tx_done_reg1_i <= tx_done_neg_sclk_i;
            ELSE
                tx_done_reg1_i <= tx_done_pos_sclk_i;
            END IF;
            tx_done_reg2_i <= tx_done_reg1_i;
            tx_done_reg3_i <= tx_done_reg2_i;
        END IF;
    END PROCESS;

    ------------------------------------------------------------------------------------------------
    -- Transmitter is ready at the end of Transmission
    -- Transmitter ready goes low as soon as ssn goes low
    ------------------------------------------------------------------------------------------------

    tx_ready : PROCESS (i_sys_clk, i_sys_rst)
    BEGIN                   -- process tx_ready
        IF i_sys_rst = '1' THEN -- asynchronous reset (active high)
            tx_ready_i <= '1';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN -- rising clock edge
            IF (tx_done_reg2_i = '1' AND tx_done_reg3_i = '0') THEN
                tx_ready_i <= '1';
            ELSIF (i_ssn = "11") THEN
                tx_ready_i <= '1';
            ELSIF (i_ssn = "10") THEN
                tx_ready_i <= '0';
            END IF;
        END IF;
    END PROCESS tx_ready;

    ----------------------------------------------------------------------------------------------------
    -- Transmitter error when a data is written while transmitter busy transmitting data
    -- (busy when Tx Ready = 0)
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_error_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (tx_ready_i = '0' AND i_wr = '1') THEN
                tx_error_i <= '1';
            ELSIF (i_wr = '1') THEN
                tx_error_i <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_error_reg_1_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            tx_error_reg_1_i <= tx_error_i;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------------------
    -- Tx ACK
    ----------------------------------------------------------------------------------------------------
    ------------------------------------------------------------------------------------------------
    -- Data Valid in  slave interface
    ------------------------------------------------------------------------------------------------
    data_valid_proc : PROCESS (i_sys_clk, i_sys_rst)
    BEGIN                   -- process data_valid_proc
        IF i_sys_rst = '1' THEN -- asynchronous reset (active high)
            data_valid_i <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN -- rising clock edge
            IF (i_wr = '1' AND i_ssn = "10") THEN
                data_valid_i <= '1';
            ELSIF tx_done_pulse_i = '1' THEN
                data_valid_i <= '0';
            ELSIF i_ssn = "11" THEN
                data_valid_i <= '0';
            END IF;
        END IF;
    END PROCESS data_valid_proc;
    tx_ack_proc : PROCESS (i_sys_clk, i_sys_rst)
    BEGIN                   -- process data_valid_proc
        IF i_sys_rst = '1' THEN -- asynchronous reset (active high)
            o_tx_ack <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN -- rising clock edge
            IF (i_ssn = "11" AND data_valid_i = '1') THEN
                o_tx_ack <= '0';
            ELSIF tx_done_pulse_i = '1' AND data_valid_i = '1' THEN
                o_tx_ack <= '1';
            ELSE
                o_tx_ack <= '0';
            END IF;
        END IF;
    END PROCESS tx_ack_proc;

    tx_no_ack_proc : PROCESS (i_sys_clk, i_sys_rst)
    BEGIN                   -- process data_valid_proc
        IF i_sys_rst = '1' THEN -- asynchronous reset (active high)
            o_tx_no_ack <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN -- rising clock edge
            IF (i_ssn = "11" AND data_valid_i = '1') THEN
                o_tx_no_ack <= '1';
            ELSIF tx_done_reg3_i = '1' AND data_valid_i = '1' THEN
                o_tx_no_ack <= '0';
            ELSE
                o_tx_no_ack <= '0';
            END IF;
        END IF;
    END PROCESS tx_no_ack_proc;

    tx_done_pulse_i <= tx_done_reg2_i AND (NOT tx_done_reg3_i);

END rtl_arch;