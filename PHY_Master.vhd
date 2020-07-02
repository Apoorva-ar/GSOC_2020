-- Copyright (C) 2020 Apoorva Arora
-----------------------------------------------------------------------------------
-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation, either version
-- 2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

ENTITY PHY_Master IS
    GENERIC (
        DATA_SIZE : INTEGER := 16;
        FIFO_REQ  : BOOLEAN := True);
    PORT (
        i_sys_clk      : IN std_logic;                                 -- system clock
        i_sys_rst      : IN std_logic;                                 -- system reset
        i_data         : IN std_logic_vector(DATA_SIZE - 1 DOWNTO 0);  -- Input data
        o_data         : OUT std_logic_vector(DATA_SIZE - 1 DOWNTO 0); --output data
        i_wr_tr_en     : IN std_logic;                                 -- write transaction enable
        i_rd_tr_en     : IN std_logic;                                 -- read transaction enable
        i_csn          : IN std_logic;                                 -- chip select for PHY master transaction Data IO
        i_wr           : IN std_logic;                                 -- Active Low Write, Active High Read
        i_rd           : IN std_logic;                                 -- Active Low Write, Active High Read
        o_tx_ready     : OUT std_logic;                                -- Transmitter ready, can write another data
        o_rx_ready     : OUT std_logic;                                -- Receiver ready, can read data
        o_tx_error     : OUT std_logic;                                -- Transmitter error
        o_rx_error     : OUT std_logic;                                -- Receiver error
        o_intr         : OUT std_logic;
        i_cpol         : IN std_logic;                    -- CPOL value - 0 or 1
        i_cpha         : IN std_logic;                    -- CPHA value - 0 or 1 
        i_lsb_first    : IN std_logic;                    -- lsb first when '1' /msb first when 
        i_PHY_start    : IN std_logic;                    -- START PHY Master Transactions
        i_clk_period   : IN std_logic_vector(7 DOWNTO 0); -- SCL clock period in terms of i_sys_clk
        i_setup_cycles : IN std_logic_vector(7 DOWNTO 0); --  setup time  in terms of i_sys_clk
        i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0); --  hold time  in terms of i_sys_clk
        i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0); --  interval between data transactions in terms of i_sys_clk
        PHY_M_IO       : INOUT std_logic;                 -- LVDS bidirectional data link
        o_sclk         : OUT std_logic;                   -- Master clock
        mosi_tri_en    : OUT std_logic
    );
END PHY_Master;

ARCHITECTURE PHY_master_rtl OF PHY_Master IS

    COMPONENT PHY_sclk_gen
        GENERIC (
            DATA_SIZE : INTEGER);
        PORT (
            i_sys_clk      : IN std_logic;
            i_sys_rst      : IN std_logic;
            i_PHY_start    : IN std_logic;
            i_clk_period   : IN std_logic_vector(7 DOWNTO 0);
            i_setup_cycles : IN std_logic_vector(7 DOWNTO 0);
            i_hold_cycles  : IN std_logic_vector(7 DOWNTO 0);
            i_tx2tx_cycles : IN std_logic_vector(7 DOWNTO 0);
            i_cpol         : IN std_logic;
            write_tr_en    : IN std_logic;
            read_tr_en     : IN std_logic;
            o_ss_start     : OUT std_logic_vector(1 DOWNTO 0);
            o_sclk         : OUT std_logic
        );
    END COMPONENT;

    COMPONENT PHY_Data_path
        GENERIC (
            DATA_SIZE : INTEGER;
            FIFO_REQ  : BOOLEAN);
        PORT (
            i_sys_clk   : IN std_logic;                                -- system clock
            i_sys_rst   : IN std_logic;                                -- system reset
            i_csn       : IN std_logic;                                -- Master Enable/select
            i_data      : IN std_logic_vector(DATA_SIZE - 1 DOWNTO 0); -- Input data
            i_wr        : IN std_logic;                                -- Active Low Write, Active High Read
            i_rd        : IN std_logic;                                -- Active Low Write, Active High Read
            i_PHY_start : IN std_logic;
            o_data      : OUT std_logic_vector(DATA_SIZE - 1 DOWNTO 0); --output data
            o_tx_ready  : OUT std_logic;                                -- Transmitter ready, can write another 
            o_rx_ready  : OUT std_logic;                                -- Receiver ready, can read data
            o_tx_error  : OUT std_logic;                                -- Transmitter error
            o_rx_error  : OUT std_logic;                                -- Receiver error
            i_cpol      : IN std_logic;                                 -- CPOL value - 0 or 1
            i_cpha      : IN std_logic;                                 -- CPHA value - 0 or 1 
            i_lsb_first : IN std_logic;                                 -- lsb first when '1' /msb first when -- '0'
            o_intr      : OUT std_logic;
            io_LVDS     : INOUT std_logic;
            i_ssn       : IN std_logic_vector(1 DOWNTO 0); -- Slave Slect Active low
            i_sclk      : IN std_logic                     -- Clock from PHY Master clock gen
        );

    END COMPONENT;

    SIGNAL sclk_i     : std_logic;
    SIGNAL ss_start_i : std_logic_vector(1 DOWNTO 0);
BEGIN

    o_sclk <= sclk_i;

    sclk_gen_u0 : PHY_sclk_gen
    GENERIC MAP(
        DATA_SIZE => DATA_SIZE)
    PORT MAP(
        i_sys_clk      => i_sys_clk,
        i_sys_rst      => i_sys_rst,
        i_PHY_start    => i_PHY_start,
        i_clk_period   => i_clk_period,
        i_setup_cycles => i_setup_cycles,
        i_hold_cycles  => i_hold_cycles,
        i_tx2tx_cycles => i_tx2tx_cycles,
        i_cpol         => i_cpol,
        write_tr_en    => i_wr_tr_en,
        read_tr_en     => i_rd_tr_en,
        o_ss_start     => ss_start_i,
        o_sclk         => sclk_i
    );

    phy_data_path_u1 : PHY_Data_path
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
        i_PHY_start => i_PHY_start,
        o_data      => o_data,
        o_tx_ready  => o_tx_ready,
        o_rx_ready  => o_rx_ready,
        o_tx_error  => o_tx_error,
        o_rx_error  => o_rx_error,
        o_intr      => o_intr,
        i_cpol      => i_cpol,
        i_cpha      => i_cpha,
        i_lsb_first => i_lsb_first,
        i_sclk      => sclk_i,
        i_ssn       => ss_start_i,
        io_LVDS     => PHY_M_IO
    );

END PHY_master_rtl;
