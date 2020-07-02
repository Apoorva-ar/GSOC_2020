-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY PHY_top_tb IS
END PHY_top_tb;

ARCHITECTURE behavior OF PHY_top_tb IS

    COMPONENT PHY_Slave_Controller
        PORT (
            clk_sys         : IN std_logic;
            reset_top       : IN std_logic;
            sclk_debug      : IN std_logic;
            data_in         : IN std_logic_vector(15 DOWNTO 0);
            valid_in        : IN std_logic;
            write_tr_en     : IN std_logic;
            read_tr_en      : IN std_logic;
            write_ready     : OUT std_logic;
            LVDS_IO_debug   : INOUT std_logic;
            data_out        : OUT std_logic_vector(15 DOWNTO 0);
            valid_out       : OUT std_logic;
            state_test      : OUT std_logic_vector(2 DOWNTO 0);
            tx_ready_S_test : OUT std_logic
        );
    END COMPONENT;

    COMPONENT PHY_Controller
        PORT (
            clk_sys       : IN std_logic;
            clk_sample    : IN std_logic;
            reset_top     : IN std_logic;
            data_in       : IN std_logic_vector(15 DOWNTO 0);
            valid_in      : IN std_logic;
            write_enable  : IN std_logic;
            read_enable   : IN std_logic;
            LVDS_IO_debug : INOUT std_logic;
            sclk_debug    : OUT std_logic;
            write_ready   : OUT std_logic;
            data_out      : OUT std_logic_vector(15 DOWNTO 0);
            valid_out     : OUT std_logic;
            test_1        : OUT std_logic;
            test_2        : OUT std_logic_vector(3 DOWNTO 0);
            test_3        : OUT std_logic;
            test_4        : OUT std_logic_vector(15 DOWNTO 0)
        );
    END COMPONENT;
    SIGNAL clk_sample          : std_logic;
    SIGNAL clk_temp            : std_logic;
    SIGNAL clk_sys             : std_logic;
    SIGNAL reset_top           : std_logic;
    SIGNAL LVDS_IO_debug       : std_logic;
    SIGNAL sclk_debug          : std_logic;
    SIGNAL data_in_slave       : std_logic_vector(15 DOWNTO 0);
    SIGNAL valid_in_slave      : std_logic;
    SIGNAL data_out_slave      : std_logic_vector(15 DOWNTO 0);
    SIGNAL valid_out_slave     : std_logic;
    SIGNAL write_tr_en_slave   : std_logic;
    SIGNAL read_tr_en_slave    : std_logic;
    SIGNAL data_in_master      : std_logic_vector(15 DOWNTO 0);
    SIGNAL valid_in_master     : std_logic;
    SIGNAL write_enable_master : std_logic;
    SIGNAL write_ready_master  : std_logic;
    SIGNAL write_ready_slave   : std_logic;
    SIGNAL data_out_master     : std_logic_vector(15 DOWNTO 0);
    SIGNAL valid_out_master    : std_logic;
    SIGNAL read_enable_master  : std_logic;
    SIGNAL test_1              : std_logic;
    SIGNAL test_2              : std_logic_vector(3 DOWNTO 0);
    SIGNAL test_3              : std_logic;
    SIGNAL test_4              : std_logic_vector(15 DOWNTO 0);
    SIGNAL Slave_state_test    : std_logic_vector(2 DOWNTO 0);
    SIGNAL tx_ready_S_test     : std_logic;
BEGIN
    -------------------------------------------------------------------------
    ------------------------ system clock generation ------------------------
    -------------------------------------------------------------------------
    sampling_clock : PROCESS
    BEGIN
        clk_temp <= '0';
        WAIT FOR 5ns;
        LOOP
            clk_temp <= NOT clk_temp;
            WAIT FOR 5ns;
        END LOOP;
    END PROCESS;
    clk_sys <= clk_temp; -- 1.6 MHz
    --------------------------------------------------------------------------------------------------------
    --------------------------------- Component instantiation ----------------------------------------------
    --------------------------------------------------------------------------------------------------------
    uut_Slave : PHY_Slave_Controller PORT MAP(
        clk_sys         => clk_sys,
        reset_top       => reset_top,
        LVDS_IO_debug   => LVDS_IO_debug,
        sclk_debug      => sclk_debug,
        data_in         => data_in_slave,
        valid_in        => valid_in_slave,
        data_out        => data_out_slave,
        valid_out       => valid_out_slave,
        write_tr_en     => write_tr_en_slave,
        read_tr_en      => read_tr_en_slave,
        state_test      => Slave_state_test,
        tx_ready_S_test => tx_ready_S_test,
        write_ready     => write_ready_slave
    );

    uut_Master : PHY_Controller PORT MAP(
        clk_sys       => clk_sys,
        clk_sample    => clk_sample,
        reset_top     => reset_top,
        LVDS_IO_debug => LVDS_IO_debug,
        sclk_debug    => sclk_debug,
        data_in       => data_in_master,
        valid_in      => valid_in_master,
        write_enable  => write_enable_master,
        write_ready   => write_ready_master,
        data_out      => data_out_master,
        valid_out     => valid_out_master,
        read_enable   => read_enable_master,
        test_1        => test_1,
        test_2        => test_2,
        test_3        => test_3,
        test_4        => test_4
    );
    -------------------------------------------------------------------------------------------------------------
    ------------------------------------ System Stimuli Process -------------------------------------------------
    -------------------------------------------------------------------------------------------------------------
    tb : PROCESS
    BEGIN
        ------- reset assertion
        reset_top         <= '1';
        write_tr_en_slave <= '0';
        read_tr_en_slave  <= '0';

        WAIT FOR 100 ns;
        ------ Write data to the master controller	
        reset_top           <= '0';
        write_enable_master <= '0';
        valid_in_master     <= '1';                -- assert valid data flag to latch in data 
        data_in_master      <= "0001000000001111"; -- new valid data 
        WAIT FOR 10ns;
        valid_in_master <= '1';
        data_in_master  <= "0001000100001111";
        WAIT FOR 50 ns;

        read_tr_en_slave    <= '1'; -- enable slave emulator for read transaction
        write_enable_master <= '1'; -- enable master write transaction
        -- valid_in_master     <= '0';
        WAIT FOR 150 ns;
        read_tr_en_slave    <= '0';
        write_enable_master <= '0';
        valid_in_master     <= '0';

        WAIT FOR 20000 ns;
        write_enable_master <= '0';
        data_in_slave       <= "1001000000001111";
        valid_in_slave      <= '1';
        WAIT FOR 200 ns;

        ------ Read data from the LVSD line 
        write_tr_en_slave  <= '1'; -- enable slave emulator for read transaction
        read_enable_master <= '1'; -- enable master read transaction
        WAIT FOR 150 ns;

        write_tr_en_slave  <= '0'; -- enable slave emulator for read transaction
        read_enable_master <= '0'; -- enable master write transaction
        WAIT FOR 20000 ns;
        valid_in_slave <= '0';
        WAIT; -- will wait forever 
    END PROCESS;

END;
