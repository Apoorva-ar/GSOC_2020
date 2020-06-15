
-- VHDL Test Bench Created from source file PHY_controller.vhd 

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY PHY_master_tb IS
END PHY_master_tb;

ARCHITECTURE behavior OF PHY_master_tb IS

	COMPONENT PHY_controller
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

	SIGNAL clk_sys              : std_logic;
	SIGNAL clk_sample           : std_logic;
	SIGNAL reset_top            : std_logic;
	SIGNAL LVDS_IO_debug        : std_logic;
	SIGNAL sclk_debug           : std_logic;
	SIGNAL data_in              : std_logic_vector(15 DOWNTO 0);
	SIGNAL valid_in             : std_logic;
	SIGNAL write_enable         : std_logic;
	SIGNAL write_ready          : std_logic;
	SIGNAL data_out             : std_logic_vector(15 DOWNTO 0);
	SIGNAL valid_out            : std_logic;
	SIGNAL read_enable          : std_logic;
	SIGNAL test_1               : std_logic;
	SIGNAL test_2               : std_logic_vector(3 DOWNTO 0);
	SIGNAL test_3               : std_logic;
	SIGNAL test_4               : std_logic_vector(15 DOWNTO 0);
	CONSTANT TIME_PERIOD_CLK    : TIME := 10 ns;
	SIGNAL clk_temp             : std_logic;
	SIGNAL data_out_slave       : std_logic_vector(15 DOWNTO 0);
	SIGNAL valid_data_slave_out : std_logic;
	SIGNAL data_slave_write     : std_logic_vector (15 DOWNTO 0) := "0000100010111101";
	SIGNAL slave_read_enable    : std_logic;
	SIGNAL slave_write_enable   : std_logic;
	SIGNAL data_slave_write_out : std_logic_vector(15 DOWNTO 0);
BEGIN

	-- Unit under test instantiation
	uut : PHY_controller PORT MAP(
		clk_sys       => clk_sys,
		clk_sample    => clk_sample,
		reset_top     => reset_top,
		LVDS_IO_debug => LVDS_IO_debug,
		sclk_debug    => sclk_debug,
		data_in       => data_in,
		valid_in      => valid_in,
		write_enable  => write_enable,
		write_ready   => write_ready,
		data_out      => data_out,
		valid_out     => valid_out,
		read_enable   => read_enable,
		test_1        => test_1,
		test_2        => test_2,
		test_3        => test_3,
		test_4        => test_4
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
	clk_sys <= clk_temp; -- 1.6 MHz

	-------------------------------------------------------------------------
	------------------------ Testbench main process -------------------------
	-------------------------------------------------------------------------
	tb : PROCESS
	BEGIN
		------- reset assertion
		reset_top <= '1';
		WAIT FOR 100 ns;
		------ Write data to the master controller	
		reset_top    <= '0';
		write_enable <= '0';
		valid_in     <= '1';                -- assert valid data flag to latch in data 
		data_in      <= "0001000000001111"; -- new valid data 
		WAIT FOR 10ns;
		valid_in <= '1';
		data_in  <= "0001000100001111";
		WAIT FOR 50 ns;

		slave_read_enable <= '1'; -- enable slave emulator for read transaction
		write_enable      <= '1'; -- enable master write transaction
		valid_in          <= '0';
		WAIT FOR 150 ns;
		write_enable <= '0';
		valid_in     <= '0';

		WAIT FOR 20000 ns;
		slave_read_enable <= '0';
		WAIT FOR 200 ns;
		------ Read data from the LVSD line 
		slave_write_enable <= '1'; -- enable slave emulator for read transaction
		read_enable        <= '1'; -- enable master write transaction

		WAIT FOR 150 ns;
		read_enable <= '0'; -- enable master write transaction

		WAIT FOR 20000 ns;
		slave_write_enable <= '0'; -- enable slave emulator for read transaction
		WAIT;                      -- will wait forever 
	END PROCESS;

	-------------------------------------------------------------------------
	------------------------ Slave read process -----------------------------
	-------------------------------------------------------------------------

	------------- Deserializer
	slave_read_emulator : PROCESS (sclk_debug, LVDS_IO_debug)
		VARIABLE cntr : INTEGER RANGE 0 TO 15 := 0;
	BEGIN
		IF reset_top = '1' THEN
			data_out_slave       <= (OTHERS => '0');
			valid_data_slave_out <= '0';
		ELSE
			IF slave_read_enable = '1' THEN
				IF falling_edge(sclk_debug) THEN
					IF cntr = 15 THEN
						data_out_slave       <= data_out_slave (14 DOWNTO 0) & LVDS_IO_debug;
						valid_data_slave_out <= '1';
						cntr := 0;
					ELSE
						data_out_slave       <= data_out_slave (14 DOWNTO 0) & LVDS_IO_debug;
						valid_data_slave_out <= '0';
						cntr := cntr + 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	-------------------------------------------------------------------------
	------------------------ Slave write process ----------------------------
	-------------------------------------------------------------------------
	slave_write_emulator : PROCESS (sclk_debug, LVDS_IO_debug)
		VARIABLE cntr : INTEGER RANGE 0 TO 15 := 15;
	BEGIN
		IF reset_top = '1' THEN
			LVDS_IO_debug <= 'Z';
		ELSE
			IF slave_write_enable = '1' THEN
				IF rising_edge(sclk_debug) THEN
					IF cntr = 0 THEN
						LVDS_IO_debug <= data_slave_write(cntr);
						cntr := 15;
					ELSE
						LVDS_IO_debug <= data_slave_write(cntr);
						cntr := cntr - 1;
					END IF;
				END IF;
			ELSE
				LVDS_IO_debug <= 'Z';
			END IF;
		END IF;
	END PROCESS;
END;