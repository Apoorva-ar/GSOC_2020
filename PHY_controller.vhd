-- (MASTER LVDS_SERDES with FIFO buffer)

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

entity PHY_controller is
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
        TX2TX_CYCLES      : std_logic_vector(7 downto 0) := "00000010"
    );
    port (
        -------------- System Interfaces ---------
        clk_sys, clk_sample, reset_top : in STD_LOGIC;
        ------------- PHY Interfaces -------------
        LVDS_IO_debug : inout std_logic;
        sclk_debug    : out std_logic;
        ------------- DATA IO channel ------------
        data_in      : in std_logic_vector(Data_Length - 1 downto 0);
        valid_in     : in std_logic;
        write_enable : in std_logic;
        write_ready  : out std_logic;
        data_out     : out std_logic_vector(Data_Length - 1 downto 0);
        valid_out    : out std_logic;
        read_enable  : in std_logic;
        ------------- Test Intefaces --------------
        test_1 : out std_logic;
        test_2 : out std_logic_vector(3 downto 0);
        test_3 : out std_logic;
        test_4 : out std_logic_vector(15 downto 0)
    );
end PHY_controller;

architecture behavioral of PHY_controller is
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    component PHY_master is
        generic (
            DATA_SIZE : integer := 32;
            FIFO_REQ  : boolean := True);
        port (
            i_sys_clk : in std_logic; -- system clock
            i_sys_rst : in std_logic; -- system reset

            i_data     : in std_logic_vector(Data_Length - 1 downto 0);  -- Input data
            o_data     : out std_logic_vector(Data_Length - 1 downto 0); --output data
            i_wr_tr_en : in std_logic;                                   -- write transaction enable
            i_rd_tr_en : in std_logic;                                   -- read transaction enable
            i_csn      : in std_logic;                                   -- chip select for PHY master transaction Data IO
            i_wr       : in std_logic;                                   -- Active Low Write, Active High Read
            i_rd       : in std_logic;                                   -- Active Low Write, Active High Read

            o_tx_ready : out std_logic; -- Transmitter ready, can write another data
            o_rx_ready : out std_logic; -- Receiver ready, can read data

            o_tx_error : out std_logic; -- Transmitter error
            o_rx_error : out std_logic; -- Receiver error
            o_intr     : out std_logic;

            i_cpol         : in std_logic;                    -- CPOL value - 0 or 1
            i_cpha         : in std_logic;                    -- CPHA value - 0 or 1 
            i_lsb_first    : in std_logic;                    -- lsb first when '1' /msb first when 
            i_PHY_start    : in std_logic;                    -- START PHY Master Transactions
            i_clk_period   : in std_logic_vector(7 downto 0); -- SCL clock period in terms of i_sys_clk
            i_setup_cycles : in std_logic_vector(7 downto 0); --  setup time  in terms of i_sys_clk
            i_hold_cycles  : in std_logic_vector(7 downto 0); --  hold time  in terms of i_sys_clk
            i_tx2tx_cycles : in std_logic_vector(7 downto 0); --  interval between data transactions in terms of i_sys_clk

            PHY_M_IO    : inout std_logic; -- LVDS bidirectional data link
            o_sclk      : out std_logic;   -- Master clock
            mosi_tri_en : out std_logic
        );
    end component;

    component FIFOx64
        port (
            Data        : in std_logic_vector(Data_Length - 1 downto 0);
            WrClock     : in std_logic;
            RdClock     : in std_logic;
            WrEn        : in std_logic;
            RdEn        : in std_logic;
            Reset       : in std_logic;
            RPReset     : in std_logic;
            Q           : out std_logic_vector(Data_Length - 1 downto 0);
            Empty       : out std_logic;
            Full        : out std_logic;
            AlmostEmpty : out std_logic;
            AlmostFull  : out std_logic
        );
    end component;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
    signal data_valid_received : std_logic                                  := '0';
    signal fifo_data_request   : std_logic                                  := '0';
    signal tx_ready_M          : STD_LOGIC                                  := '0';
    signal rx_ready_M          : STD_LOGIC                                  := '0';
    signal tx_error_M          : STD_LOGIC                                  := '0';
    signal interrupt           : STD_LOGIC                                  := '0';
    signal wait_count          : std_logic_vector(9 downto 0)               := (others => '0');
    signal intr_data_wait      : std_logic                                  := '0';
    signal intr_word_wait      : std_logic                                  := '0';
    signal setup_word_wait     : std_logic                                  := '0';
    signal request_word        : std_logic                                  := '0';
    signal valid_data          : std_logic                                  := '0';
    signal master_cs           : std_logic                                  := '0';
    signal data_valid          : std_logic                                  := '0';
    signal chip_select         : std_logic                                  := '0';
    signal start_trans         : std_logic                                  := '0';
    signal start_wait_counter  : std_logic                                  := '0';
    signal slave_CS            : std_logic_vector(3 downto 0)               := (others => '0');
    signal word_reg            : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal DATA_Valid_SPI_M_I  : std_logic                                  := '0';
    type state_S is(IDLE, TX_WAIT, LATCH_WORD, LATCH_D1, TRANSMIT_D1, wait_transmission_D1, END_TRANSACTION, SETUP_WORD, RX_transaction, WAIT_RX_D1, RX_latch_state);
    signal state_transaction : state_S := IDLE;
    type state_S_2 is(IDLE, counter_state, WAIT_empty_state);
    signal state_FIFO        : state_S_2                                  := counter_state;
    signal CSN_SPI_M         : std_logic                                  := '0';
    signal Start_SPI_M       : std_logic                                  := '0';
    signal Data_SPI_M_I      : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal SPI_data_in       : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal data_out_fifo     : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal FIFO_data_out     : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal SPI_M_CS          : std_logic                                  := '1'; -- SPI slave chip select
    signal data_in_fifo      : std_logic_vector(Data_Length - 1 downto 0) := (others => '0');
    signal FIFO_empty_signal : std_logic                                  := '0';
    signal FIFO_almost_empty : std_logic                                  := '0';
    signal FIFO_almost_full  : std_logic                                  := '0';
    signal full_fifo         : std_logic                                  := '0';
    signal valid_fifo_in     : std_logic                                  := '0';
    signal temp              : std_logic_vector(Data_Length - 1 downto 0);
    signal valid_temp        : std_logic := '0';
    signal PHY_data_in       : std_logic_vector(Data_Length - 1 downto 0);
    signal write_valid_data  : std_logic := '0';
    signal read_valid_data   : std_logic := '0';
    signal M_data_out        : std_logic_vector(Data_Length - 1 downto 0);
    signal data_received     : std_logic_vector(Data_Length - 1 downto 0);
