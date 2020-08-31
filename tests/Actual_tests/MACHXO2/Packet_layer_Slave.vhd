-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
-- Command tells burst length and write/read transaction and address

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY Packet_layer_Slave IS
    GENERIC (
        DATA_LEN    : INTEGER := 16;
        ADDRESS_LEN : INTEGER := 5;
        COMMAND_LEN : INTEGER := 16
    );
    PORT (
        -------------- System Interfaces ---------
        clk_top, reset : IN STD_LOGIC;
        -------------- Control channels ---------
        command_out       : OUT std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
        command_valid_out : OUT std_logic;
        ------------- DATA IO channel ------------
        LVDS_IO    : INOUT std_logic;
        LVDS_clock : IN std_logic;
        ------- Address channel
        -- address_in           : IN std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_in     : IN std_logic;
        -- address_out          : OUT std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_out    : OUT std_logic;
        ------- Data channel
        data_in_S        : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_in_S  : IN std_logic;
        data_in_ready_S  : OUT std_logic;
        data_out_S       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
        data_valid_out_S : OUT std_logic;
        ------------- Test Intefaces --------------
        test_1                 : OUT std_logic;
        test_2                 : OUT std_logic_vector(3 DOWNTO 0);
        test_3                 : OUT std_logic;
        test_4                 : OUT std_logic_vector(15 DOWNTO 0);
        b_length_test          : OUT std_logic_vector(6 DOWNTO 0);
        tr_type_test           : OUT std_logic;
        slave_cntrl_state_test : OUT std_logic_vector(2 DOWNTO 0)
    );
END Packet_layer_Slave;

ARCHITECTURE behavioral OF Packet_layer_Slave IS

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT PHY_Slave_Controller IS
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
    END COMPONENT;

    COMPONENT OSCH
        -- synthesis translate_off
        GENERIC (NOM_FREQ : STRING := "9.85");
        -- synthesis translate_on
        PORT (
            STDBY    : IN std_logic;
            OSC      : OUT std_logic;
            SEDSTDBY : OUT std_logic);
    END COMPONENT;
    ATTRIBUTE NOM_FREQ             : STRING;
    ATTRIBUTE NOM_FREQ OF OSCinst0 : LABEL IS "9.85";

    COMPONENT DCCA
        PORT (
            CLKI : IN std_logic;
            CE   : IN std_logic;
            CLKO : OUT std_logic);
    END COMPONENT;

    COMPONENT PLL_top
        PORT (
            CLKI  : IN std_logic;
            CLKOP : OUT std_logic);
    END COMPONENT;
    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------

    TYPE state_S IS(IDLE, tx_transmit, tx_end_state, command_wait_state, tx_wait_state,
    wait_syn_state, command_read_state, parse_command_state, tx_state_count, rx_state);
    SIGNAL state_transaction  : state_S := IDLE;
    SIGNAL transaction_type   : std_logic; -- write/read transaction
    SIGNAL burst_length       : std_logic_vector(6 DOWNTO 0);
    SIGNAL data_valid_in_PHY  : std_logic;
    SIGNAL data_in_PHY        : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL data_valid_out_PHY : std_logic;
    SIGNAL data_out_PHY       : std_logic_vector(DATA_LEN - 1 DOWNTO 0);
    SIGNAL wr_tr_en_PHY       : std_logic;
    SIGNAL rd_tr_en_PHY       : std_logic;
    SIGNAL PHY_tx_ready       : std_logic;
    SIGNAL write_tr_en_signal : std_logic;
    SIGNAL read_tr_en_signal  : std_logic;
    SIGNAL slave_state        : std_logic_vector(2 DOWNTO 0);
    SIGNAL write_ready_signal : std_logic;
    SIGNAL command_in         : std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
    SIGNAL LVDS_IO_signal     : std_logic;
    SIGNAL clock_signal       : std_logic;
    SIGNAL clock_signal_buf   : std_logic;
    SIGNAL clock_PLL_in       : std_logic;

