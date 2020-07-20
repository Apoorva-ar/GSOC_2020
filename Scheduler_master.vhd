-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
-- Command tells burst length and write/read transaction, address ans type of data packet (task priority)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

entity Packet_layer_Master_scheduler is
    generic (
        DATA_LEN    : integer := 16;
        ADDRESS_LEN : integer := 5;
        COMMAND_LEN : integer := 16
    );
    port (
        -------------- System Interfaces ---------
        clk_top, reset : in STD_LOGIC;
        -------------- Control channels ---------
        command_in       : in std_logic_vector(COMMAND_LEN - 1 downto 0);
        command_valid_in : in std_logic;
        ------------- DATA IO channel ------------
        LVDS_IO    : inout std_logic;
        LVDS_clock : out std_logic;
        ------- Address channel
        -- address_in        : IN std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_in  : IN std_logic;
        -- address_out       : OUT std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_out : OUT std_logic;
        ------- Data channel
        data_in        : in std_logic_vector(DATA_LEN - 1 downto 0);
        data_valid_in  : in std_logic;
        data_in_ready  : out std_logic;
        data_out       : out std_logic_vector(DATA_LEN - 1 downto 0);
        data_valid_out : out std_logic;
        ------------- Test Intefaces --------------
        test_1 : out std_logic;
        test_2 : out std_logic_vector(3 downto 0);
        test_3 : out std_logic;
        test_4 : out std_logic_vector(15 downto 0)
    );
end Packet_layer_Master_scheduler;

architecture behavioral of Packet_layer_Master_scheduler is

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    component PHY_Master_controller is
        generic (
            WORD_SIZE         : integer                      := 48;
            Data_Length       : integer                      := 16;
            SETUP_WORD_CYCLES : STD_LOGIC_VECTOR(9 downto 0) := "0010010000"; -- 144 cycles (48MHz) for 3us
            INTER_WORD_CYCLES : STD_LOGIC_VECTOR(9 downto 0) := "1001110000"; -- 624 cycles for 13us
            INTER_DATA_CYCLES : STD_LOGIC_VECTOR(9 downto 0) := "0001100000"; -- 96 cycles (48 MHz) for 2us
            CPOL              : std_logic                    := '0';
            CPHA              : std_logic                    := '1';
            CLK_PERIOD        : std_logic_vector(7 downto 0) := "00011110"; -- 30 cycles for 1.6MHz sclk from 48 Mhz system clock
            SETUP_CYCLES      : std_logic_vector(7 downto 0) := "00000110"; -- 6 cycles
            HOLD_CYCLES       : std_logic_vector(7 downto 0) := "00000110"; -- 6 cycles
            TX2TX_CYCLES      : std_logic_vector(7 downto 0) := "00000010");
        port (
            -------------- System Interfaces ---------
            clk_sys, clk_sample, reset_top : in STD_LOGIC;
            ------------- PHY Interfaces -------------
            LVDS_IO_debug : inout std_logic;
            sclk_debug    : out std_logic;
            ------------- DATA IO channel ------------
            data_in      : in std_logic_vector(DATA_LEN - 1 downto 0);
            valid_in     : in std_logic;
            write_enable : in std_logic;
            write_ready  : out std_logic;
            data_out     : out std_logic_vector(DATA_LEN - 1 downto 0);
            valid_out    : out std_logic;
            read_enable  : in std_logic;
            ------------- Test Intefaces --------------
            test_1 : out std_logic;
            test_2 : out std_logic_vector(3 downto 0);
            test_3 : out std_logic;
            test_4 : out std_logic_vector(15 downto 0)
        );
    end component;

    component command_fifo
        port (
            Data        : in std_logic_vector(15 downto 0);
            WrClock     : in std_logic;
            RdClock     : in std_logic;
            WrEn        : in std_logic;
            RdEn        : in std_logic;
            Reset       : in std_logic;
            RPReset     : in std_logic;
            Q           : out std_logic_vector(15 downto 0);
            Empty       : out std_logic;
            Full        : out std_logic;
            AlmostEmpty : out std_logic;
            AlmostFull  : out std_logic);
    end component;
    component fifo_1
        port (
            Data        : in std_logic_vector(15 downto 0);
            WrClock     : in std_logic;
            RdClock     : in std_logic;
            WrEn        : in std_logic;
            RdEn        : in std_logic;
            Reset       : in std_logic;
            RPReset     : in std_logic;
            Q           : out std_logic_vector(15 downto 0);
            Empty       : out std_logic;
            Full        : out std_logic;
            AlmostEmpty : out std_logic;
            AlmostFull  : out std_logic);
    end component;
    component fifo_2
        port (
            Data        : in std_logic_vector(15 downto 0);
            WrClock     : in std_logic;
            RdClock     : in std_logic;
            WrEn        : in std_logic;
            RdEn        : in std_logic;
            Reset       : in std_logic;
            RPReset     : in std_logic;
            Q           : out std_logic_vector(15 downto 0);
            Empty       : out std_logic;
            Full        : out std_logic;
            AlmostEmpty : out std_logic;
            AlmostFull  : out std_logic);
    end component;
    component fifo_3
        port (
            Data        : in std_logic_vector(15 downto 0);
            WrClock     : in std_logic;
            RdClock     : in std_logic;
            WrEn        : in std_logic;
            RdEn        : in std_logic;
            Reset       : in std_logic;
            RPReset     : in std_logic;
            Q           : out std_logic_vector(15 downto 0);
            Empty       : out std_logic;
            Full        : out std_logic;
            AlmostEmpty : out std_logic;
            AlmostFull  : out std_logic);
    end component;
    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------

    type state_S is(IDLE, parse_command_state, tx_state, rx_state);
    signal state_transaction  : state_S := IDLE;
    signal transaction_type   : std_logic; -- write/read transaction
    signal burst_length       : std_logic_vector(6 downto 0);
    signal data_type          : std_logic_vector(1 downto 0);
    signal data_valid_in_PHY  : std_logic;
    signal data_in_PHY        : std_logic_vector(DATA_LEN - 1 downto 0);
    signal data_valid_out_PHY : std_logic;
    signal data_out_PHY       : std_logic_vector(DATA_LEN - 1 downto 0);
    signal wr_tr_en_PHY       : std_logic;
    signal rd_tr_en_PHY       : std_logic;
    signal PHY_tx_ready       : std_logic;

