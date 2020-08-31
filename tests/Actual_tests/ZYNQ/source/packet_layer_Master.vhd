-- Command tells burst length and write/read transaction and address
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_signed.all;

entity packet_layer_Master is
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
        LVDS_I    : in std_logic;
        LVDS_O    : out std_logic;        
        LVDS_clock : out std_logic;
        LVDS_tristate   : out std_logic;
        ------- Address channel
        -- address_in        : IN std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_in  : IN std_logic;
        -- address_out       : OUT std_logic_vector(ADDRESS_LEN - 1 DOWNTO 0);
        -- address_valid_out : OUT std_logic;
        ------- Data channel
        data_in        : in std_logic_vector(DATA_LEN - 1 downto 0);
        data_valid_in  : in std_logic;
        data_in_ready  : out std_logic; -- logic is missing
        data_out       : out std_logic_vector(DATA_LEN - 1 downto 0);
        data_valid_out : out std_logic;
        ------------- Test Intefaces --------------
        test_1        : out std_logic;
        test_2        : out std_logic_vector(3 downto 0);
        test_3        : out std_logic;
        test_4        : out std_logic_vector(15 downto 0);
        b_length_test : out std_logic_vector(6 downto 0);
        tr_type_test  : out std_logic
    );
end packet_layer_Master;

architecture behavioral of packet_layer_Master is
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Declaration  -----------------------------------
    ----------------------------------------------------------------------------------------

    component PHY_controller is
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
            LVDS_I_debug : in std_logic;
            LVDS_O_debug : out std_logic;
            sclk_debug    : out std_logic;
            trstate_debug : out std_logic;
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

    ----------------------------------------------------------------------------------------
    ----------------------------- System Signals -------------------------------------------
    ----------------------------------------------------------------------------------------

    type state_S is(IDLE, transmit_command_state, tx_transmit, parse_command_state, tx_state_count, rx_state);
    signal state_transaction  : state_S := IDLE;
    signal transaction_type   : std_logic; -- write/read transaction
    signal burst_length       : std_logic_vector(6 downto 0);
    signal data_valid_in_PHY  : std_logic;
    signal data_in_PHY        : std_logic_vector(DATA_LEN - 1 downto 0);
    signal data_valid_out_PHY : std_logic;
    signal data_out_PHY       : std_logic_vector(DATA_LEN - 1 downto 0);
    signal wr_tr_en_PHY       : std_logic;
    signal rd_tr_en_PHY       : std_logic;
    signal PHY_tx_ready       : std_logic;

