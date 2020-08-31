----------------------------------------------------------------------------
--  top.vhd (for bidirectional packet protocol)
--	Axiom Beta Bidirectional Packet protocol Test
--	Version 1.0
--
--  Copyright (C) Herbert Poetzl, Apoorva Arora, Rahul Vyas
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
--
----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

LIBRARY unisim;
USE unisim.VCOMPONENTS.ALL;

LIBRARY unimacro;
USE unimacro.VCOMPONENTS.ALL;

USE work.axi3m_pkg.ALL;  -- AXI3 Master
USE work.axi3ml_pkg.ALL; -- AXI3 Lite Master
USE work.axi3s_pkg.ALL;  -- AXI3 Slave

USE work.reduce_pkg.ALL; -- Logic Reduction
USE work.vivado_pkg.ALL; -- Vivado Attributes

USE work.fifo_pkg.ALL;      -- FIFO Functions
USE work.reg_array_pkg.ALL; -- Register Arrays
USE work.par_array_pkg.ALL; -- Parallel Data
USE work.lut_array_pkg.ALL; -- Block RAM Arrays
USE work.hdmi_pll_pkg.ALL;  -- HDMI PLL Configs
USE work.vec_mat_pkg.ALL;   -- Vector/Matrix
USE work.helper_pkg.ALL;    -- Vivado Attributes
USE work.vec_mat_pkg.ALL;   -- Vector Types

ENTITY top IS
	PORT (
		LVDS_IO_top_p : INOUT std_logic;
		LVDS_IO_top_n : INOUT std_logic;
		LVDS_clk_top : OUT std_logic
	);

