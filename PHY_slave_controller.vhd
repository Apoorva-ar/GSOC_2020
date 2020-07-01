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

ENTITY PHY_slave_controller IS
    GENERIC (
        Data_Length : INTEGER   := 16;
        CPOL        : std_logic := '0';
        CPHA        : std_logic := '1'
    );
    PORT (
        -------------- System Interfaces ---------
        clk_sys         : IN std_logic;
        reset_top       : IN std_logic;
        data_in         : IN std_logic_vector(Data_Length - 1 DOWNTO 0);
        valid_in        : IN std_logic;
        data_out        : OUT std_logic_vector(Data_Length - 1 DOWNTO 0);
        valid_out       : OUT std_logic;
        write_ready     : OUT std_logic;
        write_tr_en     : IN std_logic;
        read_tr_en      : IN std_logic;
        state_test      : OUT std_logic_vector(2 DOWNTO 0);
        LVDS_IO_debug   : INOUT std_logic;
        sclk_debug      : IN std_logic;
        tx_ready_S_test : OUT std_logic
    );
END PHY_slave_controller;
ARCHITECTURE behavioral OF PHY_slave_controller IS

    COMPONENT PHY_slave IS
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
            i_sclk      : IN std_logic;                    -- Clock from SPI Master
            miso_tri_en : OUT std_logic;
            o_tx_ack    : OUT std_logic;
            o_tx_no_ack : OUT std_logic
        );
    END COMPONENT;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
    SIGNAL data_valid_received : std_logic                                  := '0';
    SIGNAL fifo_data_request   : std_logic                                  := '0';
    SIGNAL tx_ready_S          : STD_LOGIC                                  := '0';
    SIGNAL rx_ready_S          : STD_LOGIC                                  := '0';
    SIGNAL tx_error_S          : STD_LOGIC                                  := '0';
    SIGNAL interrupt           : STD_LOGIC                                  := '0';
    SIGNAL wait_count          : std_logic_vector(9 DOWNTO 0)               := (OTHERS => '0');
    SIGNAL PHY_transaction_en  : std_logic_vector(1 DOWNTO 0)               := (OTHERS => '0');
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
    SIGNAL DATA_Valid_SPI_M_I  : std_logic                                  := '0';
    TYPE state_S_2 IS(IDLE, Write_transaction_latch, Write_transaction_tx, Write_transaction_tx_wait, Read_transaction_latch, Read_transaction_rx);
    SIGNAL state_transaction : state_S_2                                  := IDLE;
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
    SIGNAL PHY_data_in       : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL write_valid_data  : std_logic := '0';
    SIGNAL read_valid_data   : std_logic := '0';
    SIGNAL M_data_out        : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL data_received     : std_logic_vector(Data_Length - 1 DOWNTO 0);
    SIGNAL PHY_data_out      : std_logic_vector(Data_Length - 1 DOWNTO 0);
BEGIN
    tx_ready_S_test <= rx_ready_S;
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    PHY_Slave_COMPONENT : PHY_slave
    GENERIC MAP(
        DATA_SIZE => Data_Length)
    PORT MAP(
        i_sys_clk   => clk_sys,     -- system high speed clock 
        i_sys_rst   => reset_top,   -- system reset
        i_csn       => chip_select, -- chip select for PHY Slave
        i_data      => PHY_data_in, -- input data
        i_ssn       => PHY_transaction_en,
        i_wr        => write_valid_data, -- Active High (my observation)
        i_rd        => read_valid_data,  -- Active High (my observation)
        o_tx_ready  => tx_ready_S,       -- Transmitter ready, can write another 
        o_rx_ready  => rx_ready_S,       -- receive ready
        o_data      => PHY_data_out,     -- receive data
        o_tx_error  => tx_error_S,       -- Transmitter error
        i_cpol      => CPOL,             -- CPOL value - 0 or 1
        i_cpha      => CPHA,             -- CPHA value - 0 or 1 
        i_lsb_first => '0',              -- lsb first when '1' /msb first when '0'
        LVDS_IO     => LVDS_IO_debug,    -- LVDS serial IO
        i_sclk      => sclk_debug        -- Master clock
    );

    -----------------------------------------------------------------------
    --------------------- SPI Master User FSM -----------------------------
    -----------------------------------------------------------------------
    PHY_Slave_USER_FSM : PROCESS (clk_sys, reset_top)
    BEGIN
        IF reset_top = '1' THEN
            state_transaction   <= IDLE;
            request_word        <= '0'; -- read enable to FIFO
            data_valid_received <= '0';
            write_valid_data    <= '0'; -- data valid flag to SMI_M
            chip_select         <= '1'; -- master chip select flag to PHY_M
            start_trans         <= '0'; -- start SPI transaction flag
            start_wait_counter  <= '0';
            valid_out           <= '0';
        ELSIF rising_edge(clk_sys) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    state_test <= "000";
                    -- write_ready <= '1';
                    IF write_tr_en = '1' THEN
                        state_transaction <= Write_transaction_latch;
                        write_ready       <= '0';
                    ELSIF read_tr_en = '1' THEN
                        state_transaction  <= Read_transaction_rx;
                        valid_out          <= '0';
                        PHY_transaction_en <= "01";
                        write_ready        <= '1';
                    ELSE
                        state_transaction <= IDLE;
                        write_ready       <= '1';
                    END IF;
                WHEN Write_transaction_latch =>
                    -- write_ready <= '0';
                    state_test <= "001";
                    IF valid_in = '1' THEN
                        PHY_transaction_en <= "10";
                        write_valid_data   <= '1';
                        PHY_data_in        <= data_in;
                        state_transaction  <= Write_transaction_tx;
                    END IF;

                WHEN Write_transaction_tx =>
                    state_test        <= "010";
                    write_valid_data  <= '0';
                    state_transaction <= Write_transaction_tx_wait;

                WHEN Write_transaction_tx_wait =>
                    state_test <= "011";
                    IF tx_ready_S = '1' THEN
                        PHY_transaction_en <= "11";
                        state_transaction  <= IDLE;
                        write_ready       <= '1';
                    END IF;

                WHEN Read_transaction_rx =>
                    state_test <= "100";
                    -- PHY_transaction_en <= "01";
                    state_transaction <= Read_transaction_latch;

                WHEN Read_transaction_latch =>
                    state_test      <= "101";
                    read_valid_data <= '1';
                    IF rx_ready_S = '1' THEN
                        -- PHY_transaction_en <= "11";
                        data_out           <= PHY_data_out;
                        valid_out          <= '1';
                        state_transaction  <= IDLE;
                    END IF;
                -- WHEN Wait_end_rx_transaction =>
                --     state_test <= "110";
                --     IF read_tr_en = '0' THEN
                --         state_transaction <= IDLE;
                --     END IF;
            END CASE;
        END IF;
    END PROCESS;
END behavioral;
