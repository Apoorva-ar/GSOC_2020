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
        LVDS_IO_top    : INOUT std_logic;
        LVDS_clock_top : OUT std_logic;
        ------- Data channel
        data_in            : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_in      : IN std_logic;
        data_in_ready      : OUT std_logic;
        data_out_top       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_out_top : OUT std_logic;
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
    COMPONENT data_fifo_1
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
    COMPONENT data_fifo_2
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
    COMPONENT data_fifo_3
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

    TYPE state_S IS(IDLE, parse_command_priority, transaction_decision_state,
    parse_command_state, wait_command_sync_state_tx, tx_state, wait_command_sync_state_rx,
    latch_tx_data, tx_wait_sync, rx_state);
    SIGNAL state_test            : std_logic_vector(3 DOWNTO 0);
    SIGNAL state_transaction     : state_S := IDLE;
    SIGNAL transaction_type      : std_logic; -- write/read transaction
    SIGNAL data_fifo_out_valid_1 : std_logic;
    SIGNAL data_fifo_out_valid_2 : std_logic;
    SIGNAL data_fifo_out_valid_3 : std_logic;
    SIGNAL burst_length          : std_logic_vector(6 DOWNTO 0);
    SIGNAL data_type             : std_logic_vector(1 DOWNTO 0);
    SIGNAL burst_length_in       : std_logic_vector(6 DOWNTO 0);
    SIGNAL data_type_in          : std_logic_vector(1 DOWNTO 0);
    SIGNAL data_valid_in_PHY     : std_logic;
    SIGNAL data_in_PHY           : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_valid_out_PHY    : std_logic;
    SIGNAL data_out_PHY          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_tr_en_PHY          : std_logic;
    SIGNAL rd_tr_en_PHY          : std_logic;
    SIGNAL PHY_tx_ready          : std_logic;
    SIGNAL data_fifo_1_sig       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_1          : std_logic;
    SIGNAL rd_en_fifo_1          : std_logic;
    SIGNAL data_in_fifo_1        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_1          : std_logic;
    SIGNAL data_fifo_2_sig       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_2          : std_logic;
    SIGNAL rd_en_fifo_2          : std_logic;
    SIGNAL data_in_fifo_2        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_2          : std_logic;
    SIGNAL data_fifo_3_sig       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_fifo_3          : std_logic;
    SIGNAL rd_en_fifo_3          : std_logic;
    SIGNAL data_in_fifo_3        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL fifo_empty_3          : std_logic;
    SIGNAL rd_en_command_1       : std_logic;
    SIGNAL command_read          : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_read_1        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_empty_1  : std_logic;
    SIGNAL rd_en_command_2       : std_logic;
    SIGNAL command_read_2        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_in_pak        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_in_pak_valid  : std_logic;
    SIGNAL command_fifo_empty_2  : std_logic;
    SIGNAL rd_en_command_3       : std_logic := '0';
    SIGNAL command_read_3        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_empty_3  : std_logic;
    SIGNAL read_data_latch_3     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_3  : std_logic;
    SIGNAL read_data_out_3       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_3    : std_logic;
    SIGNAL read_fifo_3_empty     : std_logic;
    SIGNAL read_data_latch_1     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_1  : std_logic;
    SIGNAL read_data_out_1       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_1    : std_logic;
    SIGNAL read_fifo_1_empty     : std_logic;
    SIGNAL read_data_latch_2     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_latch_en_2  : std_logic;
    SIGNAL read_data_out_2       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL read_data_out_en_2    : std_logic;
    SIGNAL read_fifo_2_empty     : std_logic;
    SIGNAL command_fifo_1_in     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_2_in     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL command_fifo_3_in     : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_in_valid_pak     : std_logic;
    SIGNAL data_in_pak           : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_in_ready_pak     : std_logic;
    SIGNAL command_in_reg        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_in_reg           : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_en_command_fifo_1  : std_logic;
    SIGNAL wr_en_command_fifo_2  : std_logic;
    SIGNAL wr_en_command_fifo_3  : std_logic;
    SIGNAL command_out_valid_1   : std_logic;
    SIGNAL command_out_valid_2   : std_logic;
    SIGNAL command_out_valid_3   : std_logic;
BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    Packet_Layer_Master_Component : packet_layer_Master
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
        LVDS_IO          => LVDS_IO_top,
        LVDS_clock       => LVDS_clock_top,
        data_in          => data_in_pak,
        data_valid_in    => data_in_valid_pak,
        data_in_ready    => data_in_ready_pak,
        data_out         => data_out_PHY,
        data_valid_out   => data_valid_out_PHY
    );

    -----------------------------------------------------------------------
    ---------------------  FIFO Instantiation -----------------------------
    -----------------------------------------------------------------------
    FIFO_wr_1 : data_fifo_1
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_1_sig,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_1,
        RdEn              => rd_en_fifo_1,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_1,
        Empty             => fifo_empty_1);

    FIFO_wr_2 : data_fifo_2
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_2_sig,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_2,
        RdEn              => rd_en_fifo_2,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_2,
        Empty             => fifo_empty_2);

    FIFO_wr_3 : data_fifo_3
    PORT MAP(
        Data(15 DOWNTO 0) => data_fifo_3_sig,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_3,
        RdEn              => rd_en_fifo_3,
        Reset             => reset,
        RPReset           => reset,
        Q(15 DOWNTO 0)    => data_in_fifo_3,
        Empty             => fifo_empty_3);

    Write_Data_FIFO_Valid_out_FF : PROCESS (clk_top, reset) -- Flip Flop to control command valid out signal 
    BEGIN
        IF reset = '1' THEN
            data_fifo_out_valid_1 <= '0';
            data_fifo_out_valid_2 <= '0';
            data_fifo_out_valid_3 <= '0';
        ELSE
            IF rising_edge(clk_top) THEN
                data_fifo_out_valid_1 <= rd_en_fifo_1;
                data_fifo_out_valid_2 <= rd_en_fifo_2;
                data_fifo_out_valid_3 <= rd_en_fifo_3;
            END IF;
        END IF;
    END PROCESS;

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

    Command_FIFO_Valid_out_FF : PROCESS (clk_top, reset) -- Flip Flop to control command valid out signal 
    BEGIN
        IF reset = '1' THEN
            command_out_valid_1 <= '0';
            command_out_valid_2 <= '0';
            command_out_valid_3 <= '0';
        ELSE
            IF rising_edge(clk_top) THEN
                command_out_valid_1 <= rd_en_command_1;
                command_out_valid_2 <= rd_en_command_2;
                command_out_valid_3 <= rd_en_command_3;
            END IF;
        END IF;
    END PROCESS;

    command_read <= command_read_1 WHEN command_out_valid_1 = '1' ELSE -- Read command fifo data (mux) based on read enable fifo flag 
        command_read_2 WHEN command_out_valid_2 = '1' ELSE
        command_read_3 WHEN command_out_valid_3 = '1' ELSE
        (OTHERS => '0');
    -----------------------------------------------------------------------
    ------------- Command_in | Data_in FIFO Write Logic -------------------
    -----------------------------------------------------------------------
    command_fifo_1_in <= command_in_reg; -- command_in;
    command_fifo_2_in <= command_in_reg; -- command_in;
    command_fifo_3_in <= command_in_reg; -- command_in;

    data_fifo_1_sig <= data_in_reg; -- data_in;
    data_fifo_2_sig <= data_in_reg; -- data_in;
    data_fifo_3_sig <= data_in_reg; -- data_in;

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
            -- Command FIFO input management
            IF command_valid_in = '1' THEN
                command_in_reg <= command_in; -- latch in command
                IF command_in((COMMAND_LEN - 9) DOWNTO (COMMAND_LEN - 10)) = "10" THEN
                    wr_en_command_fifo_1 <= '1';
                    wr_en_command_fifo_2 <= '0';
                    wr_en_command_fifo_3 <= '0';
                ELSIF command_in((COMMAND_LEN - 9) DOWNTO (COMMAND_LEN - 10)) = "01" THEN
                    wr_en_command_fifo_1 <= '0';
                    wr_en_command_fifo_2 <= '1';
                    wr_en_command_fifo_3 <= '0';
                ELSE
                    wr_en_command_fifo_1 <= '0';
                    wr_en_command_fifo_2 <= '0';
                    wr_en_command_fifo_3 <= '1';
                END IF;
                burst_length_in <= command_in((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));
                data_type_in    <= command_in((COMMAND_LEN - 9) DOWNTO (COMMAND_LEN - 10)); -- task priority
                wr_en_fifo_1    <= '0';
                wr_en_fifo_2    <= '0';
                wr_en_fifo_3    <= '0';
            ELSE
                wr_en_command_fifo_1 <= '0'; -- dont latch_in any data/command
                wr_en_command_fifo_2 <= '0';
                wr_en_command_fifo_3 <= '0';
            END IF;
            -- Data fifo input management
            IF data_valid_in = '1' THEN
                data_in_reg <= data_in; -- latch in data
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
            data_in_PHY       <= (OTHERS => '0');
            data_valid_in_PHY <= '0';
            transaction_type  <= '0';
            burst_length      <= (OTHERS => '0');
            data_in_ready     <= '1';
            cntr_burst := 0;

        ELSIF rising_edge(clk_top) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    state_test           <= "0000";
                    read_data_latch_en_1 <= '0';
                    read_data_latch_en_2 <= '0';
                    read_data_latch_en_3 <= '0';
                    rd_en_fifo_1         <= '0';
                    rd_en_fifo_2         <= '0';
                    rd_en_fifo_3         <= '0';
                    data_in_valid_pak    <= '0';
                    state_transaction    <= parse_command_priority;
                    ----------------------- service priority decision state
                WHEN parse_command_priority => -- check if valid command is available in FIFO based on priority
                    state_test <= "0001";
                    IF command_fifo_empty_1 = '0' THEN -- valid command avialable
                        rd_en_command_1   <= '1';          -- assert read enable flag for fifo
                        state_transaction <= parse_command_state;
                    ELSIF command_fifo_empty_2 = '0' THEN
                        rd_en_command_2   <= '1';
                        state_transaction <= parse_command_state;
                    ELSIF command_fifo_empty_3 = '0' THEN
                        rd_en_command_3   <= '1';
                        state_transaction <= parse_command_state;
                    ELSE
                        rd_en_command_1 <= '0'; -- deassert read enable flag
                        rd_en_command_2 <= '0'; -- deassert read enable flag
                        rd_en_command_3 <= '0'; -- deassert read enable flag
                    END IF;
                    ----------------------- parse command state
                WHEN parse_command_state =>
                    state_test        <= "0010";
                    rd_en_command_1   <= '0'; -- deassert read enable flag
                    rd_en_command_2   <= '0'; -- deassert read enable flag
                    rd_en_command_3   <= '0'; -- deassert read enable flag
                    state_transaction <= transaction_decision_state;
                    ----------------------- transaction decision state
                WHEN transaction_decision_state =>
                    state_test           <= "0011";
                    transaction_type     <= command_read(COMMAND_LEN - 1);
                    burst_length         <= command_read((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));
                    data_type            <= command_read((COMMAND_LEN - 9) DOWNTO (COMMAND_LEN - 10));
                    command_in_pak       <= command_read; -- latch in command packet to packet controller command register
                    command_in_pak_valid <= '1';
                    IF command_read(COMMAND_LEN - 1) = '1' THEN -- parse command MSB
                        state_transaction <= wait_command_sync_state_tx;
                    ELSE
                        state_transaction <= wait_command_sync_state_rx;
                    END IF;
                    ---------------------- Wait for command trasaction to finish
                WHEN wait_command_sync_state_tx => -- synchronisation with sink
                    state_test <= "0100";
                    IF data_in_ready_pak = '1' THEN
                        state_transaction    <= tx_state;
                        command_in_pak_valid <= '0'; -- lower the valid command_in flag
                    END IF;
                WHEN wait_command_sync_state_rx => -- synchronisation with sink
                    state_test <= "1000";
                    IF data_in_ready_pak = '1' THEN
                        state_transaction    <= rx_state;
                        command_in_pak_valid <= '0'; -- lower the valid command_in flag
                    END IF;
                    ----------------------- Write transaction state 
                WHEN tx_state =>
                    state_test           <= "0101";
                    data_in_valid_pak    <= '0';    -- lower the valid input data flag for SInk
                    command_in_pak_valid <= '0';    -- lower the valid command_in flag
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
                    END IF;
                WHEN latch_tx_data =>
                    state_test   <= "0110";
                    rd_en_fifo_1 <= '0'; -- reset the read enable pin
                    rd_en_fifo_2 <= '0';
                    rd_en_fifo_3 <= '0';
                    IF data_fifo_out_valid_1 = '1' THEN
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_1;  -- latch in new data
                            data_in_valid_pak <= '1';             -- raise the vallid input data flag for SInk
                            state_transaction <= IDLE;
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_1; -- latch in new data
                            data_in_valid_pak <= '1';            -- raise the vallid input data flag for Sink
                            state_transaction <= tx_wait_sync;
                        END IF;
                    ELSIF data_fifo_out_valid_2 = '1' THEN
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_2;  -- latch in new data
                            data_in_valid_pak <= '1';             -- raise the vallid input data flag for PHY controller
                            state_transaction <= IDLE;
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_2; -- latch in new data
                            data_in_valid_pak <= '1';            -- raise the vallid input data flag for PHY controller
                            state_transaction <= tx_wait_sync;
                        END IF;
                    ELSIF data_fifo_out_valid_3 = '1' THEN
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_pak       <= data_in_fifo_3;  -- latch in new data
                            data_in_valid_pak <= '1';             -- raise the vallid input data flag for PHY controller
                            state_transaction <= IDLE;
                        ELSE
                            cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                            data_in_pak       <= data_in_fifo_3; -- latch in new data
                            data_in_valid_pak <= '1';            -- raise the vallid input data flag for PHY controller
                            state_transaction <= tx_wait_sync;
                        END IF;
                    ELSE
                        data_in_valid_pak <= '0';
                    END IF;
                WHEN tx_wait_sync => -- handshaking synchronization with sink
                    state_test        <= "0111";
                    state_transaction <= tx_state;
                    ----------------------- Read transaction state
                WHEN rx_State =>
                    command_in_pak_valid <= '0'; -- lower the valid command_in flag
                    state_test           <= "1001";
                    IF data_valid_out_PHY = '1' THEN
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_out_top       <= data_out_PHY;
                            data_valid_out_top <= '1';
                            state_transaction  <= IDLE;
                        ELSE
                            cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                            data_out_top       <= data_out_PHY;
                            data_valid_out_top <= '1';
                            state_transaction  <= rx_State;
                        END IF;
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    test_1 <= command_in_pak_valid;
    test_2 <= state_test;     -- wr_en_command_fifo_1 & wr_en_command_fifo_2 & wr_en_command_fifo_3 & '0';
    test_4 <= command_in_pak; --command_read; --command_in_pak;

END behavioral;
