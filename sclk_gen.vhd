
---------------------------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY spi_sclk_gen IS
    GENERIC (
        DATA_SIZE : INTEGER);
    PORT (
        i_sys_clk      : IN std_logic;
        i_sys_rst      : IN std_logic;
        i_spi_start    : IN std_logic;
        i_clk_period   : IN std_logic_vector(7 DOWNTO 0);
        i_setup_cycles : IN std_logic_vector(7 DOWNTO 0);
        i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0);
        i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0);
        i_cpol         : IN std_logic;
        o_ss_start     : OUT std_logic;
        o_sclk         : OUT std_logic
    );
END spi_sclk_gen;

ARCHITECTURE count_arch OF spi_sclk_gen IS

    SIGNAL clk_periodby2_i       : std_logic_vector(7 DOWNTO 0);
    SIGNAL sclk_period_i         : std_logic_vector(7 DOWNTO 0);
    SIGNAL sclk_count_i          : std_logic_vector(7 DOWNTO 0);
    SIGNAL delay_clk_i           : std_logic;
    SIGNAL div_clk_i             : std_logic;
    SIGNAL clk_falling_i         : std_logic;
    SIGNAL clk_rising_i          : std_logic;
    SIGNAL delay_count_start_i   : std_logic;
    SIGNAL tx2tx_delay_done_i    : std_logic;
    SIGNAL hold_delay_done_i     : std_logic;
    SIGNAL setup_delay_done_i    : std_logic;
    SIGNAL delay_count_i         : std_logic_vector(7 DOWNTO 0);
    SIGNAL falling_count_start_i : std_logic;
    SIGNAL clk_falling_count_i   : std_logic_vector(7 DOWNTO 0);
    SIGNAL spi_start_i           : std_logic;
    SIGNAL sclk_count_start_i    : std_logic;

    TYPE spim_clk_states IS (SPIM_IDLE_STATE, SPIM_SETUP_STATE,
        SPIM_DATA_TX_STATE, SPIM_HOLD_STATE, SPIM_TX2TX_WAIT_STATE);
    SIGNAL spim_clk_state_i : spim_clk_states;
