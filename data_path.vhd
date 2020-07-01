
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY PHY_data_path IS
    GENERIC (
        DATA_SIZE : INTEGER := 10;
        FIFO_REQ  : BOOLEAN := FALSE);
    PORT (
        i_sys_clk   : IN std_logic;                                -- system clock
        i_sys_rst   : IN std_logic;                                -- system reset
        i_csn       : IN std_logic;                                -- Master Enable/select
        i_data      : IN std_logic_vector(DATA_SIZE - 1 DOWNTO 0); -- Input data
        i_wr        : IN std_logic;                                -- Active Low Write, Active High Read
        i_rd        : IN std_logic;                                -- Active Low Write, Active High Read
        i_PHY_start : IN std_logic;
        o_data      : OUT std_logic_vector(DATA_SIZE - 1 DOWNTO 0); --output data
        o_tx_ready  : OUT std_logic;                                -- Transmitter ready, can write another 
        o_rx_ready  : OUT std_logic;                                -- Receiver ready, can read data
        o_tx_error  : OUT std_logic;                                -- Transmitter error
        o_rx_error  : OUT std_logic;                                -- Receiver error
        i_cpol      : IN std_logic;                                 -- CPOL value - 0 or 1
        i_cpha      : IN std_logic;                                 -- CPHA value - 0 or 1 
        i_lsb_first : IN std_logic;                                 -- lsb first when '1' /msb first when -- '0'
        o_intr      : OUT std_logic;
        io_LVDS     : INOUT std_logic;
        i_ssn       : IN std_logic_vector(1 DOWNTO 0); -- Slave Slect Active low
        i_sclk      : IN std_logic                     -- Clock from PHY Master clock gen
    );

END PHY_data_path;

ARCHITECTURE rtl_arch OF PHY_data_path IS

    SIGNAL data_in_reg_i            : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL data_in                  : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rxdata_reg_i             : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL txdata_reg_i             : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rx_shift_data_pos_sclk_i : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL rx_shift_data_neg_sclk_i : std_logic_vector(DATA_SIZE - 1 DOWNTO 0);
    SIGNAL tx_error_i               : std_logic;
    SIGNAL rx_error_i               : std_logic;
    SIGNAL tx_ready_i               : std_logic := '1'; -- Initialization
    SIGNAL rx_ready_i               : std_logic;
    SIGNAL ReadHalfFull_i           : std_logic;
    SIGNAL d1_TxReady_i             : std_logic;
    SIGNAL d2_TxReady_i             : std_logic;
    SIGNAL d1_RxReady_i             : std_logic;
    SIGNAL d2_RxReady_i             : std_logic;
    SIGNAL mosi_00_i                : std_logic;
    SIGNAL mosi_01_i                : std_logic;
    SIGNAL mosi_10_i                : std_logic;
    SIGNAL mosi_11_i                : std_logic;
    SIGNAL rx_done_pos_sclk_i       : std_logic;
    SIGNAL rx_done_neg_sclk_i       : std_logic;
    SIGNAL rx_done_reg1_i           : std_logic;
    SIGNAL rx_done_reg2_i           : std_logic;
    SIGNAL rx_done_reg3_i           : std_logic;
    SIGNAL tx_done_pos_sclk_i       : std_logic;
    SIGNAL tx_done_neg_sclk_i       : std_logic;
    SIGNAL tx_done_reg1_i           : std_logic;
    SIGNAL tx_done_reg2_i           : std_logic;
    SIGNAL tx_done_reg3_i           : std_logic;
    SIGNAL rx_data_count_pos_sclk_i : std_logic_vector(5 DOWNTO 0);
    SIGNAL rx_data_count_neg_sclk_i : std_logic_vector(5 DOWNTO 0);
    SIGNAL tx_data_count_pos_sclk_i : std_logic_vector(5 DOWNTO 0);
    SIGNAL tx_data_count_neg_sclk_i : std_logic_vector(5 DOWNTO 0);
    SIGNAL dummy_i                  : std_logic_vector(7 DOWNTO 0);
    SIGNAL dummy_rd                 : std_logic_vector(7 DOWNTO 0) := (OTHERS => '0');