begin

    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    USER_FIFO_block : FIFOx64
    port map(
        Data        => data_in_fifo,
        WrClock     => clk_sys,
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
    test_1            <= request_word;
    test_4            <= data_out_fifo;

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    PHY_Master_COMPONENT : PHY_master
    generic map(
        DATA_SIZE => Data_Length,
        FIFO_REQ  => False)
    port map(
        i_sys_clk      => clk_sys,          -- system high speed clock 
        i_sys_rst      => reset_top,        -- system reset
        i_csn          => chip_select,      -- chip select for PHY master
        i_data         => PHY_data_in,      -- input data
        i_wr_tr_en     => write_enable,     -- write transaction enable
        i_rd_tr_en     => read_enable,      -- read transaction enable
        i_wr           => write_valid_data, -- Active High (my observation)
        i_rd           => read_valid_data,  -- Active High (my observation)
        o_tx_ready     => tx_ready_M,       -- Transmitter ready, can write another 
        o_rx_ready     => rx_ready_M,       -- receive ready
        o_data         => M_data_out,       -- receive data
        o_tx_error     => tx_error_M,       -- Transmitter error
        o_intr         => interrupt,        -- interrupt
        i_cpol         => CPOL,             -- CPOL value - 0 or 1
        i_cpha         => CPHA,             -- CPHA value - 0 or 1 
        i_lsb_first    => '0',              -- lsb first when '1' /msb first when '0'
        i_PHY_start    => start_trans,      -- START PHY Master Transactions
        i_clk_period   => CLK_PERIOD,       -- SCL clock period in terms of i_sys_clk
        i_setup_cycles => SETUP_CYCLES,     -- PHY_M tx setup time  in terms of i_sys_clk
        i_hold_cycles  => HOLD_CYCLES,      -- PHY_M tx hold time  in terms of i_sys_clk
        i_tx2tx_cycles => TX2TX_CYCLES,     -- PHY_M tx interval between data transactions in terms of i_sys_clk
        PHY_M_IO       => LVDS_IO_debug,    -- LVDS serial IO
        o_sclk         => sclk_debug        -- Master clock
    );

    data_out  <= data_received;
    valid_out <= data_valid_received;

    -----------------------------------------------------------------------
    --------------------- SPI Master User FSM -----------------------------
    -----------------------------------------------------------------------
    PHY_MASTER_USER_FSM : process (clk_sys, reset_top)
    begin
        if reset_top = '1' then
            state_transaction   <= IDLE;
            request_word        <= '0'; -- read enable to FIFO
            data_valid_received <= '0';
            write_valid_data    <= '0'; -- data valid flag to SMI_M
            chip_select         <= '1'; -- master chip select flag to PHY_M
            start_trans         <= '0'; -- start SPI transaction flag
            start_wait_counter  <= '0';
        elsif rising_edge(clk_sys) then
            case state_transaction is
                when IDLE =>
                    start_wait_counter  <= '0';
                    request_word        <= '0'; -- read enable to FIFO
                    write_valid_data    <= '0'; -- data valid flag to PHY_M
                    data_valid_received <= '0'; -- valid received data
                    chip_select         <= '1'; -- master chip select flag to PHY_M
                    start_trans         <= '0'; -- start SPI transaction flag
                    if write_enable = '1' then
                        state_transaction <= TX_WAIT;
                    elsif read_enable = '1' then
                        state_transaction <= RX_transaction;
                    else
                        state_transaction <= IDLE;
                    end if;
                    ------------------------ Transmitter ------------------------------------
                when TX_WAIT =>
                    if FIFO_empty_signal = '0' then -- if valid data is available in FIFO
                        state_transaction <= LATCH_WORD;
                    end if;

                when LATCH_WORD =>
                    request_word       <= '1';        -- demand new word from FIFO
                    start_wait_counter <= '1';        -- start counter for delay before sending first data element
                    state_transaction  <= SETUP_WORD; -- start_transaction;
                    SPI_M_CS           <= '0';        -- start the SPI word transaction, lower the SPI chip select line

                when SETUP_WORD =>
                    request_word <= '0';                                     -- disable the read enable to FIFO
                    word_reg     <= FIFO_data_out(Data_Length - 1 downto 0); -- latch/register the word from FIFO
                    if setup_word_wait = '1' then                            -- if the wait is equal to the required setup word cycles then change state to latch first element of the word
                        state_transaction  <= LATCH_D1;
                        start_wait_counter <= '0'; -- stop/reset the wait counter
                    end if;

                when LATCH_D1 =>
                    write_valid_data  <= '1';      -- raise the data_valid flag to SPI_M
                    chip_select       <= '0';      -- lower the master chip select to latch_in a new element
                    PHY_data_in       <= word_reg; -- latch_in new element into input_data register of SPI_M
                    state_transaction <= TRANSMIT_D1;

                when TRANSMIT_D1 =>
                    write_valid_data  <= '0';
                    chip_select       <= '1';
                    start_trans       <= '1'; -- start SPI master transaction
                    state_transaction <= wait_transmission_D1;

                when wait_transmission_D1 =>
                    start_trans       <= '0'; -- reset SPI master transaction
                    state_transaction <= END_TRANSACTION;

                when END_TRANSACTION =>
                    if tx_ready_M = '1' then
                        state_transaction <= IDLE;
                    end if;
                    ------------------------ Receiver ------------------------------------
                when RX_transaction =>
                    start_trans       <= '1';-- start master transaction
                    state_transaction <= WAIT_RX_D1;

                when WAIT_RX_D1 =>
                    start_trans <= '0'; -- reset master transaction
                    if rx_ready_M = '1' then
                        state_transaction <= RX_latch_state;
                        chip_select       <= '0';
                        read_valid_data   <= '1'; -- to read valid data from PHY_Master
                    end if;

                when RX_latch_state =>
                    chip_select         <= '1';
                    read_valid_data     <= '0';
                    data_received       <= M_data_out; -- latch out valid data
                    data_valid_received <= '1';        -- valid data signal for user
                    state_transaction   <= IDLE;
            end case;
        end if;
    end process;
    ------------------------------------------------------------------------------------------------
    ------ Wait Counter used for controlling wait stages between LVDS transactions -----------------
    ------------------ wait counter enabled only when delay_count_start_i = '1' --------------------
    ------------------------------------------------------------------------------------------------
    process (clk_sys, reset_top)
    begin
        if reset_top = '1' then
            wait_count <= "0000000001";
        elsif rising_edge(clk_sys) then
            if start_wait_counter = '0' then
                wait_count <= "0000000001";
            else
                wait_count <= wait_count + 1;
            end if;
        end if;
    end process;

    intr_data_wait <= '1' when wait_count = INTER_DATA_CYCLES else
        '0';
    intr_word_wait <= '1' when wait_count = INTER_WORD_CYCLES else
        '0';
    setup_word_wait <= '1' when wait_count = "0000000010" else
        '0';

end behavioral;
