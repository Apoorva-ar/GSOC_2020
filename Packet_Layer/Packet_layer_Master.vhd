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

ENTITY Packet_layer_Master IS
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
        LVDS_IO          : INOUT std_logic;
        LVDS_clock       : OUT std_logic;
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
        test_1         : OUT std_logic;
        test_2         : OUT std_logic_vector(3 DOWNTO 0);
        test_3         : OUT std_logic;
        test_4         : OUT std_logic_vector(15 DOWNTO 0)
    );
END Packet_layer_Master;

ARCHITECTURE behavioral OF Packet_layer_Master IS
    
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT PHY_Master_controller IS
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
            TX2TX_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000010");
        PORT (
            -------------- System Interfaces ---------
            clk_sys, clk_sample, reset_top : IN STD_LOGIC;
            ------------- PHY Interfaces -------------
            LVDS_IO_debug : INOUT std_logic;
            sclk_debug    : OUT std_logic;
            ------------- DATA IO channel ------------
            data_in      : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
            valid_in     : IN std_logic;
            write_enable : IN std_logic;
            write_ready  : OUT std_logic;
            data_out     : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
            valid_out    : OUT std_logic;
            read_enable  : IN std_logic;
            ------------- Test Intefaces --------------
            test_1 : OUT std_logic;
            test_2 : OUT std_logic_vector(3 DOWNTO 0);
            test_3 : OUT std_logic;
            test_4 : OUT std_logic_vector(15 DOWNTO 0)
        );
    END COMPONENT;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------

    TYPE state_S IS(IDLE, parse_command_state, tx_state, rx_state);
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

BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    PHY_Master_controller_COMPONENT : PHY_Master_controller
    GENERIC MAP(
        WORD_SIZE         => 48,
        Data_Length       => DATA_LEN,
        SETUP_WORD_CYCLES => "0010010000", -- 144 cycles (48MHz) for 3us
        INTER_WORD_CYCLES => "1001110000", -- 624 cycles for 13us
        INTER_DATA_CYCLES => "0001100000", -- 96 cycles (48 MHz) for 2us
        CPOL              => '0',
        CPHA              => '1',
        CLK_PERIOD        => "00011110", -- 30 cycles for 1.6MHz sclk from 48 Mhz system clock
        SETUP_CYCLES      => "00000110", -- 6 cycles
        HOLD_CYCLES       => "00000110", -- 6 cycles
        TX2TX_CYCLES      => "00000010")
    PORT MAP(
        clk_sys       => clk_top,
        clk_sample    => clk_top,
        reset_top     => reset,
        LVDS_IO_debug => LVDS_IO,
        sclk_debug    => LVDS_clock,
        data_in       => data_in_PHY,
        valid_in      => data_valid_in_PHY,
        write_enable  => wr_tr_en_PHY,
        write_ready   => PHY_tx_ready,
        data_out      => data_out_PHY,
        valid_out     => data_valid_out_PHY,
        read_enable   => rd_tr_en_PHY
    );

    -----------------------------------------------------------------------
    ---------------------  Master User FSM -----------------------------
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
                    wr_tr_en_PHY <= '0';
                    rd_tr_en_PHY <= '0';
                    IF command_valid_in = '1' THEN
                        state_transaction <= parse_command_state;
                    END IF;
                    ----------------------- parse command state
                WHEN parse_command_state =>
                    data_in_PHY       <= command_in; -- latch in command packet to PHY tx
                    data_valid_in_PHY <= '1';
                    transaction_type  <= command_in(COMMAND_LEN - 1);
                    burst_length      <= command_in((COMMAND_LEN - 2) DOWNTO (COMMAND_LEN - 8));
                    IF command_in(COMMAND_LEN - 1) = '1' THEN -- parse command MSB
                        state_transaction <= tx_state;
                    ELSE
                        state_transaction <= rx_state;
                    END IF;
                    ----------------------- Write transaction state
                WHEN tx_state =>
                    wr_tr_en_PHY <= '1';                  -- write transaction enable for master PHY controller
                    IF PHY_tx_ready = '1' THEN            -- if controller is ready to accept new data
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_in_PHY       <= data_in;         -- latch in new data
                            data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                        ELSE
                            cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                            data_in_PHY       <= data_in; -- latch in new data
                            data_valid_in_PHY <= '1';     -- raise the vallid input data flag for PHY controller
                        END IF;
                    ELSE
                        data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    END IF;
                    ----------------------- Read transaction state
                WHEN rx_State =>
                    rd_tr_en_PHY <= '1';                  -- read transaction enable for master PHY controller
                    IF data_valid_out_PHY = '1' THEN      -- if PHY controller has new valid data 
                        IF cntr_burst = burst_length - 1 THEN -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_out       <= data_out_PHY;       -- latch out new data
                            data_valid_out <= '1';                -- raise the valid output data flag 
                        ELSE
                            cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                            data_in_PHY    <= data_in;    -- latch out new data
                            data_valid_out <= '1';        -- raise the valid output data flag 
                        END IF;
                    ELSE
                        data_valid_out <= '0'; -- lower the vallid output data flag 
                    END IF;
            END CASE;
        END IF;
    END PROCESS;

END behavioral;