BEGIN
    ------------------------------------------------------------------------------------------------
    -- Right shift by 1 to compute divide by 2 of clock period
    ------------------------------------------------------------------------------------------------
    clk_periodby2_i <= '0' & i_clk_period(7 DOWNTO 1);

    ----------------------------------------------------------------------------------------------------
    -- SCLK generation - This a clock divider logic, which is enabled only when slave select is LOW.
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            sclk_count_i <= "00000001";
            div_clk_i    <= '0';
        ELSIF rising_edge(i_sys_clk) THEN
            IF sclk_count_start_i = '1' THEN
                IF sclk_count_i < i_clk_period THEN
                    sclk_count_i <= sclk_count_i + 1;
                ELSE
                    sclk_count_i <= "00000001";
                END IF;
            ELSE
                sclk_count_i <= "00000010";
            END IF;
            IF sclk_count_i > clk_periodby2_i THEN
                div_clk_i <= '0';
            ELSE
                div_clk_i <= '1';
            END IF;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------------------------------
    -- Delayed version of divided clock, used to generate falling/rising edge of generated clock
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            delay_clk_i <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN
            delay_clk_i <= div_clk_i;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------------------------------
    -- spi start registered...without which the FSM doesn't work!
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            spi_start_i <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN
            spi_start_i <= i_spi_start;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------------------------------------------
    -- SCLK derived based on divide by clock period factor and CPOL.
    -- Output clock is generated only in data transaction state.
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            o_sclk <= '0';
        ELSIF i_sys_clk'event AND i_sys_clk = '1' THEN
            IF spim_clk_state_i = SPIM_DATA_TX_STATE THEN
                IF (i_cpol = '0') THEN
                    o_sclk <= div_clk_i;
                ELSE
                    o_sclk <= NOT div_clk_i;
                END IF;
            ELSE
                o_sclk <= i_cpol;
            END IF;
        END IF;
    END PROCESS;

    ----------------------------------------------------------------------------------------------------
    -- FSM, which is heart of SPI master
    -- This enables/disables clock divider, controls output clock, as well as generating chip select
    -- for SPI Slave, controls setup and hold time before and after SCLK, time interval between
    -- two transactions.
    ----------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            spim_clk_state_i      <= SPIM_IDLE_STATE;
            delay_count_start_i   <= '0';
            sclk_count_start_i    <= '0';
            o_ss_start            <= '1';
            falling_count_start_i <= '0';
        ELSIF (rising_edge(i_sys_clk)) THEN
            CASE (spim_clk_state_i) IS
                WHEN SPIM_IDLE_STATE =>
                    IF (spi_start_i = '1') THEN -- registered input
                        spim_clk_state_i    <= SPIM_SETUP_STATE;
                        delay_count_start_i <= '1';
                        o_ss_start          <= '0';
                        sclk_count_start_i  <= '0';
                    ELSE
                        spim_clk_state_i      <= SPIM_IDLE_STATE;
                        delay_count_start_i   <= '0';
                        o_ss_start            <= '1';
                        falling_count_start_i <= '0';
                        sclk_count_start_i    <= '0';
                    END IF;
                WHEN SPIM_SETUP_STATE =>
                    IF (setup_delay_done_i = '1') THEN
                        delay_count_start_i   <= '0';
                        spim_clk_state_i      <= SPIM_DATA_TX_STATE;
                        sclk_count_start_i    <= '1';
                        falling_count_start_i <= '1';
                    ELSE
                        spim_clk_state_i    <= SPIM_SETUP_STATE;
                        delay_count_start_i <= '1';
                    END IF;
                WHEN SPIM_DATA_TX_STATE =>
                    IF (clk_falling_count_i = DATA_SIZE) THEN
                        spim_clk_state_i      <= SPIM_HOLD_STATE;
                        delay_count_start_i   <= '1';
                        falling_count_start_i <= '0';
                    ELSE
                        spim_clk_state_i <= SPIM_DATA_TX_STATE;
                    END IF;
                WHEN SPIM_HOLD_STATE =>
                    IF (hold_delay_done_i = '1') THEN
                        delay_count_start_i <= '0';
                        spim_clk_state_i    <= SPIM_TX2TX_WAIT_STATE;
                        o_ss_start          <= '1';
                        sclk_count_start_i  <= '0';
                    ELSE
                        spim_clk_state_i    <= SPIM_HOLD_STATE;
                        delay_count_start_i <= '1';
                    END IF;
                WHEN SPIM_TX2TX_WAIT_STATE =>
                    IF (tx2tx_delay_done_i = '1') THEN
                        delay_count_start_i <= '0';
                        spim_clk_state_i    <= SPIM_IDLE_STATE;
                    ELSE
                        spim_clk_state_i    <= SPIM_TX2TX_WAIT_STATE;
                        delay_count_start_i <= '1';
                    END IF;
                WHEN OTHERS =>
                    spim_clk_state_i      <= SPIM_IDLE_STATE;
                    delay_count_start_i   <= '0';
                    sclk_count_start_i    <= '0';
                    o_ss_start            <= '1';
                    falling_count_start_i <= '0';
            END CASE;
        END IF;
    END PROCESS;

    ------------------------------------------------------------------------------------------------
    -- Delay Counter used for controlling setup, hold and interval between transactions.
    -- Delay counter enabled only when delay_count_start_i = '1'
    ------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            delay_count_i <= "00000001";
        ELSIF rising_edge(i_sys_clk) THEN
            IF delay_count_start_i = '0' THEN
                delay_count_i <= "00000001";
            ELSE
                delay_count_i <= delay_count_i + 1;
            END IF;
        END IF;
    END PROCESS;
    tx2tx_delay_done_i <= '1' WHEN delay_count_i = i_tx2tx_cycles ELSE
        '0';
    hold_delay_done_i <= '1' WHEN delay_count_i = i_hold_cycles ELSE
        '0';
    setup_delay_done_i <= '1' WHEN delay_count_i = i_setup_cycles ELSE
        '0';

    ------------------------------------------------------------------------------------------------
    -- SCLK falling edge counter - determines number of bytes transmitted per SPI cycle
    ------------------------------------------------------------------------------------------------
    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            clk_falling_count_i <= (OTHERS => '0');
        ELSIF rising_edge(i_sys_clk) THEN
            IF falling_count_start_i = '0' THEN
                clk_falling_count_i <= (OTHERS => '0');
            ELSIF (clk_falling_i = '1') THEN
                clk_falling_count_i <= clk_falling_count_i + 1;
            END IF;
        END IF;
    END PROCESS;
    clk_rising_i <= '1' WHEN div_clk_i = '1' AND delay_clk_i = '0' ELSE
        '0';
    clk_falling_i <= '1' WHEN div_clk_i = '0' AND delay_clk_i = '1' ELSE
        '0';

END count_arch;