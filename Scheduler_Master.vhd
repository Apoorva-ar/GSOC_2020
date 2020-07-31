-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
-- Command tells burst length and write/read transaction, address ans type of data packet (task priority)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY Packet_layer_Master_scheduler IS
    GENERIC (
        DATA_LEN    : INTEGER := 16;
        ADDRESS_LEN : INTEGER := 5;
        COMMAND_LEN : INTEGER := 16
    );
    PORT (
        -------------- System Interfaces ---------
        clk_top, reset : IN STD_LOGIC;
        -------------- Control channels ---------
        command_in       : IN std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
        command_valid_in : IN std_logic;
        ------------- DATA IO channel ------------
        LVDS_IO    : INOUT std_logic;
        LVDS_clock : OUT std_logic;
        ------- Address channel
        -- address_in        : IN std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_in  : IN std_logic;
        -- address_out       : OUT std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_out : OUT std_logic;
        ------- Data channel
        data_in        : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_in  : IN std_logic;
        data_in_ready  : OUT std_logic;
        data_out       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_out : OUT std_logic;
        ------------- Test Intefaces --------------
        test_1 : OUT std_logic;
        test_2 : OUT std_logic_vector(3 DOWNTO 0);
        test_3 : OUT std_logic;
        test_4 : OUT std_logic_vector(15 DOWNTO 0)
    );
END Packet_layer_Master_scheduler;

ARCHITECTURE behavioral OF Packet_layer_Master_scheduler IS

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT packet_layer_Master IS
        GENERIC (
            DATA_LEN    : INTEGER := 16;
            ADDRESS_LEN : INTEGER := 5;
            COMMAND_LEN : INTEGER := 16
        );
        PORT (
            -------------- System Interfaces ---------
            clk_top, reset : IN STD_LOGIC;
            -------------- Control channels ---------
            command_in       : IN std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
            command_valid_in : IN std_logic;
            ------------- DATA IO channel ------------
            LVDS_IO    : INOUT std_logic;
            LVDS_clock : OUT std_logic;
            ------- Data channel
            data_in        : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
            data_valid_in  : IN std_logic;
            data_in_ready  : OUT std_logic;
            data_out       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
            data_valid_out : OUT std_logic;
            ------------- Test Intefaces --------------
            test_1        : OUT std_logic;
            test_2        : OUT std_logic_vector(3 DOWNTO 0);
            test_3        : OUT std_logic;
            test_4        : OUT std_logic_vector(15 DOWNTO 0);
            b_length_test : OUT std_logic_vector(6 DOWNTO 0);
            tr_type_test  : OUT std_logic
        );
    END COMPONENT;

    COMPONENT command_fifo_1
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    COMPONENT command_fifo_2
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    COMPONENT command_fifo_3
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    COMPONENT fifo_1
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    COMPONENT fifo_2
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    COMPONENT fifo_3
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
            AlmostFull  : OUT std_logic);
    END COMPONENT;
    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------

    TYPE state_S IS(IDLE, parse_command_priority, parse_command_state, tx_state, latch_tx_data, rx_state);
    SIGNAL state_transaction    : state_S := IDLE;
    SIGNAL transaction_type     : std_logic; -- write/read transaction
    SIGNAL burst_length         : std_logic_vector(6 DOWNTO 0);
    SIGNAL data_type            : std_logic_vector(1 DOWNTO 0);
    SIGNAL burst_length_in      : std_logic_vector(6 DOWNTO 0);
    SIGNAL data_type_in         : std_logic_vector(1 DOWNTO 0);
    SIGNAL data_valid_in_PHY    : std_logic;
    SIGNAL data_in_PHY          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_valid_out_PHY   : std_logic;
    SIGNAL data_out_PHY         : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_tr_en_PHY         : std_logic;
    SIGNAL rd_tr_en_PHY         : std_logic;
    SIGNAL PHY_tx_ready         : std_logic;
    SIGNAL data_fifo_1          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_1         : std_logic;
    SIGNAL rd_en_fifo_1         : std_logic;
    SIGNAL data_in_fifo_1       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_1         : std_logic;
    SIGNAL data_fifo_2          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_2         : std_logic;
    SIGNAL rd_en_fifo_2         : std_logic;
    SIGNAL data_in_fifo_2       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_2         : std_logic;
    SIGNAL data_fifo_3          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_3         : std_logic;
    SIGNAL rd_en_fifo_3         : std_logic;
    SIGNAL data_in_fifo_3       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_3         : std_logic;
    SIGNAL rd_en_command_1      : std_logic;
    SIGNAL command_read         : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_read_1       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_empty_1 : std_logic;
    SIGNAL rd_en_command_2      : std_logic;
    SIGNAL command_read_2       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_in_pak       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_in_pak_valid : std_logic;
    SIGNAL command_fifo_empty_2 : std_logic;
    SIGNAL rd_en_command_3      : std_logic;
    SIGNAL command_read_3       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_empty_3 : std_logic;
    SIGNAL read_data_latch_3    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_3 : std_logic;
    SIGNAL read_data_out_3      : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_3   : std_logic;
    SIGNAL read_fifo_3_empty    : std_logic;
    SIGNAL read_data_latch_1    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_1 : std_logic;
    SIGNAL read_data_out_1      : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_1   : std_logic;
    SIGNAL read_fifo_1_empty    : std_logic;
    SIGNAL read_data_latch_2    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_2 : std_logic;
    SIGNAL read_data_out_2      : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_2   : std_logic;
    SIGNAL read_fifo_2_empty    : std_logic;
    SIGNAL command_fifo_1_in    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_2_in    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_3_in    : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_in_valid_pak    : std_logic;
    SIGNAL data_in_pak          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_in_ready_pak    : std_logic;
BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    PHY_Master_controller_COMPONENT : PHY_Master_controller
    GENERIC MAP(
        DATA_LEN    => 16,
        ADDRESS_LEN => 5,
        COMMAND_LEN => 16
    )
    PORT MAP(
        clk_top          => clk_top,
        reset            => reset,
        command_in       => command_in_pak,
        command_valid_in => command_in_pak_valid,
        data_in          => data_in_pak,
        valid_in         => data_in_valid_pak,
        data_in_ready    => data_in_ready_pak,
        data_out         => data_out_PHY,
        data_valid_out   => data_valid_out_PHY
    );

    -----------------------------------------------------------------------
    ---------------------  FIFO Instantiation -----------------------------
    -----------------------------------------------------------------------
    FIFO_1 : fifo_1
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_1,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_1,
        RdEn              => rd_en_fifo_1,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_1,
        Empty             => fifo_empty_1);

    READ_FIFO_1 : fifo_read_1
    PORT MAP(
        Data(15 DOWNTO 0) => read_data_latch_1,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => read_data_latch_en_1,
        RdEn              => read_data_out_en_1,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => read_data_out_1,
        Empty             => read_fifo_1_empty);

    FIFO_2 : fifo_2
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_2,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_2,
        RdEn              => rd_en_fifo_2,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_2,
        Empty             => fifo_empty_2);

    READ_FIFO_2 : fifo_read_2
    PORT MAP(
        Data(15 DOWNTO 0) => read_data_latch_2,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => read_data_latch_en_2,
        RdEn              => read_data_out_en_2,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => read_data_out_2,
        Empty             => read_fifo_2_empty);

    FIFO_3 : fifo_3
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_3,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_3,
        RdEn              => rd_en_fifo_3,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_3,
        Empty             => fifo_empty_3);

    READ_FIFO_3 : fifo_read_3
    PORT MAP(
        Data(15 DOWNTO 0) => read_data_latch_3,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => read_data_latch_en_3,
        RdEn              => read_data_out_en_3,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => read_data_out_3,
        Empty             => read_fifo_3_empty);

    Command_FIFO_1_block : command_fifo_1 -- make it based on priority
    PORT MAP(
        Data(15 DOWNTO 0) => command_fifo_1_in,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_command_fifo_1,
        RdEn              => rd_en_command_1,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => command_read_1,
        Empty             => command_fifo_empty_1);

    Command_FIFO_2_block : command_fifo_2 -- make it based on priority
    PORT MAP(
        Data(15 DOWNTO 0) => command_fifo_2_in,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_command_fifo_2,
        RdEn              => rd_en_command_2,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => command_read_2,
        Empty             => command_fifo_empty_2);

    Command_FIFO_3_block : command_fifo_3 -- make it based on priority
    PORT MAP(
        Data(15 DOWNTO 0) => command_fifo_3_in,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_command_fifo_3,
        RdEn              => rd_en_command_3,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => command_read_3,
        Empty             => command_fifo_empty_3);

    command_read <= command_read_1 WHEN rd_en_command_1 = '1' ELSE
        command_read_2 WHEN rd_en_command_2 = '1' ELSE
        command_read_3 WHEN rd_en_command_3 = '1';
    -----------------------------------------------------------------------
    ------------- Command_in | Data_in FIFO Write Logic -------------------
    -----------------------------------------------------------------------
    command_fifo_1_in <= command_in;
    command_fifo_2_in <= command_in;
    command_fifo_3_in <= command_in;

    data_fifo_1 <= data_in;
    data_fifo_2 <= data_in;
    data_fifo_3 <= data_in;

    fifo_in_logic : PROCESS (clk_top, reset)
        VARIABLE cntr : INTEGER := 0;
    BEGIN
        IF reset = '1' THEN
            wr_en_command_fifo_1 <= '0'; -- dont latch_in any data/command
            wr_en_command_fifo_2 <= '0';
            wr_en_command_fifo_3 <= '0';
            wr_en_fifo_1         <= '0'; -- dont latch_in any data/command
            wr_en_fifo_2         <= '0';
            wr_en_fifo_3         <= '0';
        ELSE
            IF command_valid_in = '1' THEN
                IF command_in((COMMAND_LEN - 7) DOWNTO (COMMAND_LEN - 6)) = "10" THEN
                    wr_en_command_fifo_1 <= '1';
                    wr_en_command_fifo_2 <= '0';
                    wr_en_command_fifo_3 <= '0';
                ELSIF command_in((COMMAND_LEN - 7) DOWNTO (COMMAND_LEN - 6)) = "01" THEN
                    wr_en_command_fifo_1 <= '0';
                    wr_en_command_fifo_2 <= '1';
                    wr_en_command_fifo_3 <= '0';
                ELSE
                    wr_en_command_fifo_1 <= '0';
                    wr_en_command_fifo_2 <= '0';
                    wr_en_command_fifo_3 <= '1';
                END IF;
                burst_length_in <= command_in((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));
                data_type_in    <= command_in((COMMAND_LEN - 7) DOWNTO (COMMAND_LEN - 6)); -- task priority
                wr_en_fifo_1    <= '0';
                wr_en_fifo_2    <= '0';
                wr_en_fifo_3    <= '0';
            ELSE
                wr_en_command_fifo_1 <= '0'; -- dont latch_in any data/command
                wr_en_command_fifo_2 <= '0';
                wr_en_command_fifo_3 <= '0';
            END IF;
            IF data_valid_in = '1' THEN
                IF cntr = burst_length_in THEN
                    cntr := 0;
                    IF data_type_in = "10" THEN
                        wr_en_fifo_1 <= '1';
                        wr_en_fifo_2 <= '0';
                        wr_en_fifo_3 <= '0';
                    ELSIF data_type_in = "01" THEN
                        wr_en_fifo_1 <= '0';
                        wr_en_fifo_2 <= '1';
                        wr_en_fifo_3 <= '0';
                    ELSE
                        wr_en_fifo_1 <= '0';
                        wr_en_fifo_2 <= '0';
                        wr_en_fifo_3 <= '1';
                    END IF;
                ELSE
                    cntr := cntr + 1;
                    IF data_type_in = "10" THEN
                        wr_en_fifo_1 <= '1';
                        wr_en_fifo_2 <= '0';
                        wr_en_fifo_3 <= '0';
                    ELSIF data_type_in = "01" THEN
                        wr_en_fifo_1 <= '0';
                        wr_en_fifo_2 <= '1';
                        wr_en_fifo_3 <= '0';
                    ELSE
                        wr_en_fifo_1 <= '0';
                        wr_en_fifo_2 <= '0';
                        wr_en_fifo_3 <= '1';
                    END IF;
                END IF;
            ELSE
                wr_en_fifo_1 <= '0';
                wr_en_fifo_2 <= '0';
                wr_en_fifo_3 <= '0';
            END IF;
        END IF;
    END PROCESS; -- identifier
    -----------------------------------------------------------------------
    ---------------------  Master User FSM --------------------------------
    -----------------------------------------------------------------------
    PHY_MASTER_USER_FSM : PROCESS (clk_top, reset)
        VARIABLE cntr_burst : INTEGER := 0;
    BEGIN
        IF reset = '1' THEN -- async reset
            state_transaction <= IDLE;
            wr_tr_en_PHY      <= '0';
            rd_tr_en_PHY      <= '0';
            data_in_PHY       <= (OTHERS => '0');
            data_valid_in_PHY <= '0';
            transaction_type  <= '0';
            burst_length      <= (OTHERS => '0');
            data_out          <= (OTHERS => '0');
            data_valid_out    <= '0';
            data_in_ready     <= '1';
            cntr_burst := 0;

        ELSIF rising_edge(clk_top) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    read_data_latch_en_1 <= '0';
                    read_data_latch_en_2 <= '0';
                    read_data_latch_en_3 <= '0';
                    rd_en_fifo_1         <= '0';
                    rd_en_fifo_2         <= '0';
                    rd_en_fifo_3         <= '0';
                    wr_tr_en_PHY         <= '0';
                    rd_tr_en_PHY         <= '0';
                    state_transaction    <= parse_command_priority;
                WHEN parse_command_priority =>
                    IF command_fifo_empty_1 = '0' THEN -- valid command avialable
                        rd_en_command_1   <= '1';          -- assert read enable flag for fifo
                        state_transaction <= parse_command_state;
                    ELSIF command_fifo_empty_2 = '0' THEN
                        rd_en_command_2   <= '1';
                        state_transaction <= parse_command_state;
                    ELSE
                        rd_en_command_3   <= '1';
                        state_transaction <= parse_command_state;
                    END IF;
                    ----------------------- parse command state
                WHEN parse_command_state =>
                    -- check for high priority command
                    rd_en_command_1   <= '0';          -- deassert read enable flag
                    rd_en_command_2   <= '0';          -- deassert read enable flag
                    rd_en_command_3   <= '0';          -- deassert read enable flag
                    data_in_PHY       <= command_read; -- latch in command packet to PHY tx
                    data_valid_in_PHY <= '1';
                    transaction_type  <= command_read(COMMAND_LEN - 1);
                    burst_length      <= command_read((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));
                    data_type         <= command_read((COMMAND_LEN - 7) DOWNTO (COMMAND_LEN - 6));
                    IF command_read(COMMAND_LEN - 1) = '1' THEN -- parse command MSB
                        state_transaction <= tx_state;
                    ELSE
                        state_transaction <= rx_state;
                    END IF;
                    ----------------------- Write transaction state
                WHEN tx_state =>
                    wr_tr_en_PHY <= '1';            -- write transaction enable for master PHY controller
                    IF data_in_ready_pak = '1' THEN -- if packet layer master is ready to accept new data
                        IF data_type = "10" THEN        -- if high priority data demanded
                            IF fifo_empty_1 = '0' THEN      -- if high priority data available
                                rd_en_fifo_1      <= '1';       -- latch in data in next clock cycle
                                rd_en_fifo_2      <= '0';
                                rd_en_fifo_3      <= '0';
                                state_transaction <= latch_tx_data; -- change state to latch in data
                            END IF;
                        ELSIF data_type = "01" THEN
                            IF fifo_empty_2 = '0' THEN
                                rd_en_fifo_1      <= '0';
                                rd_en_fifo_2      <= '1';
                                rd_en_fifo_3      <= '0';
                                state_transaction <= latch_tx_data;
                            END IF;
                        ELSE
                            IF fifo_empty_3 = '0' THEN
                                rd_en_fifo_1      <= '0';
                                rd_en_fifo_2      <= '0';
                                rd_en_fifo_3      <= '1';
                                state_transaction <= latch_tx_data;
                            END IF;
                        END IF;
                    ELSE
                        data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    END IF;
                WHEN latch_tx_data =>
                    IF rd_en_fifo_1 = '1' THEN
                        rd_en_fifo_1 <= '0';                  -- reset the read enable pin
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_1;  -- latch in new data
                            data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_1; -- latch in new data
                            data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                        END IF;
                    ELSIF rd_en_fifo_2 = '1' THEN
                        rd_en_fifo_2 <= '0';
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_2;  -- latch in new data
                            data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_2; -- latch in new data
                            data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                        END IF;
                    ELSE
                        rd_en_fifo_3 <= '0';
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_3;  -- latch in new data
                            data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_3; -- latch in new data
                            data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                        END IF;
                    END IF;
                    ----------------------- Read transaction state
                WHEN rx_State =>
                    rd_tr_en_PHY <= '1';             -- read transaction enable for master PHY controller
                    IF data_valid_out_PHY = '1' THEN -- if PHY controller has new valid data 
                        IF data_type = "10" THEN
                            IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                                cntr_burst := 0;                      -- reset the byte counter
                                read_data_latch_en_1 <= '1';          -- raise the valid output data flag 
                                read_data_latch_en_2 <= '0';
                                read_data_latch_en_3 <= '0';
                            ELSE
                                cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                                read_data_latch_en_1 <= '1';  -- raise the valid output data flag 
                                read_data_latch_en_2 <= '0';
                                read_data_latch_en_3 <= '0';
                            END IF;
                        ELSIF data_type = "01" THEN
                            IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                                cntr_burst := 0;                      -- reset the byte counter
                                read_data_latch_en_1 <= '0';          -- raise the valid output data flag 
                                read_data_latch_en_2 <= '1';
                                read_data_latch_en_3 <= '0';
                            ELSE
                                cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                                read_data_latch_en_1 <= '0';  -- raise the valid output data flag 
                                read_data_latch_en_2 <= '1';
                                read_data_latch_en_3 <= '0';
                            END IF;
                        ELSE
                            IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                                cntr_burst := 0;                      -- reset the byte counter
                                read_data_latch_en_1 <= '0';          -- raise the valid output data flag 
                                read_data_latch_en_2 <= '0';
                                read_data_latch_en_3 <= '1';
                            ELSE
                                cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                                read_data_latch_en_1 <= '0';  -- raise the valid output data flag 
                                read_data_latch_en_2 <= '0';
                                read_data_latch_en_3 <= '1';
                            END IF;
                        END IF;
                    ELSE
                        read_data_latch_en_1 <= '0'; -- raise the valid output data flag 
                        read_data_latch_en_2 <= '0';
                        read_data_latch_en_3 <= '0';
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    read_data_latch_1 <= data_out_PHY;
    read_data_latch_2 <= data_out_PHY;
    read_data_latch_3 <= data_out_PHY;
    -- fifo read logic read channel
    -- data_out <=
    --     data_valid_out
    -- 
END behavioral;