-- Copyright (C) 2020 Apoorva Arora
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

ENTITY PHY_Controller IS
    GENERIC (
        WORD_SIZE         : INTEGER                      := 48;
        Data_Length       : INTEGER                      := 16;
        SETUP_WORD_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0010010000"; -- 144 cycles 
        INTER_WORD_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "1001110000"; -- 624 cycles 
        INTER_DATA_CYCLES : STD_LOGIC_VECTOR(9 DOWNTO 0) := "0001100000"; -- 96 cycles 
        CPOL              : std_logic                    := '0';
        CPHA              : std_logic                    := '1';
        CLK_PERIOD        : std_logic_vector(7 DOWNTO 0) := "00011110"; -- 30 cycles 
        SETUP_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000110"; -- 6 cycles
        HOLD_CYCLES       : std_logic_vector(7 DOWNTO 0) := "00000110"; -- 6 cycles
        TX2TX_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000010"
    );
    PORT (
        -------------- System Interfaces ---------
        clk_sys, clk_sample, reset_top : IN STD_LOGIC;
        ------------- PHY Interfaces -------------
        LVDS_IO_debug : INOUT std_logic;
        sclk_debug    : OUT std_logic;
        ------------- DATA IO channel ------------
        data_in      : IN std_logic_vector(Data_Length - 1 DOWNTO 0);
        valid_in     : IN std_logic;
        write_enable : IN std_logic;
        write_ready  : OUT std_logic;
        data_out     : OUT std_logic_vector(Data_Length - 1 DOWNTO 0);
        valid_out    : OUT std_logic;
        read_enable  : IN std_logic;
        --read_ready   : OUT std_logic;
        ------------- Test Intefaces --------------
        test_1 : OUT std_logic;
        test_2 : OUT std_logic_vector(3 DOWNTO 0); -- used to know state information
        test_3 : OUT std_logic;
        test_4 : OUT std_logic_vector(15 DOWNTO 0)
    );
END PHY_Controller;

