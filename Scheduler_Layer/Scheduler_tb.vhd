-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
-- Command tells burst length and write/read transaction, address ans type of data packet (task priority)

-- VHDL Test Bench Created from source file Packet_layer_Master_scheduler.vhd 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY Packet_layer_Master_scheduler_tb IS
END Packet_layer_Master_scheduler_tb;

ARCHITECTURE behavior OF Packet_layer_Master_scheduler_tb IS

    COMPONENT Packet_layer_Master_scheduler
        PORT (
            clk_top            : IN std_logic;
            reset              : IN std_logic;
            command_in         : IN std_logic_vector(15 DOWNTO 0);
            command_valid_in   : IN std_logic;
            data_in            : IN std_logic_vector(15 DOWNTO 0);
            data_valid_in      : IN std_logic;
            LVDS_IO_top        : INOUT std_logic;
            LVDS_clock_top     : OUT std_logic;
            data_in_ready      : OUT std_logic;
            data_out_top       : OUT std_logic_vector(15 DOWNTO 0);
            data_valid_out_top : OUT std_logic;
            test_1             : OUT std_logic;
            test_2             : OUT std_logic_vector(3 DOWNTO 0);
            test_3             : OUT std_logic;
            test_4             : OUT std_logic_vector(15 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT packet_layer_slave IS
        PORT (
            clk_top, reset         : IN STD_LOGIC;
            command_out            : OUT std_logic_vector(16 - 1 DOWNTO 0);
            command_valid_out      : OUT std_logic;
            LVDS_IO                : INOUT std_logic;
            LVDS_clock             : IN std_logic;
            data_in_S              : IN std_logic_vector(16 - 1 DOWNTO 0);
            data_valid_in_S        : IN std_logic;
            data_in_ready_S        : OUT std_logic;
            data_out_S             : OUT std_logic_vector(16 - 1 DOWNTO 0);
            data_valid_out_S       : OUT std_logic;
            test_1                 : OUT std_logic;
            test_2                 : OUT std_logic_vector(3 DOWNTO 0);
            test_3                 : OUT std_logic;
            test_4                 : OUT std_logic_vector(15 DOWNTO 0);
            b_length_test          : OUT std_logic_vector(6 DOWNTO 0);
            tr_type_test           : OUT std_logic;
            slave_cntrl_state_test : OUT std_logic_vector(2 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL clk_top                : std_logic;
    SIGNAL reset                  : std_logic;
    SIGNAL command_in             : std_logic_vector(15 DOWNTO 0);
    SIGNAL command_valid_in       : std_logic;
    SIGNAL LVDS_IO_top            : std_logic;
    SIGNAL LVDS_clock_top         : std_logic;
    SIGNAL data_in                : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_valid_in          : std_logic;
    SIGNAL data_in_ready          : std_logic;
    SIGNAL data_out_top           : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_valid_out_top     : std_logic;
    SIGNAL test_1                 : std_logic;
    SIGNAL test_2                 : std_logic_vector(3 DOWNTO 0);
    SIGNAL test_3                 : std_logic;
    SIGNAL test_4                 : std_logic_vector(15 DOWNTO 0);
    SIGNAL b_length_test          : std_logic_vector(6 DOWNTO 0);
    SIGNAL tr_type_test           : std_logic;
    SIGNAL b_length_test_S        : std_logic_vector(6 DOWNTO 0);
    SIGNAL tr_type_test_S         : std_logic;
    SIGNAL data_in_S              : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_valid_in_S        : std_logic;
    SIGNAL data_out               : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_out_S             : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_in_ready_S        : std_logic;
    SIGNAL data_valid_out         : std_logic;
    SIGNAL data_valid_out_S       : std_logic;
    SIGNAL tx_ready               : std_logic;
    SIGNAL master_state           : std_logic_vector(3 DOWNTO 0);
    SIGNAL slave_state            : std_logic_vector(3 DOWNTO 0);
    SIGNAL clk_temp               : std_logic;
    SIGNAL command_valid_out_S    : std_logic;
    SIGNAL command_out_S          : std_logic_vector(15 DOWNTO 0);
    SIGNAL rx_valid_Slave         : std_logic;
    SIGNAL wr_tr_slave            : std_logic;
    SIGNAL slave_cntrl_state_test : std_logic_vector(2 DOWNTO 0);
    SIGNAL MOSI_test              : std_logic;
    SIGNAL MISO_test              : std_logic;
    SIGNAL sclk_test              : std_logic;
    SIGNAL CS_test                : std_logic;
BEGIN

    -- Please check and add your generic clause manually
    uut_master : Packet_layer_Master_scheduler PORT MAP(
        clk_top            => clk_top,
        reset              => reset,
        command_in         => command_in,
        command_valid_in   => command_valid_in,
        LVDS_IO_top        => LVDS_IO_top,
        LVDS_clock_top     => LVDS_clock_top,
        data_in            => data_in,
        data_valid_in      => data_valid_in,
        data_in_ready      => data_in_ready,
        data_out_top       => data_out_top,
        data_valid_out_top => data_valid_out_top,
        test_1             => test_1,
        test_2             => test_2,
        test_3             => test_3,
        test_4             => test_4
    );
    uut_slave : packet_layer_slave PORT MAP(
        clk_top                => clk_top,
        reset                  => reset,
        command_out            => command_out_S,
        command_valid_out      => command_valid_out_S,
        LVDS_IO                => LVDS_IO_top,
        LVDS_clock             => LVDS_clock_top,
        data_in_S              => data_in_S,
        data_valid_in_S        => data_valid_in_S,
        data_in_ready_S        => data_in_ready_S,
        data_out_S             => data_out_S,
        data_valid_out_S       => data_valid_out_S,
        b_length_test          => b_length_test_S,
        tr_type_test           => tr_type_test_S,
        test_2                 => slave_state,
        test_1                 => rx_valid_Slave,
        test_3                 => wr_tr_slave,
        slave_cntrl_state_test => slave_cntrl_state_test
    );
    sampling_clock : PROCESS
    BEGIN
        clk_temp <= '0';
        WAIT FOR 5ns;
        LOOP
            clk_temp <= NOT clk_temp;
            WAIT FOR 5ns;
        END LOOP;
    END PROCESS;
    clk_top <= clk_temp; -- 1.6 MHz

    tb : PROCESS
    BEGIN
        ------- reset assertion
        reset <= '1';
        WAIT FOR 105 ns;
        reset <= '0';

        -------- Master inputs
        command_valid_in <= '1';
        command_in       <= "1000001100000011"; -- write transaction command
        WAIT FOR 10 ns;
        data_valid_in    <= '1';
        data_in          <= "1010101010101111"; -- Data 1
        command_valid_in <= '1';
        command_in       <= "0000001100000011"; -- Read transaction command
        WAIT FOR 10 ns;
        command_valid_in <= '0';
        data_valid_in    <= '1';
        data_in          <= "1010101010111111"; -- Data 2
        WAIT FOR 10 ns;
        data_in <= "1010101010111001"; -- Data 3
        WAIT FOR 10 ns;
        data_valid_in <= '0';

        WAIT FOR 1000 ns; -- wait for write transaction

        -------- Slave inputs
        data_valid_in_S <= '1';
        data_in_S       <= "1010101010101111";
        WAIT FOR 2000ns;
        data_in_S <= "1010101010101001";

        WAIT; -- will wait forever
    END PROCESS;

END;