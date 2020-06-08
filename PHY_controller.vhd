
-- (MASTER LVDS_SERDES with FIFO buffer)

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_signed.ALL;

ENTITY PHY_controller IS
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
        TX2TX_CYCLES      : std_logic_vector(7 DOWNTO 0) := "00000010"
    );
    PORT (
        -------------- System Interfaces ---------
        clk_sys, clk_sample, reset_top : IN STD_LOGIC;
        ------------- PHY Interfaces -------------
        LVDS_IO_debug : INOUT std_logic;
        sclk_debug    : OUT std_logic;
        ------------- DATA IO channel ------------
        data_in      : IN std_logic(WORD_SIZE - 1 DOWNTO 0);
        valid_in     : IN std_logic;
        write_enable : IN std_logic;
        write_ready  : OUT std_logic;
        data_out     : OUT std_logic(WORD_SIZE - 1 DOWNTO 0);
        valid_out    : OUT std_logic;
        read_enable  : IN std_logic;
        ------------- Test Intefaces --------------
        test_1 : OUT std_logic;
        test_2 : OUT std_logic_vector(3 DOWNTO 0);
        test_3 : OUT std_logic;
        test_4 : OUT std_logic_vector(15 DOWNTO 0)
    );
END PHY_controller;

ARCHITECTURE behavioral OF PHY_controller IS
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    COMPONENT PHY_master IS
        GENERIC (
            DATA_SIZE : INTEGER := 32;
            FIFO_REQ  : BOOLEAN := True);
        PORT (
            i_sys_clk : IN std_logic; -- system clock
            i_sys_rst : IN std_logic; -- system reset

            i_data : IN std_logic_vector(DATA_SIZE - 1 DOWNTO 0);  -- Input data
            o_data : OUT std_logic_vector(DATA_SIZE - 1 DOWNTO 0); --output data

            i_csn : IN std_logic; -- chip select for PHY master transaction Data IO
            i_wr  : IN std_logic; -- Active Low Write, Active High Read
            i_rd  : IN std_logic; -- Active Low Write, Active High Read

            o_tx_ready : OUT std_logic; -- Transmitter ready, can write another data
            o_rx_ready : OUT std_logic; -- Receiver ready, can read data

            o_tx_error : OUT std_logic; -- Transmitter error
            o_rx_error : OUT std_logic; -- Receiver error
            o_intr     : OUT std_logic;

            i_cpol         : IN std_logic;                    -- CPOL value - 0 or 1
            i_cpha         : IN std_logic;                    -- CPHA value - 0 or 1 
            i_lsb_first    : IN std_logic;                    -- lsb first when '1' /msb first when 
            i_PHY_start    : IN std_logic;                    -- START PHY Master Transactions
            i_clk_period   : IN std_logic_vector(7 DOWNTO 0); -- SCL clock period in terms of i_sys_clk
            i_setup_cycles : IN std_logic_vector(7 DOWNTO 0); --  setup time  in terms of i_sys_clk
            i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0); --  hold time  in terms of i_sys_clk
            i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0); --  interval between data transactions in terms of i_sys_clk

            PHY_M_IO    : INOUT std_logic; -- LVDS bidirectional data link
            o_sclk      : OUT std_logic;   -- Master clock
            mosi_tri_en : OUT std_logic
        );
    END COMPONENT;

    COMPONENT FIFOx64
        PORT (
            Data        : IN std_logic_vector(47 DOWNTO 0);
            WrClock     : IN std_logic;
            RdClock     : IN std_logic;
            WrEn        : IN std_logic;
            RdEn        : IN std_logic;
            Reset       : IN std_logic;
            RPReset     : IN std_logic;
            Q           : OUT std_logic_vector(47 DOWNTO 0);
            Empty       : OUT std_logic;
            Full        : OUT std_logic;
            AlmostEmpty : OUT std_logic;
            AlmostFull  : OUT std_logic
        );
    END COMPONENT;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
    SIGNAL data_valid_recieved : std_logic                                := '0';
    SIGNAL fifo_data_request   : std_logic                                := '0';
    SIGNAL tx_ready_M          : STD_LOGIC                                := '0';
    SIGNAL tx_error_M          : STD_LOGIC                                := '0';
    SIGNAL interrupt           : STD_LOGIC                                := '0';
    SIGNAL wait_count          : std_logic_vector(9 DOWNTO 0)             := (OTHERS => '0');
    SIGNAL intr_data_wait      : std_logic                                := '0';
    SIGNAL intr_word_wait      : std_logic                                := '0';
    SIGNAL setup_word_wait     : std_logic                                := '0';
    SIGNAL request_word        : std_logic                                := '0';
    SIGNAL valid_data          : std_logic                                := '0';
    SIGNAL master_cs           : std_logic                                := '0';
    SIGNAL data_valid          : std_logic                                := '0';
    SIGNAL chip_select         : std_logic                                := '0';
    SIGNAL start_trans         : std_logic                                := '0';
    SIGNAL start_wait_counter  : std_logic                                := '0';
    SIGNAL slave_CS            : std_logic_vector(3 DOWNTO 0)             := (OTHERS => '0');
    SIGNAL word_reg            : std_logic_vector(WORD_SIZE - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DATA_Valid_SPI_M_I  : std_logic                                := '0';
    TYPE state_S IS(IDLE, TX_WAIT, LATCH_WORD, LATCH_D1, TRANSMIT_D1, wait_transmission_D1,END_TRANSACTION, SETUP_WORD, RX_transaction, WAIT_RX_D1,RX_latch_state );
    SIGNAL state_transaction : state_S := IDLE;
    TYPE state_S_2 IS(IDLE, counter_state, WAIT_empty_state);
    SIGNAL state_FIFO        : state_S_2                                  := counter_state;
    SIGNAL CSN_SPI_M         : std_logic                                  := '0';
    SIGNAL Start_SPI_M       : std_logic                                  := '0';
    SIGNAL Data_SPI_M_I      : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SPI_data_in       : std_logic_vector(Data_Length - 1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL data_out_fifo     : std_logic_vector(47 DOWNTO 0)              := (OTHERS => '0');
    SIGNAL FIFO_data_out     : std_logic_vector(47 DOWNTO 0)              := (OTHERS => '0');
    SIGNAL SPI_M_CS          : std_logic                                  := '1'; -- SPI slave chip select
    SIGNAL data_in_fifo      : std_logic_vector(47 DOWNTO 0)              := (OTHERS => '0');
    SIGNAL FIFO_empty_signal : std_logic                                  := '0';
    SIGNAL FIFO_almost_empty : std_logic                                  := '0';
    SIGNAL FIFO_almost_full  : std_logic                                  := '0';
    SIGNAL full_fifo         : std_logic                                  := '0';
    SIGNAL valid_fifo_in     : std_logic                                  := '0';
    SIGNAL temp              : std_logic_vector(47 DOWNTO 0);
    SIGNAL valid_temp        : std_logic := '0';
BEGIN

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    USER_FIFO_block : FIFOx64
    PORT MAP(
        Data        => data_in_fifo,
        WrClock     => clk_sample, --clk_sys,
        RdClock     => clk_sys,
        WrEn        => valid_fifo_in,
        RdEn        => fifo_data_request,
        Reset       => reset_top,
        RPReset     => reset_top,
        Q           => data_out_fifo,
        Empty       => FIFO_empty_signal,
        AlmostEmpty => FIFO_almost_empty,
        AlmostFull  => FIFO_almost_full,
        Full        => full_fifo
    );

    data_in_fifo      <= data_in;
    valid_fifo_in     <= valid_in;
    fifo_data_request <= request_word;
    FIFO_data_out     <= data_out_fifo;

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    PHY_Master_COMPONENT : PHY_master
    GENERIC MAP(
        DATA_SIZE => Data_Length,
        FIFO_REQ  => False)
    PORT MAP(
        i_sys_clk      => clk_sys,          -- system high speed clock 
        i_sys_rst      => reset_top,        -- system reset
        i_csn          => chip_select,      -- chip select for SPI master
        i_data         => PHY_data_in,      -- input data
        i_wr           => write_valid_data, -- Active High (my observation)
        i_rd           => read_valid_data,  -- Active High (my observation)
        o_tx_ready     => tx_ready_M,       -- Transmitter ready, can write another 
        o_rx_ready     => rx_ready_M,       -- receive ready
        o_data         => M_data_out,       -- receive data
        o_tx_error     => tx_error_M,       -- Transmitter error
        o_intr         => interrupt,        -- interrupt
        i_slave_addr   => "00",             -- Slave Address
        i_cpol         => CPOL,             -- CPOL value - 0 or 1
        i_cpha         => CPHA,             -- CPHA value - 0 or 1 
        i_lsb_first    => '0',              -- lsb first when '1' /msb first when '0'
        i_spi_start    => start_trans,      -- START PHY Master Transactions
        i_clk_period   => CLK_PERIOD,       -- SCL clock period in terms of i_sys_clk
        i_setup_cycles => SETUP_CYCLES,     -- PHY_M tx setup time  in terms of i_sys_clk
        i_hold_cycles  => HOLD_CYCLES,      -- PHY_M tx hold time  in terms of i_sys_clk
        i_tx2tx_cycles => TX2TX_CYCLES,     -- PHY_M tx interval between data transactions in terms of i_sys_clk
        PHY_M_IO       => LVDS_IO_debug,    -- LVDS serial IO
        o_sclk         => sclk_debug        -- Master clock
    );

    -----------------------------------------------------------------------
    --------------------- SPI Master User FSM -----------------------------
    -----------------------------------------------------------------------
    SPI_MASTER_USER_FSM : PROCESS (clk_sys, reset_top)
    BEGIN
        IF reset_top = '1' THEN
            state_transaction   <= IDLE;
            request_word        <= '0'; -- read enable to FIFO
            data_valid_recieved <= '0';
            write_valid_data    <= '0'; -- data valid flag to SMI_M
            chip_select         <= '1'; -- master chip select flag to PHY_M
            start_trans         <= '0'; -- start SPI transaction flag
            start_wait_counter  <= '0';
        ELSIF rising_edge(clk_sys) THEN
            CASE state_transaction IS
                WHEN IDLE =>
                    start_wait_counter  <= '0';
                    request_word        <= '0'; -- read enable to FIFO
                    write_valid_data    <= '0'; -- data valid flag to PHY_M
                    data_valid_recieved <= '0'; -- valid received data
                    chip_select         <= '1'; -- master chip select flag to PHY_M
                    start_trans         <= '0'; -- start SPI transaction flag
                    IF WR_ENABLE = '1' THEN
                        state_transaction <= TX_WAIT;
                    ELSIF RD_ENABLE = '1' THEN
                        state_transaction <= RX_transaction;
                    ELSE
                        state_transaction <= IDLE;
                    END IF;
                    ------------------------ Transmitter ------------------------------------
                WHEN TX_WAIT =>
                    IF FIFO_empty_signal = '0' THEN -- if valid data is available in FIFO
                        state_transaction <= LATCH_WORD;
                    END IF;

                WHEN LATCH_WORD =>
                    request_word       <= '1';        -- demand new word from FIFO
                    start_wait_counter <= '1';        -- start counter for delay before sending first data element
                    state_transaction  <= SETUP_WORD; -- start_transaction;
                    SPI_M_CS           <= '0';        -- start the SPI word transaction, lower the SPI chip select line

                WHEN SETUP_WORD =>
                    request_word <= '0';                                   -- disable the read enable to FIFO
                    word_reg     <= FIFO_data_out(WORD_SIZE - 1 DOWNTO 0); -- latch/register the word from FIFO
                    IF setup_word_wait = '1' THEN                          -- if the wait is equal to the required setup word cycles then change state to latch first element of the word
                        state_transaction  <= LATCH_D1;
                        start_wait_counter <= '0'; -- stop/reset the wait counter
                    END IF;

                WHEN LATCH_D1 =>
                    write_valid_data  <= '1';      -- raise the data_valid flag to SPI_M
                    chip_select       <= '0';      -- lower the master chip select to latch_in a new element
                    PHY_data_in       <= word_reg; -- latch_in new element into input_data register of SPI_M
                    state_transaction <= TRANSMIT_D1;

                WHEN TRANSMIT_D1 =>
                    write_valid_data  <= '0';
                    chip_select       <= '1';
                    start_trans       <= '1'; -- start SPI master transaction
                    state_transaction <= wait_transmission_D1;

                WHEN wait_transmission_D1 =>
                    start_trans       <= '0'; -- reset SPI master transaction
                    state_transaction <= END_TRANSACTION;

                WHEN END_TRANSACTION =>
                    IF tx_ready_M = '1' THEN
                        state_transaction <= IDLE;
                    END IF;
                    ------------------------ Receiver ------------------------------------
                WHEN RX_transaction =>
                    start_trans = '1'-- start master transaction
                    state_transaction <= WAIT_RX_D1;

                WHEN WAIT_RX_D1 =>
                    start_trans <= '0'; -- reset master transaction
                    IF rx_ready_M = '1' THEN
                        state_transaction <= RX_latch_state;
                        chip_select       <= '0';
                        read_valid_data   <= '1';
                    END IF;

                WHEN RX_latch_state
                    chip_select         <= '1';
                    read_valid_data     <= '0';
                    data_received       <= M_data_out; -- latch out valid data
                    data_valid_recieved <= '1';
                    state_transaction   <= IDLE;
            END CASE;
        END IF;
    END PROCESS;
    ------------------------------------------------------------------------------------------------
    ------ Wait Counter used for controlling wait stages between LVDS transactions -----------------
    ------------------ wait counter enabled only when delay_count_start_i = '1' --------------------
    ------------------------------------------------------------------------------------------------
    PROCESS (clk_sys, reset_top)
    BEGIN
        IF reset_top = '1' THEN
            wait_count <= "0000000001";
        ELSIF rising_edge(clk_sys) THEN
            IF start_wait_counter = '0' THEN
                wait_count <= "0000000001";
            ELSE
                wait_count <= wait_count + 1;
            END IF;
        END IF;
    END PROCESS;

    intr_data_wait <= '1' WHEN wait_count = INTER_DATA_CYCLES ELSE
        '0';
    intr_word_wait <= '1' WHEN wait_count = INTER_WORD_CYCLES ELSE
        '0';
    setup_word_wait <= '1' WHEN wait_count = SETUP_WORD_CYCLES ELSE
        '0';

END behavioral;
