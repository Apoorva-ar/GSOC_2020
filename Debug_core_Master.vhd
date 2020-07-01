-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY Debug_SPI_Master IS
    GENERIC (
        WORD_SIZE         : INTEGER                      := 48;
        Data_Length       : INTEGER                      := 16;
        SETUP_WORD_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0010010000"; -- 144 cycles (48MHz) for 3us
        INTER_WORD_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1001110000"; -- 624 cycles for 13us
        INTER_DATA_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0001100000"; -- 96 cycles (48 MHz) for 2us
        CPOL              : std_logic                    := '0';
        CPHA              : std_logic                    := '1';
        CLK_PERIOD        : std_logic_vector(7 DOWNTO 0) := "00011110"; -- 30 cycles for 1.6MHz sclk from 48 Mhz system clock
        SETUP_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000110"; -- 6 cycles
        HOLD_CYCLES       : std_logic_vector(7 DOWNTO 0) := "00000110"; -- 6 cycles
        TX2TX_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000010"
    );
    PORT (
        -------------- System Interfaces ---------
        clk_sys, reset_top : IN STD_LOGIC;
        ------------- SPI Interfaces -------------
        MOSI_debug : OUT std_logic;
        MISO_debug : IN std_logic;
        sclk_debug : OUT std_logic;
        CS_debug   : OUT std_logic;
        ------------- User interface ----------
        data_in_user        : IN std_logic_vector(16 - 1 DOWNTO 0);
        data_in_user_valid  : IN std_logic;
        SPI_tx_ready        : OUT std_logic;
        data_out_user       : OUT std_logic_vector(16 - 1 DOWNTO 0);
        data_out_user_valid : OUT std_logic;
        ------------- Test Intefaces --------------
        test_1 : OUT std_logic;
        test_2 : OUT std_logic_vector(3 DOWNTO 0);
        test_3 : OUT std_logic;
        test_4 : OUT std_logic_vector(15 DOWNTO 0)
    );
END Debug_SPI_Master;

