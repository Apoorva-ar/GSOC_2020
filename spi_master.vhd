
--   ==================================================================
--   >>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
--   ------------------------------------------------------------------
--   Copyright (c) 2013 by Lattice Semiconductor Corporation
--   ALL RIGHTS RESERVED 
--   ------------------------------------------------------------------
--
--   Permission:
--
--      Lattice SG Pte. Ltd. grants permission to use this code
--      pursuant to the terms of the Lattice Reference Design License Agreement. 
--
--
--   Disclaimer:
--
--      This VHDL or Verilog source code is intended as a design reference
--      which illustrates how these types of functions can be implemented.
--      It is the user's responsibility to verify their design for
--      consistency and functionality through the use of formal
--      verification methods.  Lattice provides no warranty
--      regarding the use or functionality of this code.
--
--   --------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY SPI_Master IS
    GENERIC (
        DATA_SIZE : INTEGER := 16;
        FIFO_REQ  : BOOLEAN := True);
    PORT (
        i_sys_clk  : IN std_logic;                      -- system clock
        i_sys_rst  : IN std_logic;                      -- system reset
        i_csn      : IN std_logic;                      -- chip select for SPI master
        i_data     : IN std_logic_vector(15 DOWNTO 0);  -- Input data
        i_wr       : IN std_logic;                      -- Active Low Write, Active High Read
        i_rd       : IN std_logic;                      -- Active Low Write, Active High Read
        o_data     : OUT std_logic_vector(15 DOWNTO 0); --output data
        o_tx_ready : OUT std_logic;                     -- Transmitter ready, can write another 
        -- data
        o_rx_ready     : OUT std_logic; -- Receiver ready, can read data
        o_tx_error     : OUT std_logic; -- Transmitter error
        o_rx_error     : OUT std_logic; -- Receiver error
        o_intr         : OUT std_logic;
        i_slave_addr   : IN std_logic_vector(1 DOWNTO 0);  -- Slave Address
        i_cpol         : IN std_logic;                     -- CPOL value - 0 or 1
        i_cpha         : IN std_logic;                     -- CPHA value - 0 or 1 
        i_lsb_first    : IN std_logic;                     -- lsb first when '1' /msb first when 
        i_spi_start    : IN std_logic;                     -- START SPI Master Transactions
        i_clk_period   : IN std_logic_vector(7 DOWNTO 0);  -- SCL clock period in terms of i_sys_clk
        i_setup_cycles : IN std_logic_vector(7 DOWNTO 0);  -- SPIM setup time  in terms of i_sys_clk
        i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0);  -- SPIM hold time  in terms of i_sys_clk
        i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0);  -- SPIM interval between data transactions in terms of i_sys_clk
        o_slave_csn    : OUT std_logic_vector(3 DOWNTO 0); -- SPI Slave select (chip select) active low
        o_mosi         : OUT std_logic;                    -- Master output to Slave
        i_miso         : IN std_logic;                     -- Master input from Slave
        o_sclk         : OUT std_logic;                    -- Master clock
        mosi_tri_en    : OUT std_logic
    );
END SPI_Master;

ARCHITECTURE spi_master_rtl OF SPI_Master IS

    COMPONENT spi_sclk_gen
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
    END COMPONENT;

    COMPONENT spi_data_path
        GENERIC (
            DATA_SIZE : INTEGER;
            FIFO_REQ  : BOOLEAN);
        PORT (
            i_sys_clk   : IN std_logic;                         -- system clock
            i_sys_rst   : IN std_logic;                         -- system reset
            i_csn       : IN std_logic;                         -- Master Enable/select
            i_data      : IN std_logic_vector(16 - 1 DOWNTO 0); -- Input data
            i_wr        : IN std_logic;                         -- Active Low Write, Active High Read
            i_rd        : IN std_logic;                         -- Active Low Write, Active High Read
            i_spi_start : IN std_logic;
            o_data      : OUT std_logic_vector(16 - 1 DOWNTO 0); --output data
            o_tx_ready  : OUT std_logic;                         -- Transmitter ready, can write another 
            -- data
            o_rx_ready : OUT std_logic; -- Receiver ready, can read data
            o_tx_error : OUT std_logic; -- Transmitter error
            o_rx_error : OUT std_logic; -- Receiver error

            i_cpol      : IN std_logic; -- CPOL value - 0 or 1
            i_cpha      : IN std_logic; -- CPHA value - 0 or 1 
            i_lsb_first : IN std_logic; -- lsb first when '1' /msb first when 
            -- '0'
            o_intr      : OUT std_logic;
            o_mosi      : OUT std_logic; -- Master output to Slave
            i_miso      : IN std_logic;  -- Master input from Slave
            i_ssn       : IN std_logic;  -- Slave Slect Active low
            i_sclk      : IN std_logic;  -- Clock from SPI Master
            mosi_tri_en : OUT std_logic
        );

    END COMPONENT;

    SIGNAL sclk_i     : std_logic;
    SIGNAL ss_start_i : std_logic;
BEGIN

    o_sclk <= sclk_i;

    PROCESS (i_sys_clk, i_sys_rst)
    BEGIN
        IF i_sys_rst = '1' THEN
            o_slave_csn <= (OTHERS => '1');
        ELSIF rising_edge(i_sys_clk) THEN
            CASE (i_slave_addr) IS
                WHEN "00" =>
                    o_slave_csn <= "111" & ss_start_i;
                WHEN "01" =>
                    o_slave_csn <= "11" & ss_start_i & '1';
                WHEN "10" =>
                    o_slave_csn <= '1' & ss_start_i & "11";
                WHEN "11" =>
                    o_slave_csn <= ss_start_i & "111";
                WHEN OTHERS =>
                    o_slave_csn <= "1111";
            END CASE;
        END IF;
    END PROCESS;

    sclk_gen_u0 : spi_sclk_gen
    GENERIC MAP(
        DATA_SIZE => DATA_SIZE)
    PORT MAP(
        i_sys_clk      => i_sys_clk,
        i_sys_rst      => i_sys_rst,
        i_spi_start    => i_spi_start,
        i_clk_period   => i_clk_period,
        i_setup_cycles => i_setup_cycles,
        i_hold_cycles  => i_hold_cycles,
        i_tx2tx_cycles => i_tx2tx_cycles,
        i_cpol         => i_cpol,
        o_ss_start     => ss_start_i,
        o_sclk         => sclk_i
    );

    spi_data_path_u1 : spi_data_path
    GENERIC MAP(
        DATA_SIZE => DATA_SIZE,
        FIFO_REQ  => FIFO_REQ)
    PORT MAP(
        i_sys_clk   => i_sys_clk,
        i_sys_rst   => i_sys_rst,
        i_csn       => i_csn,
        i_data      => i_data,
        i_wr        => i_wr,
        i_rd        => i_rd,
        i_spi_start => i_spi_start,
        o_data      => o_data,
        o_tx_ready  => o_tx_ready,
        o_rx_ready  => o_rx_ready,
        o_tx_error  => o_tx_error,
        o_rx_error  => o_rx_error,
        o_intr      => o_intr,
        i_cpol      => i_cpol,
        i_cpha      => i_cpha,
        i_lsb_first => i_lsb_first,
        o_mosi      => o_mosi,
        i_miso      => i_miso,
        i_ssn       => ss_start_i,
        i_sclk      => sclk_i,
        mosi_tri_en => mosi_tri_en
    );

END spi_master_rtl;
