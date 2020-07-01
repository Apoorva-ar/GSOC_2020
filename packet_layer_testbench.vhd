
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY packet_layer_Master_tb IS
END packet_layer_Master_tb;

ARCHITECTURE behavior OF packet_layer_Master_tb IS

    COMPONENT packet_layer_Master
        PORT (
            clk_top          : IN std_logic;
            reset            : IN std_logic;
            command_in       : IN std_logic_vector(15 DOWNTO 0);
            command_valid_in : IN std_logic;
            data_in          : IN std_logic_vector(15 DOWNTO 0);
            data_valid_in    : IN std_logic;
            LVDS_IO          : INOUT std_logic;
            LVDS_clock       : OUT std_logic;
            data_in_ready    : OUT std_logic;
            data_out         : OUT std_logic_vector(15 DOWNTO 0);
            data_valid_out   : OUT std_logic;
            test_1           : OUT std_logic;
            test_2           : OUT std_logic_vector(3 DOWNTO 0);
            test_3           : OUT std_logic;
            test_4           : OUT std_logic_vector(15 DOWNTO 0);
            b_length_test    : OUT std_logic_vector(6 DOWNTO 0);
            tr_type_test     : OUT std_logic
        );
    END COMPONENT;
    SIGNAL b_length_test    : std_logic_vector(6 DOWNTO 0);
    SIGNAL tr_type_test     : std_logic;
    SIGNAL clk_top          : std_logic;
    SIGNAL reset            : std_logic;
    SIGNAL command_in       : std_logic_vector(15 DOWNTO 0);
    SIGNAL command_valid_in : std_logic;
    SIGNAL LVDS_IO          : std_logic;
    SIGNAL LVDS_clock       : std_logic;
    SIGNAL data_in          : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_valid_in    : std_logic;
    SIGNAL data_in_ready    : std_logic;
    SIGNAL data_out         : std_logic_vector(15 DOWNTO 0);
    SIGNAL data_valid_out   : std_logic;
    SIGNAL tx_ready         : std_logic;
    SIGNAL master_state     : std_logic_vector(3 DOWNTO 0);
    SIGNAL test_3           : std_logic;
    SIGNAL test_4           : std_logic_vector(15 DOWNTO 0);
    SIGNAL clk_temp         : std_logic;

BEGIN

    -- Please check and add your generic clause manually
    uut : packet_layer_Master PORT MAP(
        b_length_test    => b_length_test,
        tr_type_test     => tr_type_test,
        clk_top          => clk_top,
        reset            => reset,
        command_in       => command_in,
        command_valid_in => command_valid_in,
        LVDS_IO          => LVDS_IO,
        LVDS_clock       => LVDS_clock,
        data_in          => data_in,
        data_valid_in    => data_valid_in,
        data_in_ready    => data_in_ready,
        data_out         => data_out,
        data_valid_out   => data_valid_out,
        test_1           => tx_ready,
        test_2           => master_state,
        test_3           => test_3,
        test_4           => test_4
    );

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
    clk_top <= clk_temp; -- 1.6 MHz

    tb : PROCESS
    BEGIN
        ------- reset assertion
        reset <= '1';
        WAIT FOR 100 ns;
        reset <= '0';

        command_valid_in <= '1';
        command_in       <= "1000001100000011";
        WAIT FOR 200 ns;
        command_valid_in <= '0';

        data_valid_in <= '1';
        data_in       <= "1010101010101111";

        WAIT FOR 20000 ns;
        command_valid_in <= '1';
        command_in       <= "0000001100000011";
        WAIT FOR 200 ns;
        command_valid_in <= '0';
        WAIT; -- will wait forever
    END PROCESS;
END;