END ENTITY top;
ARCHITECTURE RTL OF top IS

	COMPONENT bd_packet_module IS

		PORT (
			s_axi_aclk     : IN std_logic;
			s_axi_areset_n : IN std_logic;
			--
			s_axi_ro : OUT axi3ml_read_in_r;
			s_axi_ri : IN axi3ml_read_out_r;
			s_axi_wo : OUT axi3ml_write_in_r;
			s_axi_wi : IN axi3ml_write_out_r;
			--
			LVDS_O_bd: OUT std_logic;
		    LVDS_I_bd: IN std_logic;
			LVDS_clk_bd: OUT std_logic;
	        LVDS_tristate_bd : out std_logic
		);

	END COMPONENT;

	ATTRIBUTE KEEP_HIERARCHY OF RTL : ARCHITECTURE IS "TRUE";
	SIGNAL LVDS_output_buf : std_logic;
	SIGNAL LVDS_input_buf : std_logic;	
    SIGNAL tristate_en : std_logic;
    SIGNAL Output_LVDS :std_logic;
    SIGNAL Input_LVDS :std_logic;    
	SIGNAL clk_100 : std_logic;

	SIGNAL debug_data   : std_logic_vector (3 DOWNTO 0);
	SIGNAL debug_data_d : std_logic_vector (3 DOWNTO 0);

	SIGNAL hd_de   : std_logic;
	SIGNAL hd_terc : std_logic;

	SIGNAL hd_hsync : std_logic;
	SIGNAL hd_vsync : std_logic;
	SIGNAL hd_pream : std_logic_vector (1 DOWNTO 0);
	SIGNAL hd_guard : std_logic_vector (2 DOWNTO 0);

	--------------------------------------------------------------------
	-- TMDS Signals
	--------------------------------------------------------------------

	SIGNAL tmds_south_io : std_logic_vector (3 DOWNTO 0);
	SIGNAL tmds_north_io : std_logic_vector (3 DOWNTO 0);

	SIGNAL tmds_enable : std_logic := '1';
	SIGNAL tmds_reset  : std_logic := '0';

	SIGNAL rgb_data : vec8_a (2 DOWNTO 0) :=
	(OTHERS => (OTHERS => '0'));

	SIGNAL dil_data : std_logic_vector (8 DOWNTO 0);
	SIGNAL dil_de   : std_logic;

	SIGNAL rgb_de    : std_logic;
	SIGNAL rgb_blank : std_logic;

	SIGNAL rgb_hsync : std_logic;
	SIGNAL rgb_vsync : std_logic;
	SIGNAL rgb_pream : std_logic_vector (1 DOWNTO 0);
	SIGNAL rgb_guard : std_logic_vector (2 DOWNTO 0);

	SIGNAL btn : std_logic_vector (4 DOWNTO 0) := (OTHERS => '0');
	SIGNAL swi : std_logic_vector (7 DOWNTO 0) := (OTHERS => '0');
	SIGNAL led : std_logic_vector (7 DOWNTO 0);

	--------------------------------------------------------------------
	-- PS7 Signals
	--------------------------------------------------------------------

	SIGNAL ps_fclk    : std_logic_vector (3 DOWNTO 0);
	SIGNAL ps_reset_n : std_logic_vector (3 DOWNTO 0);

	--------------------------------------------------------------------
	-- PS7 AXI CMV Master Signals
	--------------------------------------------------------------------

	SIGNAL m_axi0_aclk     : std_logic;
	SIGNAL m_axi0_areset_n : std_logic;

	SIGNAL m_axi0_ri : axi3m_read_in_r;
	SIGNAL m_axi0_ro : axi3m_read_out_r;
	SIGNAL m_axi0_wi : axi3m_write_in_r;
	SIGNAL m_axi0_wo : axi3m_write_out_r;

	SIGNAL m_axi0l_ri : axi3ml_read_in_r;
	SIGNAL m_axi0l_ro : axi3ml_read_out_r;
	SIGNAL m_axi0l_wi : axi3ml_write_in_r;
	SIGNAL m_axi0l_wo : axi3ml_write_out_r;

	SIGNAL m_axi0a_aclk     : std_logic_vector (7 DOWNTO 0);
	SIGNAL m_axi0a_areset_n : std_logic_vector (7 DOWNTO 0);

	SIGNAL m_axi0a_ri : axi3ml_read_in_a(7 DOWNTO 0);
	SIGNAL m_axi0a_ro : axi3ml_read_out_a(7 DOWNTO 0);
	SIGNAL m_axi0a_wi : axi3ml_write_in_a(7 DOWNTO 0);
	SIGNAL m_axi0a_wo : axi3ml_write_out_a(7 DOWNTO 0);

	--------------------------------------------------------------------
	-- PS7 AXI HDMI Master Signals
	--------------------------------------------------------------------

	SIGNAL m_axi1_aclk     : std_logic;
	SIGNAL m_axi1_areset_n : std_logic;

	SIGNAL m_axi1_ri : axi3m_read_in_r;
	SIGNAL m_axi1_ro : axi3m_read_out_r;
	SIGNAL m_axi1_wi : axi3m_write_in_r;
	SIGNAL m_axi1_wo : axi3m_write_out_r;

	SIGNAL m_axi1l_ri : axi3ml_read_in_r;
	SIGNAL m_axi1l_ro : axi3ml_read_out_r;
	SIGNAL m_axi1l_wi : axi3ml_write_in_r;
	SIGNAL m_axi1l_wo : axi3ml_write_out_r;

	SIGNAL m_axi1a_aclk     : std_logic_vector (7 DOWNTO 0);
	SIGNAL m_axi1a_areset_n : std_logic_vector (7 DOWNTO 0);

	SIGNAL m_axi1a_ri : axi3ml_read_in_a(7 DOWNTO 0);
	SIGNAL m_axi1a_ro : axi3ml_read_out_a(7 DOWNTO 0);
	SIGNAL m_axi1a_wi : axi3ml_write_in_a(7 DOWNTO 0);
	SIGNAL m_axi1a_wo : axi3ml_write_out_a(7 DOWNTO 0);

	--------------------------------------------------------------------
	-- PS7 AXI Slave Signals
	--------------------------------------------------------------------

	SIGNAL s_axi_aclk     : std_logic_vector (3 DOWNTO 0);
	SIGNAL s_axi_areset_n : std_logic_vector (3 DOWNTO 0);

	SIGNAL s_axi_ri : axi3s_read_in_a(3 DOWNTO 0);
	SIGNAL s_axi_ro : axi3s_read_out_a(3 DOWNTO 0);
	SIGNAL s_axi_wi : axi3s_write_in_a(3 DOWNTO 0);
	SIGNAL s_axi_wo : axi3s_write_out_a(3 DOWNTO 0);

	--------------------------------------------------------------------
	-- PS7 EMIO GPIO Signals
	--------------------------------------------------------------------

	SIGNAL emio_gpio_i   : std_logic_vector(63 DOWNTO 0);
	SIGNAL emio_gpio_o   : std_logic_vector(63 DOWNTO 0);
	SIGNAL emio_gpio_t_n : std_logic_vector(63 DOWNTO 0);

	--------------------------------------------------------------------
	-- I2C0 Signals
	--------------------------------------------------------------------

	SIGNAL i2c0_sda_i   : std_ulogic;
	SIGNAL i2c0_sda_o   : std_ulogic;
	SIGNAL i2c0_sda_t   : std_ulogic;
	SIGNAL i2c0_sda_t_n : std_ulogic;

	SIGNAL i2c0_scl_i   : std_ulogic;
	SIGNAL i2c0_scl_o   : std_ulogic;
	SIGNAL i2c0_scl_t   : std_ulogic;
	SIGNAL i2c0_scl_t_n : std_ulogic;

	--------------------------------------------------------------------
	-- I2C1 Signals
	--------------------------------------------------------------------

	SIGNAL i2c1_sda_i   : std_ulogic;
	SIGNAL i2c1_sda_o   : std_ulogic;
	SIGNAL i2c1_sda_t   : std_ulogic;
	SIGNAL i2c1_sda_t_n : std_ulogic;

	SIGNAL i2c1_scl_i   : std_ulogic;
	SIGNAL i2c1_scl_o   : std_ulogic;
	SIGNAL i2c1_scl_t   : std_ulogic;
	SIGNAL i2c1_scl_t_n : std_ulogic;

	--------------------------------------------------------------------
	-- CMV MMCM Signals
	--------------------------------------------------------------------

	SIGNAL cmv_pll_locked : std_ulogic;

	SIGNAL cmv_lvds_clk : std_ulogic;
	SIGNAL cmv_cmd_clk  : std_ulogic;
	SIGNAL cmv_spi_clk  : std_ulogic;
	SIGNAL cmv_axi_clk  : std_ulogic;
	SIGNAL cmv_dly_clk  : std_ulogic;

	--------------------------------------------------------------------
	-- LVDS PLL Signals
	--------------------------------------------------------------------

	SIGNAL lvds_pll_locked : std_ulogic;
	SIGNAL cmv_outclk : std_ulogic;

	--------------------------------------------------------------------
	-- HDMI MMCM Signals
	--------------------------------------------------------------------

	SIGNAL hdmi_pll_locked : std_ulogic;

	SIGNAL tmds_clk : std_ulogic;
	SIGNAL hdmi_clk : std_ulogic;
	SIGNAL data_clk : std_ulogic;

	--------------------------------------------------------------------
	-- LVDS IDELAY Signals
	--------------------------------------------------------------------

	CONSTANT CHANNELS : NATURAL := 32;

	SIGNAL idelay_valid : std_logic;

	SIGNAL idelay_in_p : std_logic_vector (CHANNELS + 1 DOWNTO 0);
	SIGNAL idelay_in_n : std_logic_vector (CHANNELS + 1 DOWNTO 0);
	SIGNAL idelay_in   : std_logic_vector (CHANNELS + 1 DOWNTO 0);
	SIGNAL idelay_out  : std_logic_vector (CHANNELS + 1 DOWNTO 0);
	SIGNAL ser_out     : std_logic_vector (CHANNELS + 1 DOWNTO 0)
	:= (OTHERS => '0');

	--------------------------------------------------------------------
	-- CMV Serdes Signals
	--------------------------------------------------------------------

	SIGNAL serdes_phase : std_logic;

	SIGNAL serdes_bitslip : std_logic_vector (CHANNELS + 1 DOWNTO 0);

	--------------------------------------------------------------------
	-- CMV Parallel Data Signals
	--------------------------------------------------------------------

	SIGNAL par_data   : par12_a (CHANNELS DOWNTO 0);
	SIGNAL par_data_e : par12_a (CHANNELS DOWNTO 0);
	SIGNAL par_data_o : par12_a (CHANNELS DOWNTO 0);

	ALIAS par_ctrl : std_logic_vector (11 DOWNTO 0)
	IS par_data(CHANNELS);
	SIGNAL par_ctrl_d : std_logic_vector (11 DOWNTO 0);

	SIGNAL par_valid   : std_logic;
	SIGNAL par_valid_d : std_logic;
	SIGNAL par_enable  : std_logic;

	SIGNAL par_pattern  : par12_a (CHANNELS DOWNTO 0);
	SIGNAL par_match    : std_logic_vector (CHANNELS + 1 DOWNTO 0);
	SIGNAL par_mismatch : std_logic_vector (CHANNELS + 1 DOWNTO 0);

	--------------------------------------------------------------------
	-- Remapper Signals
	--------------------------------------------------------------------

	SIGNAL map_ctrl : std_logic_vector (11 DOWNTO 0);
	SIGNAL map_data : par12_a (CHANNELS - 1 DOWNTO 0);

	SIGNAL remap_ctrl : std_logic_vector (11 DOWNTO 0);
	SIGNAL remap_data : par12_a (CHANNELS - 1 DOWNTO 0);

	SIGNAL chop_enable : std_logic;

	--------------------------------------------------------------------
	-- CMV Register File Signals
	--------------------------------------------------------------------

	CONSTANT REG_SPLIT : NATURAL := 8;
	CONSTANT OREG_SIZE : NATURAL := 16;

	SIGNAL reg_oreg : reg32_a(0 TO OREG_SIZE - 1);

	ALIAS waddr_buf0 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(0)(31 DOWNTO 0);

	ALIAS waddr_pat0 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(1)(31 DOWNTO 0);

	ALIAS waddr_buf1 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(2)(31 DOWNTO 0);

	ALIAS waddr_pat1 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(3)(31 DOWNTO 0);

	ALIAS waddr_buf2 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(4)(31 DOWNTO 0);

	ALIAS waddr_pat2 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(5)(31 DOWNTO 0);

	ALIAS waddr_buf3 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(6)(31 DOWNTO 0);

	ALIAS waddr_pat3 : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(7)(31 DOWNTO 0);

	ALIAS waddr_cinc : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(8)(31 DOWNTO 0);

	ALIAS waddr_rinc : std_logic_vector (31 DOWNTO 0)
	IS reg_oreg(9)(31 DOWNTO 0);

	ALIAS waddr_ccnt : std_logic_vector (11 DOWNTO 0)
	IS reg_oreg(10)(11 DOWNTO 0);

	ALIAS fifo_data_reset : std_logic IS reg_oreg(11)(0);

	ALIAS oreg_wblock  : std_logic IS reg_oreg(11)(4);
	ALIAS oreg_wreset  : std_logic IS reg_oreg(11)(5);
	ALIAS oreg_wload   : std_logic IS reg_oreg(11)(6);
	ALIAS oreg_wswitch : std_logic IS reg_oreg(11)(7);

	ALIAS serdes_reset : std_logic IS reg_oreg(11)(8);

	ALIAS wbuf_enable : std_logic_vector (3 DOWNTO 0)
	IS reg_oreg(11)(15 DOWNTO 12);

	ALIAS writer_enable : std_logic_vector (3 DOWNTO 0)
	IS reg_oreg(11)(19 DOWNTO 16);

	ALIAS rcn_clip : std_logic_vector (1 DOWNTO 0)
	IS reg_oreg(11)(21 DOWNTO 20);

	ALIAS write_strobe : std_logic_vector (7 DOWNTO 0)
	IS reg_oreg(11)(31 DOWNTO 24);

	ALIAS reg_pattern : std_logic_vector (11 DOWNTO 0)
	IS reg_oreg(12)(11 DOWNTO 0);

	ALIAS reg_mval : std_logic_vector (2 DOWNTO 0)
	IS reg_oreg(13)(0 + 2 DOWNTO 0);

	ALIAS reg_mask : std_logic_vector (2 DOWNTO 0)
	IS reg_oreg(13)(8 + 2 DOWNTO 8);

	ALIAS reg_amsk : std_logic_vector (2 DOWNTO 0)
	IS reg_oreg(13)(16 + 2 DOWNTO 16);

	ALIAS led_val : std_logic_vector (7 DOWNTO 0)
	IS reg_oreg(14)(7 DOWNTO 0);

	ALIAS i2c1_sel : std_logic_vector (1 DOWNTO 0)
	IS reg_oreg(14)(13 DOWNTO 12);

	ALIAS led_mask : std_logic_vector (7 DOWNTO 0)
	IS reg_oreg(14)(23 DOWNTO 16);

	ALIAS swi_val : std_logic_vector (7 DOWNTO 0)
	IS reg_oreg(15)(7 DOWNTO 0);

	ALIAS btn_val : std_logic_vector (4 DOWNTO 0)
	IS reg_oreg(15)(8 + 4 DOWNTO 8);

	ALIAS swi_mask : std_logic_vector (7 DOWNTO 0)
	IS reg_oreg(15)(23 DOWNTO 16);

	ALIAS btn_mask : std_logic_vector (4 DOWNTO 0)
	IS reg_oreg(15)(24 + 4 DOWNTO 24);
	CONSTANT IREG_SIZE : NATURAL := 8;

	SIGNAL led_done : std_logic;

	SIGNAL reg_ireg : reg32_a(0 TO IREG_SIZE - 1);

	SIGNAL usr_access : std_logic_vector (31 DOWNTO 0);

	--------------------------------------------------------------------
	-- AddrGen Register File Signals
	--------------------------------------------------------------------

	CONSTANT GEN_SPLIT : NATURAL := 8;
	CONSTANT OGEN_SIZE : NATURAL := 16;

	SIGNAL reg_ogen : reg32_a(0 TO OGEN_SIZE - 1);

	ALIAS raddr_buf0 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(0)(31 DOWNTO 0);

	ALIAS raddr_pat0 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(1)(31 DOWNTO 0);

	ALIAS raddr_buf1 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(2)(31 DOWNTO 0);

	ALIAS raddr_pat1 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(3)(31 DOWNTO 0);

	ALIAS raddr_buf2 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(4)(31 DOWNTO 0);

	ALIAS raddr_pat2 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(5)(31 DOWNTO 0);

	ALIAS raddr_buf3 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(6)(31 DOWNTO 0);

	ALIAS raddr_pat3 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(7)(31 DOWNTO 0);

	ALIAS raddr_cinc : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(8)(31 DOWNTO 0);

	ALIAS raddr_rinc : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(9)(31 DOWNTO 0);

	ALIAS raddr_ccnt : std_logic_vector (11 DOWNTO 0)
	IS reg_ogen(10)(11 DOWNTO 0);

	ALIAS fifo_hdmi_reset : std_logic IS reg_ogen(11)(0);

	ALIAS ogen_rblock  : std_logic IS reg_ogen(11)(4);
	ALIAS ogen_rreset  : std_logic IS reg_ogen(11)(5);
	ALIAS ogen_rload   : std_logic IS reg_ogen(11)(6);
	ALIAS ogen_rswitch : std_logic IS reg_ogen(11)(7);

	ALIAS hdmi_pll_reset  : std_logic IS reg_ogen(11)(8);
	ALIAS hdmi_pll_pwrdwn : std_logic IS reg_ogen(11)(9);

	ALIAS rbuf_enable : std_logic_vector (3 DOWNTO 0)
	IS reg_ogen(11)(15 DOWNTO 12);

	ALIAS reader_enable : std_logic_vector (3 DOWNTO 0)
	IS reg_ogen(11)(19 DOWNTO 16);

	ALIAS overlay_enable : std_logic IS reg_ogen(11)(24);

	ALIAS ogen_code0 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(12)(31 DOWNTO 0);

	ALIAS ogen_code1 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(13)(31 DOWNTO 0);

	ALIAS ogen_code2 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(14)(31 DOWNTO 0);

	ALIAS ogen_code3 : std_logic_vector (31 DOWNTO 0)
	IS reg_ogen(15)(31 DOWNTO 0);
	CONSTANT IGEN_SIZE : NATURAL := 3;

	SIGNAL reg_igen : reg32_a(0 TO IGEN_SIZE - 1);

	--------------------------------------------------------------------
	-- Scan Register File Signals
	--------------------------------------------------------------------

	CONSTANT SCN_SPLIT : NATURAL := 8;
	CONSTANT OSCN_SIZE : NATURAL := 18;

	SIGNAL reg_oscn : reg32_a(0 TO OSCN_SIZE - 1);

	CONSTANT ISCN_SIZE : NATURAL := 2;

	SIGNAL reg_iscn : reg32_a(0 TO ISCN_SIZE - 1);

	--------------------------------------------------------------------
	-- Matrix Register File Signals
	--------------------------------------------------------------------

	CONSTANT MAT_SPLIT : NATURAL := 8;
	CONSTANT OMAT_SIZE : NATURAL := 36;

	SIGNAL reg_omat : reg32_a(0 TO OMAT_SIZE - 1);

	CONSTANT IMAT_SIZE : NATURAL := 1;

	SIGNAL reg_imat : reg32_a(0 TO IMAT_SIZE - 1);

	--------------------------------------------------------------------
	-- Color Matrix Signals
	--------------------------------------------------------------------

	SIGNAL mat_values : mat16_4x4;
	SIGNAL mat_adjust : mat16_4x4;
	SIGNAL mat_offset : vec16_4;

	SIGNAL mat_v_in  : vec12_4;
	SIGNAL mat_v_out : vec12_4;

	--------------------------------------------------------------------
	-- Override Signals
	--------------------------------------------------------------------

	SIGNAL led_out : std_logic_vector (7 DOWNTO 0);
	SIGNAL swi_ovr : std_logic_vector (7 DOWNTO 0);
	SIGNAL btn_ovr : std_logic_vector (4 DOWNTO 0);

	--------------------------------------------------------------------
	-- Reader and Writer Constants and Signals
	--------------------------------------------------------------------

	CONSTANT DATA_WIDTH : NATURAL := 64;

	CONSTANT ADDR_WIDTH : NATURAL := 32;

	TYPE addr_a IS ARRAY (NATURAL RANGE <>) OF
	std_logic_vector (ADDR_WIDTH - 1 DOWNTO 0);

	CONSTANT RADDR_MASK : addr_a(0 TO 3) :=
	(x"07FFFFFF", x"07FFFFFF", x"07FFFFFF", x"07FFFFFF");
	CONSTANT RADDR_BASE : addr_a(0 TO 3) :=
	(x"18000000", x"20000000", x"18000000", x"20000000");

	CONSTANT WADDR_MASK : addr_a(0 TO 3) :=
	(x"07FFFFFF", x"07FFFFFF", x"07FFFFFF", x"07FFFFFF");
	CONSTANT WADDR_BASE : addr_a(0 TO 3) :=
	(x"18000000", x"20000000", x"18000000", x"20000000");

	--------------------------------------------------------------------
	-- Reader Constants and Signals
	--------------------------------------------------------------------

	SIGNAL rdata_clk    : std_logic;
	SIGNAL rdata_enable : std_logic;
	SIGNAL rdata_out    : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL rdata_full   : std_logic;

	SIGNAL rdata_empty : std_logic;

	SIGNAL raddr_clk    : std_logic;
	SIGNAL raddr_enable : std_logic;
	SIGNAL raddr_in     : std_logic_vector (ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL raddr_empty  : std_logic;

	SIGNAL raddr_match  : std_logic;
	SIGNAL raddr_sel    : std_logic_vector (1 DOWNTO 0);
	SIGNAL raddr_sel_in : std_logic_vector (1 DOWNTO 0);

	SIGNAL rbuf_sel : std_logic_vector (1 DOWNTO 0);

	ALIAS reader_clk : std_logic IS cmv_axi_clk;

	SIGNAL reader_inactive : std_logic_vector (3 DOWNTO 0);
	SIGNAL reader_error    : std_logic_vector (3 DOWNTO 0);

	SIGNAL reader_active : std_logic_vector (3 DOWNTO 0);

	SIGNAL raddr_reset  : std_logic;
	SIGNAL raddr_load   : std_logic;
	SIGNAL raddr_switch : std_logic;
	SIGNAL raddr_block  : std_logic;

	--------------------------------------------------------------------
	-- Writer Constants and Signals
	--------------------------------------------------------------------

	SIGNAL wdata_clk    : std_logic;
	SIGNAL wdata_enable : std_logic;
	SIGNAL wdata_in     : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL wdata_empty  : std_logic;

	SIGNAL wdata_full : std_logic;

	SIGNAL waddr_clk    : std_logic;
	SIGNAL waddr_enable : std_logic;
	SIGNAL waddr_in     : std_logic_vector (ADDR_WIDTH - 1 DOWNTO 0);
	SIGNAL waddr_empty  : std_logic;

	SIGNAL waddr_match  : std_logic;
	SIGNAL waddr_sel    : std_logic_vector (1 DOWNTO 0);
	SIGNAL waddr_sel_in : std_logic_vector (1 DOWNTO 0);

	SIGNAL wbuf_sel : std_logic_vector (1 DOWNTO 0);

	ALIAS writer_clk : std_logic IS cmv_axi_clk;

	SIGNAL writer_inactive : std_logic_vector (3 DOWNTO 0);
	SIGNAL writer_error    : std_logic_vector (3 DOWNTO 0);

	SIGNAL writer_active : std_logic_vector (3 DOWNTO 0);
	SIGNAL writer_unconf : std_logic_vector (3 DOWNTO 0);

	SIGNAL waddr_reset  : std_logic;
	SIGNAL waddr_load   : std_logic;
	SIGNAL waddr_switch : std_logic;
	SIGNAL waddr_block  : std_logic;

	--------------------------------------------------------------------
	-- Data FIFO Signals
	--------------------------------------------------------------------

	SIGNAL fifo_data_in  : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL fifo_data_out : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);

	CONSTANT DATA_CWIDTH : NATURAL := cwidth_f(DATA_WIDTH, "36Kb");

	SIGNAL fifo_data_rdcount : std_logic_vector (DATA_CWIDTH - 1 DOWNTO 0);
	SIGNAL fifo_data_wrcount : std_logic_vector (DATA_CWIDTH - 1 DOWNTO 0);

	SIGNAL fifo_data_wclk  : std_logic;
	SIGNAL fifo_data_wen   : std_logic;
	SIGNAL fifo_data_high  : std_logic;
	SIGNAL fifo_data_full  : std_logic;
	SIGNAL fifo_data_wrerr : std_logic;

	SIGNAL fifo_data_rclk  : std_logic;
	SIGNAL fifo_data_ren   : std_logic;
	SIGNAL fifo_data_low   : std_logic;
	SIGNAL fifo_data_empty : std_logic;
	SIGNAL fifo_data_rderr : std_logic;

	SIGNAL fifo_data_rst  : std_logic;
	SIGNAL fifo_data_rrdy : std_logic;
	SIGNAL fifo_data_wrdy : std_logic;

	SIGNAL data_ctrl     : std_logic_vector (11 DOWNTO 0);
	SIGNAL data_ctrl_d   : std_logic_vector (11 DOWNTO 0);
	SIGNAL data_ctrl_dd  : std_logic_vector (11 DOWNTO 0);
	SIGNAL data_ctrl_ddd : std_logic_vector (11 DOWNTO 0);

	ALIAS data_dval : std_logic IS data_ctrl(0);
	ALIAS data_lval : std_logic IS data_ctrl(1);
	ALIAS data_fval : std_logic IS data_ctrl(2);

	ALIAS data_dval_d : std_logic IS data_ctrl_d(0);
	ALIAS data_lval_d : std_logic IS data_ctrl_d(1);
	ALIAS data_fval_d : std_logic IS data_ctrl_d(2);

	ALIAS data_dval_dd : std_logic IS data_ctrl_dd(0);
	ALIAS data_lval_dd : std_logic IS data_ctrl_dd(1);
	ALIAS data_fval_dd : std_logic IS data_ctrl_dd(2);

	ALIAS data_fot   : std_logic IS data_ctrl(3);
	ALIAS data_inte1 : std_logic IS data_ctrl(4);
	ALIAS data_inte2 : std_logic IS data_ctrl(5);

	SIGNAL match_en   : std_logic;
	SIGNAL match_en_d : std_logic;

	SIGNAL data_wen    : std_logic_vector (0 DOWNTO 0);
	SIGNAL data_wen_d  : std_logic_vector (0 DOWNTO 0);
	SIGNAL data_wen_dd : std_logic_vector (0 DOWNTO 0);

	SIGNAL data_rcn_wen : std_logic;

	SIGNAL data_in   : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL data_in_d : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	-- signal data_in_dd : std_logic_vector (DATA_WIDTH - 1 downto 0);

	SIGNAL data_rcn : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);

	SIGNAL llut_dout_ch0 : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch1 : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch2 : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch3 : std_logic_vector (17 DOWNTO 0);

	SIGNAL llut_dout_ch0_d : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch1_d : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch2_d : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch3_d : std_logic_vector (17 DOWNTO 0);

	SIGNAL llut_dout_ch0_dd : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch1_dd : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch2_dd : std_logic_vector (17 DOWNTO 0);
	SIGNAL llut_dout_ch3_dd : std_logic_vector (17 DOWNTO 0);

	SIGNAL data_rcn_ch0 : std_logic_vector (15 DOWNTO 0);
	SIGNAL data_rcn_ch1 : std_logic_vector (15 DOWNTO 0);
	SIGNAL data_rcn_ch2 : std_logic_vector (15 DOWNTO 0);
	SIGNAL data_rcn_ch3 : std_logic_vector (15 DOWNTO 0);

	--------------------------------------------------------------------
	-- HDMI FIFO Signals
	--------------------------------------------------------------------

	SIGNAL fifo_hdmi_in  : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);
	SIGNAL fifo_hdmi_out : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);

	CONSTANT HDMI_CWIDTH : NATURAL := cwidth_f(DATA_WIDTH, "36Kb");

	SIGNAL fifo_hdmi_rdcount : std_logic_vector (HDMI_CWIDTH - 1 DOWNTO 0);
	SIGNAL fifo_hdmi_wrcount : std_logic_vector (HDMI_CWIDTH - 1 DOWNTO 0);

	SIGNAL fifo_hdmi_wclk  : std_logic;
	SIGNAL fifo_hdmi_wen   : std_logic;
	SIGNAL fifo_hdmi_high  : std_logic;
	SIGNAL fifo_hdmi_full  : std_logic;
	SIGNAL fifo_hdmi_wrerr : std_logic;

	SIGNAL fifo_hdmi_rclk  : std_logic;
	SIGNAL fifo_hdmi_ren   : std_logic;
	SIGNAL fifo_hdmi_low   : std_logic;
	SIGNAL fifo_hdmi_empty : std_logic;
	SIGNAL fifo_hdmi_rderr : std_logic;

	SIGNAL fifo_hdmi_rst  : std_logic;
	SIGNAL fifo_hdmi_rrdy : std_logic;
	SIGNAL fifo_hdmi_wrdy : std_logic;

	SIGNAL hdmi_enable : std_logic;

	SIGNAL hdmi_in : std_logic_vector (DATA_WIDTH - 1 DOWNTO 0);

	ALIAS hdmi_ch0 : std_logic_vector (11 DOWNTO 0)
	IS hdmi_in (63 DOWNTO 52);
	ALIAS hdmi_ch1 : std_logic_vector (11 DOWNTO 0)
	IS hdmi_in (51 DOWNTO 40);
	ALIAS hdmi_ch2 : std_logic_vector (11 DOWNTO 0)
	IS hdmi_in (39 DOWNTO 28);
	ALIAS hdmi_ch3 : std_logic_vector (11 DOWNTO 0)
	IS hdmi_in (27 DOWNTO 16);
	ALIAS hdmi_ch4 : std_logic_vector (15 DOWNTO 0)
	IS hdmi_in (15 DOWNTO 0);

	SIGNAL hdmi_ch4_d : std_logic_vector (15 DOWNTO 0);

	SIGNAL conv_out : std_logic_vector (63 DOWNTO 0);
	SIGNAL hdmi_out : std_logic_vector (63 DOWNTO 0);

	SIGNAL hd_edata : std_logic_vector(31 DOWNTO 0);
	SIGNAL hd_odata : std_logic_vector(31 DOWNTO 0);
	SIGNAL hd_sdata : std_logic_vector(31 DOWNTO 0);

	SIGNAL hd_code : std_logic_vector(63 DOWNTO 0);

	ALIAS hd_r : std_logic_vector (11 DOWNTO 0)
	IS hd_code (63 DOWNTO 52);
	ALIAS hd_g1 : std_logic_vector (11 DOWNTO 0)
	IS hd_code (47 DOWNTO 36);
	ALIAS hd_b : std_logic_vector (11 DOWNTO 0)
	IS hd_code (31 DOWNTO 20);
	ALIAS hd_g2 : std_logic_vector (11 DOWNTO 0)
	IS hd_code (15 DOWNTO 4);
	--------------------------------------------------------------------
	-- HDMI Scan Signals
	--------------------------------------------------------------------

	SIGNAL scan_disp : std_logic_vector (3 DOWNTO 0);
	SIGNAL scan_sync : std_logic_vector (3 DOWNTO 0);
	SIGNAL scan_data : std_logic_vector (3 DOWNTO 0);
	SIGNAL scan_ctrl : std_logic_vector (3 DOWNTO 0);

	SIGNAL scan_hevent : std_logic_vector (3 DOWNTO 0);
	SIGNAL scan_vevent : std_logic_vector (3 DOWNTO 0);

	SIGNAL scan_hcnt : std_logic_vector (11 DOWNTO 0);
	SIGNAL scan_vcnt : std_logic_vector (11 DOWNTO 0);
	SIGNAL scan_fcnt : std_logic_vector (11 DOWNTO 0);

	SIGNAL scan_econf : std_logic_vector (63 DOWNTO 0);
	SIGNAL scan_event : std_logic_vector (63 DOWNTO 0);

	SIGNAL scan_eo : std_logic;

	SIGNAL scan_rblock : std_logic;
	SIGNAL scan_rreset : std_logic;
	SIGNAL scan_rload  : std_logic;
	SIGNAL scan_arm    : std_logic;

	SIGNAL sync_rblock  : std_logic;
	SIGNAL sync_rreset  : std_logic;
	SIGNAL sync_rload   : std_logic;
	SIGNAL sync_rswitch : std_logic_vector (1 DOWNTO 0);

	SIGNAL event_event  : std_logic_vector (7 DOWNTO 0);
	SIGNAL event_data   : std_logic_vector (1 DOWNTO 0);
	SIGNAL event_data_d : std_logic_vector (1 DOWNTO 0);

	SIGNAL event_hcnt : std_logic_vector (11 DOWNTO 0);
	SIGNAL event_vcnt : std_logic_vector (11 DOWNTO 0);
	SIGNAL event_fcnt : std_logic_vector (11 DOWNTO 0);

	SIGNAL event_cr : std_logic_vector (11 DOWNTO 0);
	SIGNAL event_cg : std_logic_vector (11 DOWNTO 0);
	SIGNAL event_cb : std_logic_vector (11 DOWNTO 0);
	--------------------------------------------------------------------
	-- Capture Sequencer Signals
	--------------------------------------------------------------------

	SIGNAL cseq_clk  : std_logic;
	SIGNAL cseq_done : std_logic;
	SIGNAL cseq_fcnt : std_logic_vector (11 DOWNTO 0)
	:= (OTHERS => '0');

	SIGNAL cseq_req   : std_logic;
	SIGNAL cseq_shift : std_logic_vector (31 DOWNTO 0)
	:= (OTHERS => '0');

	SIGNAL cseq_wblock  : std_logic;
	SIGNAL cseq_wreset  : std_logic;
	SIGNAL cseq_wload   : std_logic;
	SIGNAL cseq_wswitch : std_logic;

	SIGNAL cseq_wempty : std_logic;
	SIGNAL cseq_frmreq : std_logic;

	SIGNAL cseq_flip   : std_logic;
	SIGNAL cseq_switch : std_logic;

	SIGNAL sync_wblock  : std_logic;
	SIGNAL sync_wreset  : std_logic;
	SIGNAL sync_wload   : std_logic;
	SIGNAL sync_wswitch : std_logic_vector (1 DOWNTO 0);

	SIGNAL sync_wempty  : std_logic;
	SIGNAL sync_wenable : std_logic;
	SIGNAL sync_winact  : std_logic;
	SIGNAL sync_frmreq  : std_logic;
	SIGNAL sync_arm     : std_logic;

	--------------------------------------------------------------------
	-- Cross Event Signals
	--------------------------------------------------------------------

	SIGNAL cmv_active : std_logic;

	SIGNAL sync_switch : std_logic;
	SIGNAL sync_done   : std_logic;

	SIGNAL flip_active : std_logic;

	SIGNAL sync_flip : std_logic;

	SIGNAL ilu_clk    : std_logic;
	SIGNAL ilu_frmreq : std_logic;

	SIGNAL ilu_led0 : std_logic := '0';
	SIGNAL ilu_led1 : std_logic := '0';
	SIGNAL ilu_led2 : std_logic := '0';

	SIGNAL ilu_led3 : std_logic := '0';
	SIGNAL ilu_led4 : std_logic := '0';

	--------------------------------------------------------------------
	-- BRAM LUT Signals
	--------------------------------------------------------------------

	CONSTANT CLUT_COUNT : NATURAL := 6;

	SIGNAL clut_addr    : lut11_a (0 TO CLUT_COUNT - 1);
	SIGNAL clut_dout    : lut12_a (0 TO CLUT_COUNT - 1);
	SIGNAL clut_dout_d  : lut12_a (0 TO CLUT_COUNT - 1);
	SIGNAL clut_dout_dd : lut12_a (0 TO CLUT_COUNT - 1);

	CONSTANT LLUT_COUNT : NATURAL := 4;

	SIGNAL llut_addr   : lut12_a (0 TO LLUT_COUNT - 1);
	SIGNAL llut_dout   : lut18_a (0 TO LLUT_COUNT - 1);
	SIGNAL llut_dout_d : lut18_a (0 TO LLUT_COUNT - 1);

	CONSTANT DLUT_COUNT : NATURAL := 4;

	SIGNAL dlut_addr   : lut12_a (0 TO DLUT_COUNT - 1);
	SIGNAL dlut_dout   : lut16_a (0 TO DLUT_COUNT - 1);
	SIGNAL dlut_dout_d : lut16_a (0 TO DLUT_COUNT - 1);

	--------------------------------------------------------------------
	-- BRAM MEM Signals
	--------------------------------------------------------------------

	SIGNAL dmem_addr : std_logic_vector (11 DOWNTO 0);
	SIGNAL dmem_dout : std_logic_vector (8 DOWNTO 0);