begin
    b_length_test <= burst_length;
    tr_type_test  <= transaction_type;
    ----------------------------------------------------------------------------------------
    ----------------------------- Component Instantiation  ---------------------------------
    ----------------------------------------------------------------------------------------

    PHY_Master_controller_COMPONENT : PHY_controller
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
        LVDS_I_debug  => LVDS_I,
        LVDS_O_debug  => LVDS_O,
        sclk_debug    => LVDS_clock,
        trstate_debug => LVDS_tristate,
        data_in       => data_in_PHY,
        valid_in      => data_valid_in_PHY,
        write_enable  => wr_tr_en_PHY,
        write_ready   => PHY_tx_ready,
        data_out      => data_out_PHY,
        valid_out     => data_valid_out_PHY,
        read_enable   => rd_tr_en_PHY,
        test_2        => test_4(3 downto 0)
    );
    test_1 <= data_valid_out_PHY;
    test_3 <= rd_tr_en_PHY;
    -----------------------------------------------------------------------
    ---------------------  Master User FSM -----------------------------
    -----------------------------------------------------------------------
    PACKET_MASTER_USER_FSM : process (clk_top, reset)
        variable cntr_burst : std_logic_vector(6 downto 0) := "0000000";
    begin
        if reset = '1' then -- async reset
            test_2            <= "0000";
            state_transaction <= IDLE;
            wr_tr_en_PHY      <= '0';
            rd_tr_en_PHY      <= '0';
            data_in_PHY       <= (others => '0');
            data_valid_in_PHY <= '0';
            transaction_type  <= '0';
            burst_length      <= (others => '0');
            data_out          <= (others => '0');
            data_valid_out    <= '0';
            data_in_ready     <= '1'; -- READY flag for the Source 
            cntr_burst := (others => '0');

        elsif rising_edge(clk_top) then
            case state_transaction is
                when IDLE =>
                    test_2       <= "0000";
                    wr_tr_en_PHY <= '0';
                    rd_tr_en_PHY <= '0';
                    if PHY_tx_ready = '1' then     -- if SPI is ready to accept new data from User
                        data_in_ready <= '1';          -- raise the sink ready flag
                        if command_valid_in = '1' then -- valid data available from Source
                            data_in_ready <= '0';          -- ack
                            ----------------------- transmit command packet
                            state_transaction <= transmit_command_state;
                            wr_tr_en_PHY      <= '1';        -- write transaction enable for master PHY controller
                            data_in_PHY       <= command_in; -- latch in command packet to PHY tx
                            data_valid_in_PHY <= '1';
                        else
                            wr_tr_en_PHY      <= '0'; -- write transaction disable for master PHY controller
                            data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                        end if;
                    else
                        data_in_ready <= '0'; -- lower the sink ready flag
                    end if;
                when transmit_command_state =>
                    data_in_ready     <= '0'; -- lower the sink ready flag
                    test_2            <= "0001";
                    wr_tr_en_PHY      <= '0';
                    state_transaction <= parse_command_state;
                    -------- parse command state
                when parse_command_state =>
                    test_2 <= "0010";
                    if PHY_tx_ready = '1' then -- if controller is ready to accept new data
                        data_valid_in_PHY <= '0';
                        if command_in(COMMAND_LEN - 1) = '1' then -- parse command MSB
                            state_transaction <= tx_state_count;
                        else
                            state_transaction <= rx_state;
                        end if;
                    end if;
                    ---------- record address and burst length
                    transaction_type <= command_in(COMMAND_LEN - 1);
                    burst_length     <= command_in((COMMAND_LEN - 2) downto (COMMAND_LEN - 8));
                    ----------------------- Write transaction state
                    -- add tx ready logic here
                when tx_state_count =>
                    test_2       <= "0011";
                    rd_tr_en_PHY <= '0'; -- read transaction disable for master PHY controller
                    if PHY_tx_ready = '1' then
                        data_in_ready <= '1';         -- raise the sink ready flag
                        if data_valid_in = '1' then   -- if controller is ready to accept new data
                            data_in_ready     <= '0';     -- lower the sink ready flag
                            wr_tr_en_PHY      <= '1';     -- write transaction enable for master PHY controller
                            data_in_PHY       <= data_in; -- latch in new data
                            data_valid_in_PHY <= '1';     -- raise the vallid input data flag for PHY controller
                            state_transaction <= tx_transmit;
                        else
                            wr_tr_en_PHY      <= '0'; -- write transaction disable for master PHY controller
                            data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                        end if;
                    else
                        data_in_ready     <= '0'; -- lower the sink ready flag
                        wr_tr_en_PHY      <= '0'; -- write transaction disable for master PHY controller
                        data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    end if;
                when tx_transmit =>
                    data_in_ready     <= '0'; -- lower the sink ready flag
                    wr_tr_en_PHY      <= '0'; -- write transaction disable for master PHY controller
                    data_valid_in_PHY <= '0'; -- lower the vallid input data flag for PHY controller
                    test_2            <= "0100";
                    if cntr_burst = (burst_length - 1) then -- if burst length is equaal to byte counter
                        cntr_burst := (others => '0');          -- reset the byte counter
                        state_transaction <= IDLE;
                    else
                        cntr_burst := cntr_burst + 1; -- increment byte counter on every sucessful write transaction 
                        state_transaction <= tx_state_count;
                    end if;
                    ----------------------- Read transaction state
                when rx_State =>
                    test_2       <= "0101";
                    wr_tr_en_PHY <= '0';                  -- write transaction disable for master PHY controller
                    if data_valid_out_PHY = '1' then      -- if PHY controller has new valid data 
                        if cntr_burst = burst_length - 1 then -- if burst length is equaal to byte counter
                            cntr_burst := (others => '0');        -- reset the byte counter
                            data_out          <= data_out_PHY;    -- latch out new data
                            data_valid_out    <= '1';             -- raise the valid output data flag 
                            state_transaction <= IDLE;
                            rd_tr_en_PHY      <= '0'; -- read transaction enable for master PHY controller
                        else
                            cntr_burst := cntr_burst + 1;   -- increment byte counter on every sucessful write transaction 
                            data_out       <= data_out_PHY; -- latch out new data
                            data_valid_out <= '1';          -- raise the valid output data flag 
                            rd_tr_en_PHY   <= '1';          -- read transaction enable for master PHY controller
                        end if;
                    else
                        data_valid_out <= '0'; -- lower the vallid output data flag 
                        rd_tr_en_PHY   <= '1';
                    end if;
            end case;
        end if;
    end process;

end behavioral;