----------------------------------------------------------------------------
--  bd_packet_protocol.vhd
--	AXI Lite Interface for bidirectional Packet protocol Master
--	Version 1.0
--
--      Copyright (C) 2020 Apoorva Arora & Rahul Vyas
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
--
----------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

PACKAGE reg_array_pkg IS

	TYPE reg64_a IS ARRAY (NATURAL RANGE <>) OF
	std_logic_vector (63 DOWNTO 0);

	TYPE reg32_a IS ARRAY (NATURAL RANGE <>) OF
	std_logic_vector (31 DOWNTO 0);

	TYPE reg16_a IS ARRAY (NATURAL RANGE <>) OF
	std_logic_vector (15 DOWNTO 0);

	TYPE reg8_a IS ARRAY (NATURAL RANGE <>) OF
	std_logic_vector (7 DOWNTO 0);

END reg_array_pkg;
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

LIBRARY unisim;
USE unisim.VCOMPONENTS.ALL;

USE work.axi3ml_pkg.ALL; -- AXI3 Lite Master
USE work.vivado_pkg.ALL; -- Vivado Attributes
USE work.reg_array_pkg.ALL;
ENTITY bd_packet_module IS

	PORT (
		s_axi_aclk     : IN std_logic;
		s_axi_areset_n : IN std_logic;
		--
		s_axi_ro : OUT axi3ml_read_in_r;
		s_axi_ri : IN axi3ml_read_out_r;
		s_axi_wo : OUT axi3ml_write_in_r;
		s_axi_wi : IN axi3ml_write_out_r

	);

END ENTITY bd_packet_module;
ARCHITECTURE RTL OF bd_packet_module IS
        SIGNAL command_reg_M       : std_logic_vector(15 DOWNTO 0); -- Command Reg Master
	SIGNAL command_reg_M_valid : std_logic;
	SIGNAL data_reg_M          : std_logic_vector(15 DOWNTO 0); -- Data Reg Master
	SIGNAL data_reg_M_valid    : std_logic;
	SIGNAL command_reg_S       : std_logic_vector(15 DOWNTO 0); -- Command Reg Slave
	SIGNAL data_reg_S          : std_logic_vector(15 DOWNTO 0); -- Data Reg Slave
	SIGNAL LVDS_data_test      : std_logic;
	SIGNAL LVDS_clk_test       : std_logic;
	ATTRIBUTE KEEP_HIERARCHY OF RTL : ARCHITECTURE IS "TRUE";
	COMPONENT packet_layer_Master IS
		GENERIC (
			DATA_LEN    : INTEGER := 16;
			ADDRESS_LEN : INTEGER := 5;
			COMMAND_LEN : INTEGER := 16
		);
		PORT (
			-------------- System Interfaces ---------
			clk_top, reset : IN STD_LOGIC;
			-------------- Control channels ---------
			command_in       : IN std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
			command_valid_in : IN std_logic;
			------------- DATA IO channel ------------
			LVDS_IO    : INOUT std_logic;
			LVDS_clock : OUT std_logic;
			------- Data channel
			data_in        : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
			data_valid_in  : IN std_logic;
			data_in_ready  : OUT std_logic;
			data_out       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
			data_valid_out : OUT std_logic;
			------------- Test Intefaces --------------
			test_1        : OUT std_logic;
			test_2        : OUT std_logic_vector(3 DOWNTO 0);
			test_3        : OUT std_logic;
			test_4        : OUT std_logic_vector(15 DOWNTO 0);
			b_length_test : OUT std_logic_vector(6 DOWNTO 0);
			tr_type_test  : OUT std_logic
		);
	END COMPONENT;

	COMPONENT packet_layer_slave IS
		GENERIC (
			DATA_LEN    : INTEGER := 16;
			ADDRESS_LEN : INTEGER := 5;
			COMMAND_LEN : INTEGER := 16
		);
		PORT (
			-------------- System Interfaces ---------
			clk_top, reset : IN STD_LOGIC;
			-------------- Control channels ---------
			command_out       : OUT std_logic_vector(COMMAND_LEN - 1 DOWNTO 0);
			command_valid_out : OUT std_logic;
			------------- DATA IO channel ------------
			LVDS_IO    : INOUT std_logic;
			LVDS_clock : IN std_logic;
			------- Data channel
			data_in_S        : IN std_logic_vector(DATA_LEN - 1 DOWNTO 0);
			data_valid_in_S  : IN std_logic;
			data_in_ready_S  : OUT std_logic;
			data_out_S       : OUT std_logic_vector(DATA_LEN - 1 DOWNTO 0);
			data_valid_out_S : OUT std_logic;
			------------- Test Intefaces --------------
			test_1                 : OUT std_logic;
			test_2                 : OUT std_logic_vector(3 DOWNTO 0);
			test_3                 : OUT std_logic;
			test_4                 : OUT std_logic_vector(15 DOWNTO 0);
			b_length_test          : OUT std_logic_vector(6 DOWNTO 0);
			tr_type_test           : OUT std_logic;
			slave_cntrl_state_test : OUT std_logic_vector(2 DOWNTO 0)
		);
	END COMPONENT;