BEGIN

	--------------------------------------------------------------------
	-- PS7 Interface
	--------------------------------------------------------------------

	ps7_stub_inst : ENTITY work.ps7_stub
		PORT MAP(
			i2c0_sda_i   => i2c0_sda_i,
			i2c0_sda_o   => i2c0_sda_o,
			i2c0_sda_t_n => i2c0_sda_t_n,
			--
			i2c0_scl_i   => i2c0_scl_i,
			i2c0_scl_o   => i2c0_scl_o,
			i2c0_scl_t_n => i2c0_scl_t_n,
			--
			i2c1_sda_i   => i2c1_sda_i,
			i2c1_sda_o   => i2c1_sda_o,
			i2c1_sda_t_n => i2c1_sda_t_n,
			--
			i2c1_scl_i   => i2c1_scl_i,
			i2c1_scl_o   => i2c1_scl_o,
			i2c1_scl_t_n => i2c1_scl_t_n,
			--
			ps_fclk    => ps_fclk,
			ps_reset_n => ps_reset_n,
			--
			emio_gpio_i   => emio_gpio_i,
			emio_gpio_o   => emio_gpio_o,
			emio_gpio_t_n => emio_gpio_t_n,
			--
			m_axi0_aclk     => m_axi0_aclk,
			m_axi0_areset_n => m_axi0_areset_n,
			--
			m_axi0_arid    => m_axi0_ro.arid,
			m_axi0_araddr  => m_axi0_ro.araddr,
			m_axi0_arburst => m_axi0_ro.arburst,
			m_axi0_arlen   => m_axi0_ro.arlen,
			m_axi0_arsize  => m_axi0_ro.arsize,
			m_axi0_arprot  => m_axi0_ro.arprot,
			m_axi0_arvalid => m_axi0_ro.arvalid,
			m_axi0_arready => m_axi0_ri.arready,
			--
			m_axi0_rid    => m_axi0_ri.rid,
			m_axi0_rdata  => m_axi0_ri.rdata,
			m_axi0_rlast  => m_axi0_ri.rlast,
			m_axi0_rresp  => m_axi0_ri.rresp,
			m_axi0_rvalid => m_axi0_ri.rvalid,
			m_axi0_rready => m_axi0_ro.rready,
			--
			m_axi0_awid    => m_axi0_wo.awid,
			m_axi0_awaddr  => m_axi0_wo.awaddr,
			m_axi0_awburst => m_axi0_wo.awburst,
			m_axi0_awlen   => m_axi0_wo.awlen,
			m_axi0_awsize  => m_axi0_wo.awsize,
			m_axi0_awprot  => m_axi0_wo.awprot,
			m_axi0_awvalid => m_axi0_wo.awvalid,
			m_axi0_awready => m_axi0_wi.wready,
			--
			m_axi0_wid    => m_axi0_wo.wid,
			m_axi0_wdata  => m_axi0_wo.wdata,
			m_axi0_wstrb  => m_axi0_wo.wstrb,
			m_axi0_wlast  => m_axi0_wo.wlast,
			m_axi0_wvalid => m_axi0_wo.wvalid,
			m_axi0_wready => m_axi0_wi.wready,
			--
			m_axi0_bid    => m_axi0_wi.bid,
			m_axi0_bresp  => m_axi0_wi.bresp,
			m_axi0_bvalid => m_axi0_wi.bvalid,
			m_axi0_bready => m_axi0_wo.bready,
			--
			m_axi1_aclk     => m_axi1_aclk,
			m_axi1_areset_n => m_axi1_areset_n,
			--
			m_axi1_arid    => m_axi1_ro.arid,
			m_axi1_araddr  => m_axi1_ro.araddr,
			m_axi1_arburst => m_axi1_ro.arburst,
			m_axi1_arlen   => m_axi1_ro.arlen,
			m_axi1_arsize  => m_axi1_ro.arsize,
			m_axi1_arprot  => m_axi1_ro.arprot,
			m_axi1_arvalid => m_axi1_ro.arvalid,
			m_axi1_arready => m_axi1_ri.arready,
			--
			m_axi1_rid    => m_axi1_ri.rid,
			m_axi1_rdata  => m_axi1_ri.rdata,
			m_axi1_rlast  => m_axi1_ri.rlast,
			m_axi1_rresp  => m_axi1_ri.rresp,
			m_axi1_rvalid => m_axi1_ri.rvalid,
			m_axi1_rready => m_axi1_ro.rready,
			--
			m_axi1_awid    => m_axi1_wo.awid,
			m_axi1_awaddr  => m_axi1_wo.awaddr,
			m_axi1_awburst => m_axi1_wo.awburst,
			m_axi1_awlen   => m_axi1_wo.awlen,
			m_axi1_awsize  => m_axi1_wo.awsize,
			m_axi1_awprot  => m_axi1_wo.awprot,
			m_axi1_awvalid => m_axi1_wo.awvalid,
			m_axi1_awready => m_axi1_wi.wready,
			--
			m_axi1_wid    => m_axi1_wo.wid,
			m_axi1_wdata  => m_axi1_wo.wdata,
			m_axi1_wstrb  => m_axi1_wo.wstrb,
			m_axi1_wlast  => m_axi1_wo.wlast,
			m_axi1_wvalid => m_axi1_wo.wvalid,
			m_axi1_wready => m_axi1_wi.wready,
			--
			m_axi1_bid    => m_axi1_wi.bid,
			m_axi1_bresp  => m_axi1_wi.bresp,
			m_axi1_bvalid => m_axi1_wi.bvalid,
			m_axi1_bready => m_axi1_wo.bready,
			--
			s_axi0_aclk     => s_axi_aclk(0),
			s_axi0_areset_n => s_axi_areset_n(0),
			--
			s_axi0_arid    => s_axi_ri(0).arid,
			s_axi0_araddr  => s_axi_ri(0).araddr,
			s_axi0_arburst => s_axi_ri(0).arburst,
			s_axi0_arlen   => s_axi_ri(0).arlen,
			s_axi0_arsize  => s_axi_ri(0).arsize,
			s_axi0_arprot  => s_axi_ri(0).arprot,
			s_axi0_arvalid => s_axi_ri(0).arvalid,
			s_axi0_arready => s_axi_ro(0).arready,
			s_axi0_racount => s_axi_ro(0).racount,
			--
			s_axi0_rid    => s_axi_ro(0).rid,
			s_axi0_rdata  => s_axi_ro(0).rdata,
			s_axi0_rlast  => s_axi_ro(0).rlast,
			s_axi0_rvalid => s_axi_ro(0).rvalid,
			s_axi0_rready => s_axi_ri(0).rready,
			s_axi0_rcount => s_axi_ro(0).rcount,
			--
			s_axi0_awid    => s_axi_wi(0).awid,
			s_axi0_awaddr  => s_axi_wi(0).awaddr,
			s_axi0_awburst => s_axi_wi(0).awburst,
			s_axi0_awlen   => s_axi_wi(0).awlen,
			s_axi0_awsize  => s_axi_wi(0).awsize,
			s_axi0_awprot  => s_axi_wi(0).awprot,
			s_axi0_awvalid => s_axi_wi(0).awvalid,
			s_axi0_awready => s_axi_wo(0).awready,
			s_axi0_wacount => s_axi_wo(0).wacount,
			--
			s_axi0_wid    => s_axi_wi(0).wid,
			s_axi0_wdata  => s_axi_wi(0).wdata,
			s_axi0_wstrb  => s_axi_wi(0).wstrb,
			s_axi0_wlast  => s_axi_wi(0).wlast,
			s_axi0_wvalid => s_axi_wi(0).wvalid,
			s_axi0_wready => s_axi_wo(0).wready,
			s_axi0_wcount => s_axi_wo(0).wcount,
			--
			s_axi0_bid    => s_axi_wo(0).bid,
			s_axi0_bresp  => s_axi_wo(0).bresp,
			s_axi0_bvalid => s_axi_wo(0).bvalid,
			s_axi0_bready => s_axi_wi(0).bready,
			--
			s_axi1_aclk     => s_axi_aclk(1),
			s_axi1_areset_n => s_axi_areset_n(1),
			--
			s_axi1_arid    => s_axi_ri(1).arid,
			s_axi1_araddr  => s_axi_ri(1).araddr,
			s_axi1_arburst => s_axi_ri(1).arburst,
			s_axi1_arlen   => s_axi_ri(1).arlen,
			s_axi1_arsize  => s_axi_ri(1).arsize,
			s_axi1_arprot  => s_axi_ri(1).arprot,
			s_axi1_arvalid => s_axi_ri(1).arvalid,
			s_axi1_arready => s_axi_ro(1).arready,
			s_axi1_racount => s_axi_ro(1).racount,
			--
			s_axi1_rid    => s_axi_ro(1).rid,
			s_axi1_rdata  => s_axi_ro(1).rdata,
			s_axi1_rlast  => s_axi_ro(1).rlast,
			s_axi1_rvalid => s_axi_ro(1).rvalid,
			s_axi1_rready => s_axi_ri(1).rready,
			s_axi1_rcount => s_axi_ro(1).rcount,
			--
			s_axi1_awid    => s_axi_wi(1).awid,
			s_axi1_awaddr  => s_axi_wi(1).awaddr,
			s_axi1_awburst => s_axi_wi(1).awburst,
			s_axi1_awlen   => s_axi_wi(1).awlen,
			s_axi1_awsize  => s_axi_wi(1).awsize,
			s_axi1_awprot  => s_axi_wi(1).awprot,
			s_axi1_awvalid => s_axi_wi(1).awvalid,
			s_axi1_awready => s_axi_wo(1).awready,
			s_axi1_wacount => s_axi_wo(1).wacount,
			--
			s_axi1_wid    => s_axi_wi(1).wid,
			s_axi1_wdata  => s_axi_wi(1).wdata,
			s_axi1_wstrb  => s_axi_wi(1).wstrb,
			s_axi1_wlast  => s_axi_wi(1).wlast,
			s_axi1_wvalid => s_axi_wi(1).wvalid,
			s_axi1_wready => s_axi_wo(1).wready,
			s_axi1_wcount => s_axi_wo(1).wcount,
			--
			s_axi1_bid    => s_axi_wo(1).bid,
			s_axi1_bresp  => s_axi_wo(1).bresp,
			s_axi1_bvalid => s_axi_wo(1).bvalid,
			s_axi1_bready => s_axi_wi(1).bready,
			--
			s_axi2_aclk     => s_axi_aclk(2),
			s_axi2_areset_n => s_axi_areset_n(2),
			--
			s_axi2_arid    => s_axi_ri(2).arid,
			s_axi2_araddr  => s_axi_ri(2).araddr,
			s_axi2_arburst => s_axi_ri(2).arburst,
			s_axi2_arlen   => s_axi_ri(2).arlen,
			s_axi2_arsize  => s_axi_ri(2).arsize,
			s_axi2_arprot  => s_axi_ri(2).arprot,
			s_axi2_arvalid => s_axi_ri(2).arvalid,
			s_axi2_arready => s_axi_ro(2).arready,
			s_axi2_racount => s_axi_ro(2).racount,
			--
			s_axi2_rid    => s_axi_ro(2).rid,
			s_axi2_rdata  => s_axi_ro(2).rdata,
			s_axi2_rlast  => s_axi_ro(2).rlast,
			s_axi2_rvalid => s_axi_ro(2).rvalid,
			s_axi2_rready => s_axi_ri(2).rready,
			s_axi2_rcount => s_axi_ro(2).rcount,
			--
			s_axi2_awid    => s_axi_wi(2).awid,
			s_axi2_awaddr  => s_axi_wi(2).awaddr,
			s_axi2_awburst => s_axi_wi(2).awburst,
			s_axi2_awlen   => s_axi_wi(2).awlen,
			s_axi2_awsize  => s_axi_wi(2).awsize,
			s_axi2_awprot  => s_axi_wi(2).awprot,
			s_axi2_awvalid => s_axi_wi(2).awvalid,
			s_axi2_awready => s_axi_wo(2).awready,
			s_axi2_wacount => s_axi_wo(2).wacount,
			--
			s_axi2_wid    => s_axi_wi(2).wid,
			s_axi2_wdata  => s_axi_wi(2).wdata,
			s_axi2_wstrb  => s_axi_wi(2).wstrb,
			s_axi2_wlast  => s_axi_wi(2).wlast,
			s_axi2_wvalid => s_axi_wi(2).wvalid,
			s_axi2_wready => s_axi_wo(2).wready,
			s_axi2_wcount => s_axi_wo(2).wcount,
			--
			s_axi2_bid    => s_axi_wo(2).bid,
			s_axi2_bresp  => s_axi_wo(2).bresp,
			s_axi2_bvalid => s_axi_wo(2).bvalid,
			s_axi2_bready => s_axi_wi(2).bready,
			--
			s_axi3_aclk     => s_axi_aclk(3),
			s_axi3_areset_n => s_axi_areset_n(3),
			--
			s_axi3_arid    => s_axi_ri(3).arid,
			s_axi3_araddr  => s_axi_ri(3).araddr,
			s_axi3_arburst => s_axi_ri(3).arburst,
			s_axi3_arlen   => s_axi_ri(3).arlen,
			s_axi3_arsize  => s_axi_ri(3).arsize,
			s_axi3_arprot  => s_axi_ri(3).arprot,
			s_axi3_arvalid => s_axi_ri(3).arvalid,
			s_axi3_arready => s_axi_ro(3).arready,
			s_axi3_racount => s_axi_ro(3).racount,
			--
			s_axi3_rid    => s_axi_ro(3).rid,
			s_axi3_rdata  => s_axi_ro(3).rdata,
			s_axi3_rlast  => s_axi_ro(3).rlast,
			s_axi3_rvalid => s_axi_ro(3).rvalid,
			s_axi3_rready => s_axi_ri(3).rready,
			s_axi3_rcount => s_axi_ro(3).rcount,
			--
			s_axi3_awid    => s_axi_wi(3).awid,
			s_axi3_awaddr  => s_axi_wi(3).awaddr,
			s_axi3_awburst => s_axi_wi(3).awburst,
			s_axi3_awlen   => s_axi_wi(3).awlen,
			s_axi3_awsize  => s_axi_wi(3).awsize,
			s_axi3_awprot  => s_axi_wi(3).awprot,
			s_axi3_awvalid => s_axi_wi(3).awvalid,
			s_axi3_awready => s_axi_wo(3).awready,
			s_axi3_wacount => s_axi_wo(3).wacount,
			--
			s_axi3_wid    => s_axi_wi(3).wid,
			s_axi3_wdata  => s_axi_wi(3).wdata,
			s_axi3_wstrb  => s_axi_wi(3).wstrb,
			s_axi3_wlast  => s_axi_wi(3).wlast,
			s_axi3_wvalid => s_axi_wi(3).wvalid,
			s_axi3_wready => s_axi_wo(3).wready,
			s_axi3_wcount => s_axi_wo(3).wcount,
			--
			s_axi3_bid    => s_axi_wo(3).bid,
			s_axi3_bresp  => s_axi_wo(3).bresp,
			s_axi3_bvalid => s_axi_wo(3).bvalid,
			s_axi3_bready => s_axi_wi(3).bready);
	clk_100 <= ps_fclk(0);

	-- cmv_sys_res_n <= '1';

	--------------------------------------------------------------------
	-- AXI3 CMV Interconnect
	--------------------------------------------------------------------

	axi_lite_inst0 : ENTITY work.axi_lite
		PORT MAP(
			s_axi_aclk     => m_axi0_aclk,
			s_axi_areset_n => m_axi0_areset_n,

			s_axi_ro => m_axi0_ri,
			s_axi_ri => m_axi0_ro,
			s_axi_wo => m_axi0_wi,
			s_axi_wi => m_axi0_wo,

			m_axi_ro => m_axi0l_ro,
			m_axi_ri => m_axi0l_ri,
			m_axi_wo => m_axi0l_wo,
			m_axi_wi => m_axi0l_wi);

	m_axi0_aclk <= clk_100;
	--------------------------------------------------------------------
	-- CMV SPI Interface
	--------------------------------------------------------------------

   BD_PACKET_Layer : ENTITY work.bd_packet_module
		PORT MAP(
			s_axi_aclk     => m_axi0_aclk,
			s_axi_areset_n => m_axi0_areset_n,
			--
			s_axi_ro => m_axi0l_ri,
			s_axi_ri => m_axi0l_ro,
			s_axi_wo => m_axi0l_wi,
			s_axi_wi => m_axi0l_wo,
			LVDS_O_bd => LVDS_output_buf,
			LVDS_I_bd => LVDS_input_buf,			
			LVDS_clk_bd => LVDS_clk_top,
			LVDS_tristate_bd => tristate_en
			);

IOBUFDS_inst : IOBUFDS
generic map (   DIFF_TERM => FALSE, -- Differential Termination (TRUE/FALSE)
                IBUF_LOW_PWR => TRUE, -- Low Power = TRUE, High Performance = FALSE 
                IOSTANDARD => "BLVDS_25", -- Specify the I/O standard
                SLEW => "SLOW")       -- Specify the output slew rate
port map (   O => LVDS_input_buf,     -- Buffer output
            IO => LVDS_IO_top_p,      -- Diff_p inout (connect directly to top-level port) 
           IOB => LVDS_IO_top_n,      -- Diff_n inout (connect directly to top-level port)
             I => LVDS_output_buf,    -- Buffer input
             T => tristate_en         -- 3-state enable input, high=input, low=output
          );

                 
 END RTL;