BEGIN
    b_length_test <= burst_length;
    -- tr_type_test  <= transaction_type;
    ----------------------------------------------------------------------------------------
    ----------------------------- Internal CLock Instantiation  ----------------------------
    ----------------------------------------------------------------------------------------
    OSCInst0 : OSCH
    -- synthesis translate_off
    GENERIC MAP(NOM_FREQ => "9.85")
    -- synthesis translate_on
    PORT MAP(
        STDBY    => '0',
        OSC      => clock_signal,
        SEDSTDBY => OPEN
    );

    Central_PLL : PLL_top
    PORT MAP(
        CLKI  => clock_signal,
        CLKOP => clock_PLL_in
    );

    I1 : DCCA
    PORT MAP(
        CLKI => clock_PLL_in,
        CE   => '1',
        CLKO => clock_signal_buf
    );

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    PHY_Slave_Controller_COMPONENT : PHY_Slave_Controller
    GENERIC MAP(
        Data_Length => DATA_LEN,
        CPOL        => '0',
        CPHA        => '1')
    PORT MAP(
        clk_sys         => clock_signal_buf, --clk_top,
        reset_top       => reset,
        data_in         => data_in_PHY,
        valid_in        => data_valid_in_PHY,
        data_out        => data_out_PHY,
        valid_out       => data_valid_out_PHY,
        write_tr_en     => write_tr_en_signal,
        read_tr_en      => read_tr_en_signal,
        write_ready     => write_ready_signal,
        state_test      => slave_state,
        LVDS_IO_debug   => LVDS_IO,
        sclk_debug      => LVDS_clock,
        tx_ready_S_test => tr_type_test
    );
    test_1                 <= data_valid_out_PHY;
    test_3                 <= read_tr_en_signal;
    slave_cntrl_state_test <= slave_state;

    -----------------------------------------------------------------------
    ---------------------  Slave User FSM -----------------------------
    -----------------------------------------------------------------------

    PACKET_SLAVE_USER_FSM : PROCESS (clock_signal_buf, reset)
        VARIABLE cntr_burst : std_logic_vector(6 DOWNTO 0) := "0000000";
    BEGIN
        IF reset = '1' THEN -- async reset
            test_2             <= "0000";
            state_transaction  <= IDLE;
            write_tr_en_signal <= '0';
            read_tr_en_signal  <= '0';
            data_in_PHY        <= (OTHERS => '0');
            data_valid_in_PHY  <= '0';
            transaction_type   <= '0';
            burst_length       <= (OTHERS => '0');
            data_out_S         <= (OTHERS => '0');
            data_valid_out_S   <= '0';
            data_in_ready_S    <= '1';
            cntr_burst := (OTHERS => '0');

        ELSIF rising_edge(clock_signal_buf) THEN
            CASE state_transaction IS
                WHEN IDLE             =>
                    cntr_burst := (OTHERS => '0');
                    test_2             <= "0000";
                    write_tr_en_signal <= '0';
                    read_tr_en_signal  <= '1'; -- read transaction enable to read command packet
                    data_in_ready_S    <= '1'; -- set tx ready falg as 1
                    state_transaction  <= command_wait_state;
                WHEN command_wait_state =>
                    test_2            <= "1000";
                    read_tr_en_signal <= '0'; -- read transaction disable
                    state_transaction <= command_read_state;
                WHEN command_read_state =>
                    test_2 <= "1001";
                    IF data_valid_out_PHY = '1' THEN
                        -- read_tr_en_signal <= '0'; -- read transaction disable for master PHY controller  
                        state_transaction <= parse_command_state;
                        command_in        <= data_out_PHY;
                        command_out       <= data_out_PHY;
                        command_valid_out <= '1';
                    ELSE
                        -- read_tr_en_signal <= '1'; -- read transaction enable to parse command packet
                        command_valid_out <= '0';
                    END IF;
                    ----------------------- parse command state -----------------------
                WHEN parse_command_state =>
                    command_valid_out <= '0';
                    test_2            <= "0001";
                    IF command_in(COMMAND_LEN - 1) = '0' THEN -- parse command MSB
                        state_transaction  <= tx_state_count;     -- tx_state_count;
                        data_in_ready_S    <= '0';                -- set tx ready flag as 0
                        read_tr_en_signal  <= '0';                -- read transaction disable for master PHY controller  
                        write_tr_en_signal <= '1';                -- write transaction enable for master PHY controller
                    ELSE
                        state_transaction <= wait_syn_state;
                        read_tr_en_signal <= '1'; -- read transaction enable for master PHY controller  
                    END IF;
                    transaction_type <= command_in(COMMAND_LEN - 1); -- record address and burst length
                    burst_length     <= command_in((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));

                    ----------------------- Write transaction state --------------------
                WHEN tx_wait_state =>
                    state_transaction <= tx_state_count;
                    test_2            <= "0010";
                WHEN tx_state_count =>
                    test_2       <= "0011";
                    rd_tr_en_PHY <= '0';             -- read transaction disable for master PHY controller
                    --IF data_valid_in_S = '1' THEN    -- if new input data is available from user space
                        data_valid_in_PHY <= '1';        -- raise the vallid input data flag for PHY controller
                        IF write_ready_signal = '1' THEN -- if controller is ready to accept new data ("tx_ready_controller")
                            -- write_tr_en_signal <= '1';       -- write transaction enable for master PHY controller
                            data_in_PHY       <= x"1234"; --data_in_S; -- latch in new data
                            state_transaction <= tx_transmit;
                        END IF;
                    --ELSE
                    --    data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    --END IF;
                WHEN tx_transmit =>
                    test_2 <= "0100";
                    IF cntr_burst = (burst_length - 1) THEN -- if burst length is equaal to byte counter
                        cntr_burst := (OTHERS => '0');          -- reset the byte counter
                        state_transaction <= tx_end_state;      --IDLE;              -- stop transaction
                    ELSE
                        cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                        state_transaction <= tx_state_count;
                    END IF;
                WHEN tx_end_state =>
                    test_2             <= "1100";
                    write_tr_en_signal <= '0';

                    IF write_ready_signal = '1' THEN -- if controller is ready to accept new data ("tx_ready_controller")
                        state_transaction <= IDLE;       -- stop transaction
                        read_tr_en_signal <= '1';        -- read transaction enable to read command packet
                    END IF;
                    ----------------------- Read transaction state --------------------------
                WHEN wait_syn_state =>
                    test_2            <= "0101";
                    state_transaction <= rx_State;
                WHEN rx_State =>
                    test_2             <= "0110";
                    write_tr_en_signal <= '0';            -- write transaction disable for master PHY controller
                    IF data_valid_out_PHY = '1' THEN      -- if PHY controller has new valid data 
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := (OTHERS => '0');        -- reset the byte counter
                            data_out_S        <= data_out_PHY;    -- latch out new data
                            data_valid_out_S  <= '1';             -- raise the valid output data flag 
                            state_transaction <= IDLE;
                            read_tr_en_signal <= '0'; -- read transaction enable for master PHY controller
                        ELSE
                            cntr_burst := cntr_burst + 1;      -- increment byte counter on every sucessful write transaction 
                            data_out_S        <= data_out_PHY; -- latch out new data
                            data_valid_out_S  <= '1';          -- raise the valid output data flag 
                            read_tr_en_signal <= '1';          -- read transaction enable for master PHY controller
                        END IF;
                    ELSE
                        data_valid_out_S  <= '0'; -- lower the vallid output data flag 
                        read_tr_en_signal <= '1';
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

    -- FSM_Trigger : PROCESS (LVDS_IO)
    -- BEGIN
    --     IF falling_edge(LVDS_IO) THEN
    --         IF state_transaction = IDLE THEN
    --             Start_FSM <= '1';
    --         ELSE
    --             Start_FSM <= '0';
    --         END IF;
    --     END IF;
    -- END PROCESS; -- identifier

END behavioral;