ARCHITECTURE behavioral OF Debug_SPI_Master IS
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT spi_master IS
        GENERIC (
            DATA_SIZE : INTEGER := 32;
            FIFO_REQ  : BOOLEAN := True);
        PORT (
            i_sys_clk      : IN std_logic;                                 -- system clock
            i_sys_rst      : IN std_logic;                                 -- system reset
            i_csn          : IN std_logic;                                 -- chip select for SPI master
            i_data         : IN std_logic_vector(16 - 1 DOWNTO 0);  -- Input data
            i_wr           : IN std_logic;                                 -- Active High (my observation)
            i_rd           : IN std_logic;                                 -- Active High (my observation)
            o_data         : OUT std_logic_vector(16  - 1 DOWNTO 0); -- output data
            o_tx_ready     : OUT std_logic;                                -- Transmitter ready, can write another 
            o_rx_ready     : OUT std_logic;                                -- Receiver ready, can read data
            o_tx_error     : OUT std_logic;                                -- Transmitter error
            o_rx_error     : OUT std_logic;                                -- Receiver error
            o_intr         : OUT std_logic;                                -- interrupt
            i_slave_addr   : IN std_logic_vector(1 DOWNTO 0);              -- Slave Address
            i_cpol         : IN std_logic;                                 -- CPOL value - 0 or 1
            i_cpha         : IN std_logic;                                 -- CPHA value - 0 or 1 
            i_lsb_first    : IN std_logic;                                 -- lsb first when '1' /msb first when 
            i_spi_start    : IN std_logic;                                 -- START SPI Master Transactions
            i_clk_period   : IN std_logic_vector(7 DOWNTO 0);              -- SCL clock period in terms of i_sys_clk
            i_setup_cycles : IN std_logic_vector(7 DOWNTO 0);              -- SPIM setup time  in terms of i_sys_clk
            i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0);              -- SPIM hold time  in terms of i_sys_clk
            i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0);              -- SPIM interval between data transactions in terms of i_sys_clk
            o_slave_csn    : OUT std_logic_vector(3 DOWNTO 0);             -- SPI Slave select (chip select) active low
            o_mosi         : OUT std_logic;                                -- Master output to Slave
            i_miso         : IN std_logic;                                 -- Master input from Slave
            o_sclk         : OUT std_logic;                                -- Master clock
            mosi_tri_en    : OUT std_logic
        );
    END COMPONENT;

    COMPONENT FIFOx64
        PORT (
            Data        : IN std_logic_vector(15 DOWNTO 0);
            WrClock     : IN std_logic;
            RdClock     : IN std_logic;
            WrEn        : IN std_logic;
            RdEn        : IN std_logic;
            Reset       : IN std_logic;
            RPReset     : IN std_logic;
            Q           : OUT std_logic_vector(15 DOWNTO 0);
            Empty       : OUT std_logic;
            Full        : OUT std_logic;
            AlmostEmpty : OUT std_logic;
            AlmostFull  : OUT std_logic
        );
    END COMPONENT;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
    SIGNAL fifo_data_request  : std_logic                                  := '0';
    SIGNAL tx_ready_M         : STD_LOGIC                                  := '0';
    SIGNAL tx_error_M         : STD_LOGIC                                  := '0';
    SIGNAL interrupt          : STD_LOGIC                                  := '0';
    SIGNAL wait_count         : std_logic_vector(9 DOWNTO 0)               := (OTHERS => '0');
    SIGNAL intr_data_wait     : std_logic                                  := '0';
    SIGNAL intr_word_wait     : std_logic                                  := '0';
    SIGNAL setup_word_wait    : std_logic                                  := '0';
    SIGNAL request_word       : std_logic                                  := '0';
    SIGNAL valid_data         : std_logic                                  := '0';
    SIGNAL master_cs          : std_logic                                  := '0';
    SIGNAL data_valid         : std_logic                                  := '0';
    SIGNAL chip_select        : std_logic                                  := '0';
    SIGNAL start_trans        : std_logic                                  := '0';
    SIGNAL start_wait_counter : std_logic                                  := '0';
    SIGNAL slave_CS           : std_logic_vector(3 DOWNTO 0)               := (OTHERS => '0');
    SIGNAL word_reg           : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DATA_Valid_SPI_M_I : std_logic                                  := '0';
    TYPE state_S IS(IDLE, LATCH_WORD, LATCH_D1, TRANSMIT_D1, wait_transmission_D1, LATCH_D2, TRANSMIT_D2, wait_transmission_D2, LATCH_D3, TRANSMIT_D3, wait_transmission_D3, END_TRANSACTION, WAIT_INTR_D1D2, WAIT_INTR_D2D3, SETUP_WORD);
    SIGNAL state_transaction : state_S := IDLE;
    TYPE state_S_2 IS(IDLE, counter_state, WAIT_empty_state);
    SIGNAL state_FIFO        : state_S_2                                  := counter_state;
    SIGNAL CSN_SPI_M         : std_logic                                  := '0';
    SIGNAL Start_SPI_M       : std_logic                                  := '0';
    SIGNAL Data_SPI_M_I      : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SPI_data_in       : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_out_fifo     : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL FIFO_data_out     : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SPI_M_CS          : std_logic                                  := '1'; -- SPI slave chip select
    SIGNAL data_in_fifo      : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL FIFO_empty_signal : std_logic                                  := '0';
    SIGNAL FIFO_almost_empty : std_logic                                  := '0';
    SIGNAL FIFO_almost_full  : std_logic                                  := '0';
    SIGNAL full_fifo         : std_logic                                  := '0';
    SIGNAL valid_fifo_in     : std_logic                                  := '0';
    SIGNAL temp              : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL valid_temp        : std_logic := '0';
BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    USER_FIFO_block : FIFOx64
    PORT MAP(
        Data        => data_in_fifo,
        WrClock     => clk_sys,
        RdClock     => clk_sys,
        WrEn        => valid_fifo_in,
        RdEn        => fifo_data_request,
        Reset       => reset_top,
        RPReset     => reset_top,
        Q           => data_out_fifo,
        Empty       => FIFO_empty_signal,
        AlmostEmpty => FIFO_almost_empty,
        AlmostFull  => FIFO_almost_full,
        Full        => full_fifo
    );

    data_in_fifo  <= data_in_user;
    valid_fifo_in <= data_in_user_valid;

    fifo_data_request <= request_word;
    FIFO_data_out     <= data_out_fifo;

    ---------------------------------------------------------------------------
    ------------------------------  SPI Master --------------------------------
    ---------------------------------------------------------------------------
    SPI_Master_COMPONENT : spi_master
    GENERIC MAP(
        DATA_SIZE => Data_Length,
        FIFO_REQ  => False)
    PORT MAP(
        i_sys_clk      => clk_sys,            -- system high speed clock 
        i_sys_rst      => reset_top,          -- system reset
        i_csn          => CSN_SPI_M,          -- chip select for SPI master
        i_data         => Data_SPI_M_I,       -- input data
        i_wr           => DATA_Valid_SPI_M_I, -- Active High (my observation)
        i_rd           => '0',                -- Active High (my observation)
        o_tx_ready     => tx_ready_M,         -- Transmitter ready, can write another 
        o_tx_error     => tx_error_M,         -- Transmitter error
        o_intr         => interrupt,          -- interrupt
        i_slave_addr   => "00",               -- Slave Address
        i_cpol         => CPOL,               -- CPOL value - 0 or 1
        i_cpha         => CPHA,               -- CPHA value - 0 or 1 
        i_lsb_first    => '0',                -- lsb first when '1' /msb first when '0'
        i_spi_start    => Start_SPI_M,        -- START SPI Master Transactions
        i_clk_period   => CLK_PERIOD,         -- SCL clock period in terms of i_sys_clk
        i_setup_cycles => SETUP_CYCLES,       -- SPIM setup time  in terms of i_sys_clk
        i_hold_cycles  => HOLD_CYCLES,        -- SPIM hold time  in terms of i_sys_clk
        i_tx2tx_cycles => TX2TX_CYCLES,       -- SPIM interval between data transactions in terms of i_sys_clk
        o_slave_csn    => slave_CS,           -- SPI Slave select (chip select) active low
        o_mosi         => MOSI_debug,         -- Master output to Slave
        i_miso         => MISO_debug,         -- Master input from Slave
        o_sclk         => sclk_debug          -- Master clock
    );
    DATA_Valid_SPI_M_I <= data_valid;
    CSN_SPI_M          <= chip_select;
    Start_SPI_M        <= start_trans;
    Data_SPI_M_I       <= SPI_data_in;
    -----------------------------------------------------------------------
    --------------------- SPI Master User FSM -----------------------------
    -----------------------------------------------------------------------
    SPI_MASTER_USER_FSM : PROCESS (clk_sys, reset_top)
        VARIABLE i : INTEGER RANGE 1 TO 3 := 3;
    BEGIN
        IF reset_top = '1' THEN
            state_transaction  <= IDLE;
            SPI_M_CS           <= '1'; -- raise the spi chip select line to HIGH
            request_word       <= '0'; -- read enable to FIFO
            data_valid         <= '0'; -- data valid flag to SMI_M
            chip_select        <= '1'; -- master chip select flag to SPI_M
            start_trans        <= '0'; -- start SPI transaction flag
            start_wait_counter <= '0';
        ELSIF rising_edge(clk_sys) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    start_wait_counter <= '0';
                    SPI_M_CS           <= '1';      -- raise the spi chip select line to HIGH
                    request_word       <= '0';      -- read enable to FIFO
                    data_valid         <= '0';      -- data valid flag to SMI_M
                    chip_select        <= '1';      -- master chip select flag to SPI_M
                    start_trans        <= '0';      -- start SPI transaction flag
                    IF FIFO_empty_signal = '0' THEN -- if valid data is available in FIFO
                        state_transaction <= LATCH_WORD;
                    END IF;

                WHEN LATCH_WORD =>
                    request_word       <= '1';        -- demand new word from FIFO
                    start_wait_counter <= '1';        -- start counter for delay before sending first data element
                    state_transaction  <= SETUP_WORD; -- start_transaction;
                    SPI_M_CS           <= '0';        -- start the SPI word transaction, lower the SPI chip select line

                WHEN SETUP_WORD =>
                    request_word <= '0';           -- disable the read enable to FIFO
                    word_reg     <= FIFO_data_out; -- latch/register the word from FIFO
                    IF setup_word_wait = '1' THEN  -- if the wait is equal to the required setup word cycles then change state to latch first element of the word
                        state_transaction  <= LATCH_D1;
                        start_wait_counter <= '0'; -- stop/reset the wait counter
                    END IF;

                WHEN LATCH_D1 =>
                    data_valid        <= '1';      -- raise the data_valid flag to SPI_M
                    chip_select       <= '0';      -- lower the master chip select to latch_in a new element
                    SPI_data_in       <= word_reg; -- latch_in new element into input_data register of SPI_M
                    state_transaction <= TRANSMIT_D1;

                WHEN TRANSMIT_D1 =>
                    data_valid        <= '0';
                    chip_select       <= '1';
                    start_trans       <= '1'; -- start SPI master transaction
                    state_transaction <= wait_transmission_D1;

                WHEN wait_transmission_D1 =>
                    start_trans       <= '0'; -- reset SPI master transaction
                    state_transaction <= WAIT_INTR_D1D2;

                WHEN END_TRANSACTION =>
                    IF tx_ready_M = '1' THEN
                        start_wait_counter <= '1'; -- start counter to wait for the inter element wait
                    END IF;
                    IF setup_word_wait = '1' THEN -- if the wait is equal 3us
                        SPI_M_CS <= '1';              -- raise the spi chip select line to HIGH
                    END IF;
                    IF intr_word_wait = '1' THEN -- if the wait is equal to 13 us
                        state_transaction  <= IDLE;
                        start_wait_counter <= '0';
                    END IF;
                WHEN OTHERS =>
                    state_transaction <= IDLE;
            END CASE;
        END IF;
    END PROCESS;
    ------------------------------------------------------------------------------------------------
    ------- Wait Counter used for controlling wait stages between SPI transactions -----------------
    ------------------ wait counter enabled only when delay_count_start_i = '1' --------------------
    ------------------------------------------------------------------------------------------------
    PROCESS (clk_sys, reset_top)
    BEGIN
        IF reset_top = '1' THEN
            wait_count <= "0000000001";
        ELSIF rising_edge(clk_sys) THEN
            IF start_wait_counter = '0' THEN
                wait_count <= "0000000001";
            ELSE
                wait_count <= wait_count + 1;
            END IF;
        END IF;
    END PROCESS;

    intr_data_wait <= '1' WHEN wait_count = INTER_DATA_CYCLES ELSE
        '0';
    intr_word_wait <= '1' WHEN wait_count = INTER_WORD_CYCLES ELSE
        '0';
    setup_word_wait <= '1' WHEN wait_count = SETUP_WORD_CYCLES ELSE
        '0';
    -------------------------------------------------------------------------------------------
    --------------------------- Combinitorial signals -----------------------------------------
    -------------------------------------------------------------------------------------------
    CS_debug <= SPI_M_CS;
    test_1   <= tx_ready_M;
    test_3   <= intr_data_wait;
    test_4   <= SPI_data_in;
END behavioral;
