entity PHY_slave_controller is
    generic (
        Data_Length : integer   := 16;
        CPOL        : std_logic := '0';
        CPHA        : std_logic := '1'
    );
    port (
        -------------- System Interfaces ---------
        clk_sys     : in std_logic;
        reset       : in std_logic;
        data_in     : in std_logic_vector(Data_Length - 1 downto 0);
        valid_in    : in std_logic;
        data_out    : out std_logic_vector(Data_Length - 1 downto 0);
        valid_out   : out std_logic;
        write_tr_en : in std_logic;
        read_tr_en  : in std_logic
    );
end PHY_slave_controller;
architecture behavioral of PHY_slave_controller is

    component PHY_slave is
        generic (
            DATA_SIZE : natural := 16);
        port (
            i_sys_clk   : in std_logic;                                 -- system clock
            i_sys_rst   : in std_logic;                                 -- system reset
            i_csn       : in std_logic;                                 -- Slave Enable/select
            i_data      : in std_logic_vector(DATA_SIZE - 1 downto 0);  -- Input data
            i_wr        : in std_logic;                                 -- Active Low Write, Active High Read
            i_rd        : in std_logic;                                 -- Active Low Write, Active High Read
            o_data      : out std_logic_vector(DATA_SIZE - 1 downto 0); --output data
            o_tx_ready  : out std_logic;                                -- Transmitter ready, can write another 
            o_rx_ready  : out std_logic;                                -- Receiver ready, can read data
            o_tx_error  : out std_logic;                                -- Transmitter error
            o_rx_error  : out std_logic;                                -- Receiver error
            i_cpol      : in std_logic;                                 -- CPOL value - 0 or 1
            i_cpha      : in std_logic;                                 -- CPHA value - 0 or 1 
            i_lsb_first : in std_logic;                                 -- lsb first when '1' /msb first when -- '0'
            LVDS_IO     : inout std_logic;
            i_ssn       : in std_logic_vector(1 downto 0); -- Slave Slect Active low
            i_sclk      : in std_logic;                    -- Clock from SPI Master
            miso_tri_en : out std_logic;
            o_tx_ack    : out std_logic;
            o_tx_no_ack : out std_logic
        );
    end component;

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------
    signal data_valid_received : std_logic                                  := '0';
    signal fifo_data_request   : std_logic                                  := '0';
    signal tx_ready_S          : STD_LOGIC                                  := '0';
    signal rx_ready_S          : STD_LOGIC                                  := '0';
    signal tx_error_S          : STD_LOGIC                                  := '0';
    signal interrupt           : STD_LOGIC                                  := '0';
    signal wait_count          : std_logic_vector(9 downto 0)               := (others => '0');
    signal PHY_transaction_en  : std_logic_vector(1 downto 0)               := (others => '0');
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
    type state_S_2 is(IDLE, Write_transaction_latch, Write_transaction_tx, Read_transaction_latch, Read_transaction_tx);
    signal state_transaction : state_S_2                                  := counter_state;
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

    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    ---------------------------------------------------------------------------
    PHY_Slave_COMPONENT : PHY_slave
    generic map(
        DATA_SIZE => Data_Length)
    port map(
        i_sys_clk   => clk_sys,     -- system high speed clock 
        i_sys_rst   => reset_top,   -- system reset
        i_csn       => chip_select, -- chip select for PHY Slave
        i_data      => PHY_data_in, -- input data
        i_ssn       => PHY_transaction_en,
        i_wr        => write_valid_data, -- Active High (my observation)
        i_rd        => read_valid_data,  -- Active High (my observation)
        o_tx_ready  => tx_ready_S,       -- Transmitter ready, can write another 
        o_rx_ready  => rx_ready_S,       -- receive ready
        o_data      => PHY_data_out,     -- receive data
        o_tx_error  => tx_error_S,       -- Transmitter error
        i_cpol      => CPOL,             -- CPOL value - 0 or 1
        i_cpha      => CPHA,             -- CPHA value - 0 or 1 
        i_lsb_first => '0',              -- lsb first when '1' /msb first when '0'
        LVDS_IO     => LVDS_IO_debug,    -- LVDS serial IO
        i_sclk      => sclk_debug        -- Master clock
    );

    -----------------------------------------------------------------------
    --------------------- SPI Master User FSM -----------------------------
    -----------------------------------------------------------------------
    PHY_Slave_USER_FSM : process (clk_sys, reset_top)
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
                    if write_tr_en = '1' then
                        state_transaction <= Write_transaction_latch;
                    elsif read_tr_en = '1' then
                        state_transaction <= Read_transaction_rx;
                    else
                        state_transaction <= IDLE;
                    end if;

                when Write_transaction_latch =>
                    if valid_in = '1' then
                        PHY_transaction_en <= "10";
                        write_valid_data   <= '1';
                        PHY_data_in        <= data_in;
                        state_transaction  <= Write_transaction_tx;
                    end if;

                when Write_transaction_tx =>
                    write_valid_data <= '0';
                    if tx_ready_S = '1' then
                        PHY_transaction_en <= "11";
                        state_transaction  <= IDLE;
                    end if;

                when Read_transaction_rx =>
                    PHY_transaction_en <= "01";
                    state_transaction  <= Read_transaction_latch;

                when Read_transaction_latch =>
                    read_valid_data <= '1';
                    if rx_ready_S = '1' then
                        PHY_transaction_en <= "11";
                        data_out           <= PHY_data_out;
                        valid_out          <= '1';
                        state_transaction  <= IDLE;
                    end if;
            end case;
        end if;
    end process;
end behavioral;