BEGIN
	Packet_Layer_Master_Component : packet_layer_Master
	GENERIC MAP(
		DATA_LEN    => 16,
		ADDRESS_LEN => 5,
		COMMAND_LEN => 16
	)
	PORT MAP(
		clk_top          => S_AXI_ACLK,
		reset            => '0',
		command_in       => command_reg_M,
		command_valid_in => command_reg_M_valid,
		LVDS_IO          => LVDS_data_test,
		LVDS_clock       => LVDS_clk_test,
		data_in          => data_reg_M,
		data_valid_in    => data_reg_M_valid
	);

	Packet_Layer_Slave_Component : packet_layer_slave
	GENERIC MAP(
		DATA_LEN    => 16,
		ADDRESS_LEN => 5,
		COMMAND_LEN => 16
	)
	PORT MAP(
		clk_top         => S_AXI_ACLK,
		reset           => '0',
		command_out     => command_reg_S,
		LVDS_IO         => LVDS_data_test,
		LVDS_clock      => LVDS_clk_test,
		data_in_S       => (OTHERS => '0'),
		data_valid_in_S => '0',
		data_out_S      => data_reg_S
	);

	-------------------------------------------------------------
	----------------- AXI Lite Slave Process --------------------
	-------------------------------------------------------------
	AXI_Lite_Process : PROCESS (
		s_axi_aclk, s_axi_areset_n,
		s_axi_ri, s_axi_wi)
		VARIABLE addr_v    : std_logic_vector (31 DOWNTO 0) := (OTHERS => '0');
		VARIABLE arready_v : std_logic                      := '0';
		VARIABLE rvalid_v  : std_logic                      := '0';
		VARIABLE awready_v : std_logic                      := '0';
		VARIABLE wready_v  : std_logic                      := '0';
		VARIABLE bvalid_v  : std_logic                      := '0';
		VARIABLE rdata_v   : std_logic_vector (31 DOWNTO 0);
		VARIABLE rresp_v   : std_logic_vector (1 DOWNTO 0) := "00";
		VARIABLE wdata_v   : std_logic_vector (31 DOWNTO 0);
		VARIABLE wstrb_v   : std_logic_vector (3 DOWNTO 0);
		VARIABLE bresp_v   : std_logic_vector (1 DOWNTO 0) := "00";
		TYPE axi_state IS (
			idle_s,
			r_addr_s, r_data_s,
			w_addr_s, w_data_s, w_resp_s);
		VARIABLE state : axi_state := idle_s;
	BEGIN
		IF rising_edge(s_axi_aclk) THEN
			IF s_axi_areset_n = '0' THEN
				addr_v    := (OTHERS => '0');
				arready_v := '0';
				rvalid_v  := '0';
				awready_v := '0';
				wready_v  := '0';
				bvalid_v  := '0';
				rdata_v   := (OTHERS => '0');
				wdata_v   := (OTHERS => '0');
				wstrb_v   := (OTHERS => '0');
				state     := idle_s;
			ELSE
				CASE state IS
					WHEN idle_s =>
						rvalid_v := '0';
						bvalid_v := '0';

						IF s_axi_ri.arvalid = '1' THEN -- address _is_ valid
							state := r_addr_s;

						ELSIF s_axi_wi.awvalid = '1' THEN -- address _is_ valid
							state := w_addr_s;
						END IF;

						--  ARVALID ---> RVALID		Master
						--     \	 /`   \
						--	 \,	/      \,
						--	 ARREADY     RREADY	    Slave

					WHEN r_addr_s =>
						addr_v    := s_axi_ri.araddr;
						arready_v := '1'; -- ready for transfer
						state     := r_data_s;

					WHEN r_data_s =>
					arready_v := '0';         -- done with addr
						------ ADD ADDRESS BASED CONDITIONS FOR COMMAND AND DATA REG
						IF addr_v = x"40000008" THEN
							rdata_v(15 downto 0)    := command_reg_S; -- Slave command_red output
							rdata_v(31 downto 16)   := data_reg_S;    -- Slave Data_reg output
							rresp_v   := "00";          -- okay
						ELSIF addr_v = x"40000012"  THEN
							rdata_v(15 downto 0)   := data_reg_S;      -- Slave Data_reg output
							rdata_v(31 downto 16)   := x"1212";        -- Constant
							rresp_v   := "00";       -- okay
						ELSE
							rdata_v   := (others=>'0'); -- TEST DATA
							rresp_v   := "00";        -- okay
						END IF;
						IF s_axi_ri.rready = '1' THEN -- master ready
							rvalid_v := '1';              -- data is valid
							state    := idle_s;
						END IF;

						--  AWVALID ---> WVALID	 _	       BREADY   Master
						--     \    --__ /`   \	  --__		/`
						--	    \,  	/--__  \,     --_  /
						--	 AWREADY     -> WREADY ---> BVALID	    Slave

					WHEN w_addr_s =>
						addr_v    := s_axi_wi.awaddr;
						awready_v := '1'; -- ready for transfer
						state     := w_data_s;

					WHEN w_data_s =>
						awready_v := '0'; -- done with addr
						wready_v  := '1'; -- ready for data

						IF s_axi_wi.wvalid = '1' THEN                       
							IF addr_v = x"40000000" THEN                  
								command_reg_M       <= s_axi_wi.wdata(15 DOWNTO 0);  -- Latch_in Master command word
								command_reg_M_valid <= '1';
								wstrb_v := s_axi_wi.wstrb;
								bresp_v := "00"; -- transfer OK
								state   := w_resp_s;
							ELSIF addr_v = x"40000004" THEN
								data_reg_M <= s_axi_wi.wdata(15 DOWNTO 0);            -- Latch_in Master Data word
								data_reg_M_valid <= '1';
								wstrb_v := s_axi_wi.wstrb;
								bresp_v := "00"; -- transfer OK
								state   := w_resp_s;
							ELSE
								wstrb_v := s_axi_wi.wstrb;
								bresp_v := "00"; -- transfer OK
								state   := w_resp_s;
							END IF;
						--ELSE
						--	command_reg_M_valid <= '0';
						--	data_reg_M_valid    <= '0';
						END IF;

					WHEN w_resp_s =>
						command_reg_M_valid <= '0';
						data_reg_M_valid    <= '0';
						wready_v := '0';              -- done with write
						IF s_axi_wi.bready = '1' THEN -- master ready
							bvalid_v := '1';      -- response valid
							state    := idle_s;
						END IF;
				END CASE;
			END IF;
		END IF;

		s_axi_ro.arready <= arready_v;
		s_axi_ro.rvalid  <= rvalid_v;
		s_axi_wo.awready <= awready_v;
		s_axi_wo.wready  <= wready_v;
		s_axi_wo.bvalid  <= bvalid_v;
		s_axi_ro.rdata   <= rdata_v;
		s_axi_ro.rresp   <= rresp_v;
		s_axi_wo.bresp   <= bresp_v;

	END PROCESS;

END RTL;