begin

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    PHY_Master_controller_COMPONENT : PHY_Master_controller
    generic map(
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
    port map(
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

    PHY_MASTER_USER_FSM : process (clk_top, reset)
        variable cntr_burst : integer := 0;
    begin
        if reset = '1' then -- async reset
            state_transaction <= IDLE;
            wr_tr_en_PHY      <= '0';
            rd_tr_en_PHY      <= '0';
            data_in_PHY       <= (others => '0');
            data_valid_in_PHY <= '0';
            transaction_type  <= '0';
            burst_length      <= (others => '0');
            data_out          <= (others => '0');
            data_valid_out    <= '0';
            data_in_ready     <= '1';
            cntr_burst := 0;

        elsif rising_edge(clk_top) then
            case state_transaction is
                when IDLE =>
                    wr_tr_en_PHY <= '0';
                    rd_tr_en_PHY <= '0';
                    if command_valid_in = '1' then
                        state_transaction <= parse_command_state;
                    end if;
                    ----------------------- parse command state
                when parse_command_state =>
                    data_in_PHY       <= command_in; -- latch in command packet to PHY tx
                    data_valid_in_PHY <= '1';
                    transaction_type  <= command_in(COMMAND_LEN - 1);
                    burst_length      <= command_in((COMMAND_LEN - 2) downto (COMMAND_LEN - 8));
                    data_type         <= command_in((COMMAND_LEN - 7) downto (COMMAND_LEN - 6));
                    if command_in(COMMAND_LEN - 1) = '1' then -- parse command MSB
                        state_transaction <= tx_state;
                    else
                        state_transaction <= rx_state;
                    end if;
                    ----------------------- Write transaction state
                when tx_state =>
                    wr_tr_en_PHY <= '1';       -- write transaction enable for master PHY controller
                    if PHY_tx_ready = '1' then -- if controller is ready to accept new data
                        if data_type = "10" then
                            if fifo_empty_1 = '0' then
                                if cntr_burst = burst_length - 1 then -- if burst length is equaal to byte counter
                                    cntr_burst := 0;                      -- reset the byte counter
                                    data_in_PHY       <= data_in_fifo_1;  -- latch in new data
                                    data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                                else
                                    cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                                    data_in_PHY       <= data_in_fifo_1; -- latch in new data
                                    data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                                end if;
                            end if;
                        elsif data_type = "01" then
                            if fifo_empty_2 = '0' then
                                if cntr_burst = burst_length - 1 then -- if burst length is equaal to byte counter
                                    cntr_burst := 0;                      -- reset the byte counter
                                    data_in_PHY       <= data_in_fifo_2;  -- latch in new data
                                    data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                                else
                                    cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                                    data_in_PHY       <= data_in_fifo_2; -- latch in new data
                                    data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                                end if;
                            end if;
                        else
                            if fifo_empty_3 = '0' then
                                if cntr_burst = burst_length - 1 then -- if burst length is equaal to byte counter
                                    cntr_burst := 0;                      -- reset the byte counter
                                    data_in_PHY       <= data_in_fifo_3;  -- latch in new data
                                    data_valid_in_PHY <= '1';             -- raise the vallid input data flag for PHY controller
                                else
                                    cntr_burst := cntr_burst + 1;        -- increment byte counter on every sucessful write transaction 
                                    data_in_PHY       <= data_in_fifo_3; -- latch in new data
                                    data_valid_in_PHY <= '1';            -- raise the vallid input data flag for PHY controller
                                end if;
                            end if;
                        end if;
                    else
                        data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    end if;
                    ----------------------- Read transaction state
                when rx_State =>
                    rd_tr_en_PHY <= '1';                  -- read transaction enable for master PHY controller
                    if data_valid_out_PHY = '1' then      -- if PHY controller has new valid data 
                        if cntr_burst = burst_length - 1 then -- if burst length is equaal to byte counter
                            cntr_burst := 0;                      -- reset the byte counter
                            data_out       <= data_out_PHY;       -- latch out new data
                            data_valid_out <= '1';                -- raise the valid output data flag 
                        else
                            cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                            data_in_PHY    <= data_in;    -- latch out new data
                            data_valid_out <= '1';        -- raise the valid output data flag 
                        end if;
                    else
                        data_valid_out <= '0'; -- lower the vallid output data flag 
                    end if;
            end case;
        end if;
    end process;

    FIFO_1 : fifo_1
    port map(
        Data(15 downto 0) => data_fifo_1,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_1,
        RdEn              => rd_en_fifo_1,
        Reset             => reset,
        RPReset           => reset,
        Q(15 downto 0)    => data_in_fifo_1,
        Empty             => fifo_empty_1);
        
    FIFO_2 : fifo_2
    port map(
        Data(15 downto 0) => data_fifo_2,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_2,
        RdEn              => rd_en_fifo_2,
        Reset             => reset,
        RPReset           => reset,
        Q(15 downto 0)    => data_in_fifo_2,
        Empty             => fifo_empty_2);

    FIFO_3 : fifo_3
    port map(
        Data(15 downto 0) => data_fifo_3,
        WrClock           => clk_top,
        RdClock           => clk_top,
        WrEn              => wr_en_fifo_3,
        RdEn              => rd_en_fifo_3,
        Reset             => reset,
        RPReset           => reset,
        Q(15 downto 0)    => data_in_fifo_3,
        Empty             => fifo_empty_3);

    -- three fifo buffers instantiated
    -- fifo data in logic
    -- add read enable fifo logic
end behavioral;