BEGIN

    ----------------------------------------------------------------------------------------------------
    ------------------- Output signals Generation ------------------------------------------------------
    ----------------------------------------------------------------------------------------------------

    o_tx_ready <= tx_ready_i;
    o_rx_ready <= rx_ready_i;
    o_tx_error <= tx_error_i;
    o_rx_error <= rx_error_i;
    o_data     <= rxdata_reg_i;

    ----------------------------------------------------------------------------------------------------
    --  Master Transmitter section  				      ----------------------------------------------
    ----------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    -- Data input latch process
    -- Latched only when slave enabled, Transmitter ready and wr is high.
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            data_in <= (OTHERS => '0');
        ELSIF rising_edge(i_sys_clk) THEN
            IF (i_wr = '1' AND i_csn = '0' AND tx_ready_i = '1') THEN
                data_in <= i_data;
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
            txdata_reg_i <= data_in;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- cpol=0 and cpha=0: data must be placed before rising edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (txdata_reg_i, tx_data_count_neg_sclk_i, i_lsb_first)
    BEGIN
        IF (i_lsb_first = '1') THEN
            mosi_00_i <= txdata_reg_i(conv_integer(tx_data_count_neg_sclk_i));
        ELSE
            mosi_00_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_neg_sclk_i - 1));
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------
    -- cpol=1 and cpha=0: data must be placed before falling edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (txdata_reg_i, tx_data_count_pos_sclk_i, i_lsb_first)
    BEGIN
        IF (i_lsb_first = '1') THEN
            mosi_10_i <= txdata_reg_i(conv_integer(tx_data_count_pos_sclk_i));
        ELSE
            mosi_10_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_pos_sclk_i - 1));
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- cpol=0 and cpha=1: data must be placed at rising edge of sclk  -------
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            mosi_01_i <= '1';
        ELSIF rising_edge(i_sclk) THEN
            IF (i_lsb_first = '1') THEN
                mosi_01_i <= txdata_reg_i(conv_integer(tx_data_count_pos_sclk_i));
            ELSE
                mosi_01_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_pos_sclk_i - 1));
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- cpol=1 and cpha=1: data must be placed at falling edge of sclk  -------
    ----------------------------------------------------------------------------

    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            mosi_11_i <= '1';
        ELSIF falling_edge(i_sclk) THEN
            IF (i_lsb_first = '1') THEN
                mosi_11_i <= txdata_reg_i(conv_integer(tx_data_count_neg_sclk_i));
            ELSE
                mosi_11_i <= txdata_reg_i(conv_integer(DATA_SIZE - tx_data_count_neg_sclk_i - 1));
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
            ELSIF i_ssn = "01" THEN
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
            ELSIF (i_ssn = "01") THEN
                tx_data_count_pos_sclk_i <= tx_data_count_pos_sclk_i + 1;
                tx_done_pos_sclk_i       <= '0';
            END IF;
        END IF;
    END PROCESS;

    PROCESS (i_ssn, i_cpol, i_cpha, mosi_00_i, mosi_01_i, mosi_10_i, mosi_11_i)
    BEGIN
        IF (i_ssn = "01") THEN
            IF (i_cpol = '0' AND i_cpha = '0') THEN
                io_LVDS <= mosi_00_i;
            ELSIF (i_cpol = '0' AND i_cpha = '1') THEN
                io_LVDS <= mosi_01_i;
            ELSIF (i_cpol = '1' AND i_cpha = '0') THEN
                io_LVDS <= mosi_10_i;
            ELSE
                io_LVDS <= mosi_11_i;
            END IF;
        ELSE
            io_LVDS <= 'Z'; --'0'; -- IDLE HIGH IMPEDANCE
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
            IF (i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1') THEN
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
    -- Transmitter ready goes low as soon as it gets a data byte/word
    ------------------------------------------------------------------------------------------------

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_ready_i <= '1';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (i_PHY_start = '1') THEN
                tx_ready_i <= '0';
            ELSIF (tx_done_reg2_i = '1' AND tx_done_reg3_i = '0') THEN
                tx_ready_i <= '1';
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------------------
    -- Transmitter error when a data is written while transmitter busy transmitting data
    -- (busy when Tx Ready = 0)
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            tx_error_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (tx_ready_i = '0' AND i_wr = '1' AND i_csn = '0') THEN
                tx_error_i <= '1';
            ELSIF (i_wr = '1' AND i_csn = '0') THEN
                tx_error_i <= '0';
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    --  Receiver Section  		------------------------------------------------
    ----------------------------------------------------------------------------
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
    ----------------------------------------------------------------------------
    --- MOSI Sampling : Sample at posedge of SCLK for 
    --                  1. i_cpol=0 and i_cpha=0 
    --                  2. i_cpol=1 and i_cpha=1 
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_shift_data_pos_sclk_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sclk) THEN
            IF (i_ssn = "10" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
                IF (i_lsb_first = '1') THEN
                    rx_shift_data_pos_sclk_i <= io_LVDS & rx_shift_data_pos_sclk_i(DATA_SIZE - 1 DOWNTO 1);
                ELSE
                    rx_shift_data_pos_sclk_i <= rx_shift_data_pos_sclk_i(DATA_SIZE - 2 DOWNTO 0) & io_LVDS;
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
            IF (i_ssn = "10" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
                IF (rx_data_count_pos_sclk_i = DATA_SIZE - 1) THEN
                    rx_data_count_pos_sclk_i <= (OTHERS => '0');
                    rx_done_pos_sclk_i       <= '1';
                ELSIF (i_ssn = "10") THEN
                    rx_data_count_pos_sclk_i <= rx_data_count_pos_sclk_i + 1;
                    rx_done_pos_sclk_i       <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    --- MOSI Sampling : Sample at negedge of SCLK for
    -- 1. i_cpol=1 and i_cpha=0
    -- 2. i_cpol=0 and i_cpha=1
    ----------------------------------------------------------------------------
    PROCESS (i_sclk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_shift_data_neg_sclk_i <= (OTHERS => '0');
        ELSIF falling_edge(i_sclk) THEN
            IF (i_ssn = "10" AND ((i_cpol = '1' AND i_cpha = '0') OR (i_cpol = '0' AND i_cpha = '1'))) THEN
                IF (i_lsb_first = '1') THEN
                    rx_shift_data_neg_sclk_i <= io_LVDS & rx_shift_data_neg_sclk_i(DATA_SIZE - 1 DOWNTO 1);
                ELSE
                    rx_shift_data_neg_sclk_i <= rx_shift_data_neg_sclk_i(DATA_SIZE - 2 DOWNTO 0) & io_LVDS;
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
            ELSIF (i_ssn = "10") THEN
                rx_data_count_neg_sclk_i <= rx_data_count_neg_sclk_i + 1;
                rx_done_neg_sclk_i       <= '0';
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- PHY Master Receiver Receive Done signal generator
    -- This is based on CPOL and CPHA
    ----------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF (i_sys_rst = '1') THEN
            rx_done_reg1_i <= '0';
            rx_done_reg2_i <= '0';
            rx_done_reg3_i <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF (i_ssn = "10" AND ((i_cpol = '0' AND i_cpha = '0') OR (i_cpol = '1' AND i_cpha = '1'))) THEN
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
            ELSIF (i_rd = '1' AND i_csn = '0') THEN
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
            IF (rx_done_reg2_i = '1' AND rx_done_reg3_i = '0' AND rx_ready_i = '1') THEN
                rx_error_i <= '1';
            ELSIF (i_rd = '1' AND i_csn = '0') THEN
                rx_error_i <= '0';
            END IF;
        END IF;
    END PROCESS;
END rtl_arch;