ARCHITECTURE behavioral OF PHY_Controller IS
    
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT PHY_Master IS
        GENERIC (
            DATA_SIZE : INTEGER := 32;
            FIFO_REQ  : BOOLEAN := True);
        PORT (
            i_sys_clk : IN std_logic; -- system clock
            i_sys_rst : IN std_logic; -- system reset

            i_data     : IN std_logic_vector(Data_Length - 1 DOWNTO 0);  -- Input data
            o_data     : OUT std_logic_vector(Data_Length - 1 DOWNTO 0); --output data
            i_wr_tr_en : IN std_logic;                                   -- write transaction enable
            i_rd_tr_en : IN std_logic;                                   -- read transaction enable
            i_csn      : IN std_logic;                                   -- chip select for PHY master transaction Data IO
            i_wr       : IN std_logic;                                   -- Active Low Write, Active High Read
            i_rd       : IN std_logic;                                   -- Active Low Write, Active High Read

            o_tx_ready : OUT std_logic; -- Transmitter ready, can write another data
            o_rx_ready : OUT std_logic; -- Receiver ready, can read data

            o_tx_error : OUT std_logic; -- Transmitter error
            o_rx_error : OUT std_logic; -- Receiver error
            o_intr     : OUT std_logic;

            i_cpol         : IN std_logic;                    -- CPOL value - 0 or 1
            i_cpha         : IN std_logic;                    -- CPHA value - 0 or 1 
            i_lsb_first    : IN std_logic;                    -- lsb first when '1' /msb first when 
            i_PHY_start    : IN std_logic;                    -- START PHY Master Transactions
            i_clk_period   : IN std_logic_vector(7 DOWNTO 0); -- SCL clock period in terms of i_sys_clk
            i_setup_cycles : IN std_logic_vector(7 DOWNTO 0); --  setup time  in terms of i_sys_clk
            i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0); --  hold time  in terms of i_sys_clk
            i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0); --  interval between data transactions in terms of i_sys_clk

            PHY_M_IO    : INOUT std_logic; -- LVDS bidirectional data link
            o_sclk      : OUT std_logic;   -- Master clock
            mosi_tri_en : OUT std_logic
        );
    END COMPONENT;

    COMPONENT FIFOx64
        PORT (
            Data        : IN std_logic_vector(Data_Length - 1 DOWNTO 0);
            WrClock     : IN std_logic;
            RdClock     : IN std_logic;
            WrEn        : IN std_logic;
            RdEn        : IN std_logic;
            Reset       : IN std_logic;
            RPReset     : IN std_logic;
            Q           : OUT std_logic_vector(Data_Length - 1 DOWNTO 0);
            Empty       : OUT std_logic;
            Full        : OUT std_logic;
            AlmostEmpty : OUT std_logic;
            AlmostFull  : OUT std_logic
        );
    END COMPONENT;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
        
    SIGNAL data_valid_received : std_logic                                  := '0';
    SIGNAL fifo_data_request   : std_logic                                  := '0';
    SIGNAL tx_ready_M          : STD_LOGIC                                  := '0';
    SIGNAL rx_ready_M          : STD_LOGIC                                  := '0';
    SIGNAL tx_error_M          : STD_LOGIC                                  := '0';
    SIGNAL interrupt           : STD_LOGIC                                  := '0';
    SIGNAL wait_count          : std_logic_vector(9 DOWNTO 0)               := (OTHERS => '0');
    SIGNAL intr_data_wait      : std_logic                                  := '0';
    SIGNAL intr_word_wait      : std_logic                                  := '0';
    SIGNAL setup_word_wait     : std_logic                                  := '0';
    SIGNAL request_word        : std_logic                                  := '0';
    SIGNAL valid_data          : std_logic                                  := '0';
    SIGNAL master_cs           : std_logic                                  := '0';
    SIGNAL data_valid          : std_logic                                  := '0';
    SIGNAL chip_select         : std_logic                                  := '0';
    SIGNAL start_trans         : std_logic                                  := '0';
    SIGNAL start_wait_counter  : std_logic                                  := '0';
    SIGNAL slave_CS            : std_logic_vector(3 DOWNTO 0)               := (OTHERS => '0');
    SIGNAL word_reg            : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    TYPE state_S IS(IDLE, wait_end_transaction, rx_end_state, TX_WAIT, LATCH_WORD,
                    LATCH_D1, TRANSMIT_D1, wait_transmission_D1, END_TRANSACTION,
                    SETUP_WORD, RX_transaction, WAIT_RX_D1, RX_latch_state);
    SIGNAL state_transaction : state_S := IDLE;
    TYPE state_S_2 IS(IDLE, counter_state, WAIT_empty_state);
    SIGNAL state_FIFO           : state_S_2                                  := counter_state;
    SIGNAL CSN_SPI_M            : std_logic                                  := '0';
    SIGNAL data_out_fifo        : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL FIFO_data_out        : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SPI_M_CS             : std_logic                                  := '1'; -- SPI slave chip select
    SIGNAL data_in_fifo         : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL FIFO_empty_signal    : std_logic                                  := '0';
    SIGNAL FIFO_almost_empty    : std_logic                                  := '0';
    SIGNAL FIFO_almost_full     : std_logic                                  := '0';
    SIGNAL full_fifo            : std_logic                                  := '0';
    SIGNAL valid_fifo_in        : std_logic                                  := '0';
    SIGNAL temp                 : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL valid_temp           : std_logic := '0';
    SIGNAL PHY_data_in          : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL write_valid_data     : std_logic := '0';
    SIGNAL read_valid_data      : std_logic := '0';
    SIGNAL M_data_out           : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL data_received        : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL write_enable_signal  : std_logic := '0';
    SIGNAL read_enable_signal   : std_logic := '0';
    SIGNAL end_transaction_wait : std_logic := '0';
BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    test_1 <= tx_ready_M;
    test_4 <= data_out_fifo;

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------

    PHY_Master_COMPONENT : PHY_Master
    GENERIC MAP(
        DATA_SIZE => Data_Length,
        FIFO_REQ  => False)
    PORT MAP(
        i_sys_clk      => clk_sys,             -- system high speed clock 
        i_sys_rst      => reset_top,           -- system reset
        i_csn          => chip_select,         -- chip select for PHY master
        i_data         => PHY_data_in,         -- input data
        i_wr_tr_en     => write_enable_signal, -- write transaction enable
        i_rd_tr_en     => read_enable_signal,  -- read transaction enable
        i_wr           => write_valid_data,    -- Active High (my observation)
        i_rd           => read_valid_data,     -- Active High (my observation)
        o_tx_ready     => tx_ready_M,          -- Transmitter ready, can write another 
        o_rx_ready     => rx_ready_M,          -- receive ready
        o_data         => M_data_out,          -- receive data
        o_tx_error     => tx_error_M,          -- Transmitter error
        o_intr         => interrupt,           -- interrupt
        i_cpol         => CPOL,                -- CPOL value - 0 or 1
        i_cpha         => CPHA,                -- CPHA value - 0 or 1 
        i_lsb_first    => '0',                 -- lsb first when '1' /msb first when '0'
        i_PHY_start    => start_trans,         -- START PHY Master Transactions
        i_clk_period   => CLK_PERIOD,          -- SCL clock period in terms of i_sys_clk
        i_setup_cycles => SETUP_CYCLES,        -- PHY_M tx setup time  in terms of i_sys_clk
        i_hold_cycles  => HOLD_CYCLES,         -- PHY_M tx hold time  in terms of i_sys_clk
        i_tx2tx_cycles => TX2TX_CYCLES,        -- PHY_M tx interval between data transactions in terms of i_sys_clk
        PHY_M_IO       => LVDS_IO_debug,       -- LVDS serial IO
        o_sclk         => sclk_debug           -- Master clock
    );

    data_out  <= data_received;
    valid_out <= data_valid_received;

    -----------------------------------------------------------------------
    ---------------------   Master User FSM -----------------------------
    -----------------------------------------------------------------------

    PHY_MASTER_USER_FSM : PROCESS (clk_sys, reset_top)
    BEGIN
        IF reset_top = '1' THEN
            test_2              <= "0000";
            state_transaction   <= IDLE;
            request_word        <= '0'; -- read enable to FIFO
            data_valid_received <= '0';
            write_valid_data    <= '0'; -- data valid flag to SMI_M
            chip_select         <= '1'; -- master chip select flag to PHY_M
            start_trans         <= '0'; -- start  transaction flag
            start_wait_counter  <= '0';
            write_enable_signal <= '0';
            read_enable_signal  <= '0';
        ELSIF rising_edge(clk_sys) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    test_2      <= "0000";
                    write_ready <= '1'; -- ready to accept new data from user
                    -- read_ready          <= '1'; -- read to write new data to user
                    start_wait_counter  <= '0';
                    request_word        <= '0'; -- read enable to FIFO
                    write_valid_data    <= '0'; -- data valid flag to PHY_M
                    chip_select         <= '1'; -- master chip select flag to PHY_M
                    start_trans         <= '0'; -- start  transaction flag
                    write_enable_signal <= '0';
                    read_enable_signal  <= '0';
                    IF write_enable = '1' THEN
                        IF valid_in = '1' THEN    -- if valid inpuit data is available
                            write_ready       <= '0'; -- lower the tx ready flag
                            state_transaction <= LATCH_WORD;
                            word_reg          <= data_in; -- latch in the data
                        END IF;
                        -- state_transaction <= TX_WAIT;
                    ELSIF read_enable = '1' THEN
                        data_valid_received <= '0'; -- valid received data
                        state_transaction   <= RX_transaction;
                    ELSE
                        state_transaction <= IDLE;
                    END IF;
                    ------------------------ Transmitter ------------------------------------
                WHEN TX_WAIT =>
                    test_2 <= "0001";
                WHEN LATCH_WORD =>
                    test_2             <= "0010";
                    request_word       <= '1';        -- demand new word from FIFO
                    start_wait_counter <= '1';        -- start counter for delay before sending first data element
                    state_transaction  <= SETUP_WORD; -- start_transaction;

                WHEN SETUP_WORD =>
                    test_2       <= "0011";
                    request_word <= '0'; -- disable the read enable to FIFO
                    -- word_reg     <= FIFO_data_out(Data_Length - 1 DOWNTO 0); -- latch/register the word from FIFO
                    IF setup_word_wait = '1' THEN -- latch first element of the word
                        state_transaction  <= LATCH_D1;
                        start_wait_counter <= '0'; -- stop/reset the wait counter
                    END IF;

                WHEN LATCH_D1 =>
                    test_2            <= "0100";
                    write_valid_data  <= '1';      -- raise the data_valid flag to 
                    chip_select       <= '0';      -- lower the master chip select to latch_in a new element
                    PHY_data_in       <= word_reg; -- latch_in new element into input_data register of 
                    state_transaction <= TRANSMIT_D1;

                WHEN TRANSMIT_D1 =>
                    test_2              <= "0101";
                    write_valid_data    <= '0';
                    chip_select         <= '1';
                    write_enable_signal <= '1';
                    start_trans         <= '1'; -- start  master transaction
                    state_transaction   <= wait_transmission_D1;

                WHEN wait_transmission_D1 =>
                    test_2              <= "0110";
                    write_enable_signal <= '0';
                    start_trans         <= '0'; -- reset  master transaction
                    state_transaction   <= END_TRANSACTION;

                WHEN END_TRANSACTION =>
                    test_2 <= "0111";
                    IF tx_ready_M = '1' THEN
                        state_transaction  <= wait_end_transaction; --IDLE;
                        start_wait_counter <= '1';                  -- start counter for delay 
                    END IF;
                WHEN wait_end_transaction =>
                    test_2 <= "1111";
                    IF end_transaction_wait = '1' THEN
                        state_transaction  <= IDLE;
                        start_wait_counter <= '0'; -- stop/reset the wait counter
                    END IF;
                    ------------------------ Receiver ------------------------------------
                WHEN RX_transaction =>
                    test_2 <= "1000";
                    -- read_ready        <= '0';
                    start_trans        <= '1';-- start master transaction
                    read_enable_signal <= '1';
                    state_transaction  <= WAIT_RX_D1;

                WHEN WAIT_RX_D1 =>
                    test_2             <= "1001";
                    start_trans        <= '0'; -- reset master transaction
                    read_enable_signal <= '0';
                    IF rx_ready_M = '1' THEN
                        state_transaction  <= RX_latch_state;
                        chip_select        <= '0';
                        read_valid_data    <= '1'; -- to read valid data from PHY_Master
                        start_wait_counter <= '1'; -- start counter for delay before sending first data element
                    END IF;

                WHEN RX_latch_state =>
                    test_2          <= "1010";
                    chip_select     <= '1';
                    read_valid_data <= '0';
                    data_received   <= M_data_out; -- latch out valid data
                    IF end_transaction_wait = '1' THEN
                        state_transaction   <= rx_end_state;
                        start_wait_counter  <= '0'; -- stop/reset the wait counter
                        data_valid_received <= '1'; -- valid data signal for user
                    END IF;
                WHEN rx_end_state =>
                    state_transaction <= IDLE;
                    data_valid_received <= '0';
            END CASE;
        END IF;
    END PROCESS;
            
    ------------------------------------------------------------------------------------------------
    ------ Wait Counter used for controlling wait stages between LVDS transactions -----------------
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
    setup_word_wait <= '1' WHEN wait_count = "0000000010" ELSE
        '0';
    end_transaction_wait <= '1' WHEN wait_count = CLK_PERIOD ELSE
        '0';
END behavioral;
