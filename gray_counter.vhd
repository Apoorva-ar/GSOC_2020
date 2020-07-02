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
----------------------------------------------------------------------------------------------------
-- library declaration
----------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_arith.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
----------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------
entity gray_counter is

    generic (
        ADDRESS_WIDTH : integer);

    port (
        i_clk          : in  std_logic;
        i_rst          : in  std_logic;
        i_ce           : in  std_logic;
        o_bin_cnt_out  : out std_logic_vector(3 downto 0);
        o_gray_cnt_out : out std_logic_vector(3 downto 0)
        );

end gray_counter;
----------------------------------------------------------------------------------------------------
-- architecture declaration
----------------------------------------------------------------------------------------------------
architecture rtl of gray_counter is

    signal gray_count_i   : std_logic_vector(3 downto 0);
    signal binary_count_i : std_logic_vector(3 downto 0);

begin  -- rtl

    
    
    ------------------------------------------------------------------------------------------------
    -- binary count
    ------------------------------------------------------------------------------------------------
    binary_cnt_proc : process (i_clk, i_rst)
    begin  -- process binary_cnt_proc
        if i_rst = '1' then  			-- asynchronous reset (active high)
            binary_count_i(0)                        <= '1';
            binary_count_i(3 downto 1) <= (others => '0');
        elsif i_clk'event and i_clk = '1' then  -- rising clock edge
            if i_ce = '1' then
                binary_count_i                       <= binary_count_i + '1';
            end if;
        end if;
    end process binary_cnt_proc;

    ------------------------------------------------------------------------------------------------
    -- Gray counter
    ------------------------------------------------------------------------------------------------
    gray_cnt_proc : process (i_clk, i_rst)
    begin  -- process gray_cnt_proc
        if i_rst = '1' then                     -- asynchronous reset (active high)
            gray_count_i      <= (others => '0');
            o_bin_cnt_out     <= (others => '0');
        elsif i_clk'event and i_clk = '1' then  -- rising clock edge
            if i_ce = '1' then
                gray_count_i  <= binary_count_i(3) & (binary_count_i(2 downto 0) xor binary_count_i(3 downto 1));
                o_bin_cnt_out <= binary_count_i;
            end if;
        end if;
    end process gray_cnt_proc;

    o_gray_cnt_out <= gray_count_i;

end rtl;
