----------------------------------------------------------------------------
--  color_matrix.vhd
--	Color Correction Matrix
--	Version 1.0
--
--  Copyright (C) 2014 H.Poetzl
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.ALL;

package vec_mat_pkg is

    type vec1_a is array (natural range <>) of
	std_logic;

    type vec2_a is array (natural range <>) of
	std_logic_vector (1 downto 0);

    type vec4_a is array (natural range <>) of
	std_logic_vector (3 downto 0);

    type vec8_a is array (natural range <>) of
	std_logic_vector (7 downto 0);

    type vec9_a is array (natural range <>) of
	std_logic_vector (8 downto 0);

    type vec10_a is array (natural range <>) of
	std_logic_vector (9 downto 0);

    type vec12_a is array (natural range <>) of
	std_logic_vector (11 downto 0);

    type vec16_a is array (natural range <>) of
	std_logic_vector (15 downto 0);

    type vec18_a is array (natural range <>) of
	std_logic_vector (17 downto 0);

    type vec24_a is array (natural range <>) of
	std_logic_vector (23 downto 0);

    type vec25_a is array (natural range <>) of
	std_logic_vector (24 downto 0);

    type vec30_a is array (natural range <>) of
	std_logic_vector (29 downto 0);

    type vec32_a is array (natural range <>) of
	std_logic_vector (31 downto 0);

    type vec48_a is array (natural range <>) of
	std_logic_vector (47 downto 0);

    subtype vec1_3  is vec1_a  (0 to 2);
    subtype vec2_3  is vec2_a  (0 to 2);
    subtype vec8_3  is vec8_a  (0 to 2);
    subtype vec9_3  is vec9_a  (0 to 2);
    subtype vec12_3 is vec12_a (0 to 2);
    subtype vec16_3 is vec16_a (0 to 2);
    subtype vec18_3 is vec18_a (0 to 2);
    subtype vec24_3 is vec24_a (0 to 2);
    subtype vec25_3 is vec25_a (0 to 2);
    subtype vec30_3 is vec30_a (0 to 2);
    subtype vec32_3 is vec32_a (0 to 2);
    subtype vec48_3 is vec48_a (0 to 2);

    type mat1_3x3  is array (0 to 2) of vec1_3;
    type mat2_3x3  is array (0 to 2) of vec2_3;
    type mat8_3x3  is array (0 to 2) of vec8_3;
    type mat9_3x3  is array (0 to 2) of vec9_3;
    type mat12_3x3 is array (0 to 2) of vec12_3;
    type mat16_3x3 is array (0 to 2) of vec16_3;
    type mat18_3x3 is array (0 to 2) of vec18_3;
    type mat24_3x3 is array (0 to 2) of vec24_3;
    type mat25_3x3 is array (0 to 2) of vec25_3;
    type mat30_3x3 is array (0 to 2) of vec30_3;
    type mat32_3x3 is array (0 to 2) of vec32_3;
    type mat48_3x3 is array (0 to 2) of vec48_3;

    subtype vec1_4  is vec1_a  (0 to 3);
    subtype vec2_4  is vec2_a  (0 to 3);
    subtype vec8_4  is vec8_a  (0 to 3);
    subtype vec9_4  is vec9_a  (0 to 3);
    subtype vec12_4 is vec12_a (0 to 3);
    subtype vec16_4 is vec16_a (0 to 3);
    subtype vec18_4 is vec18_a (0 to 3);
    subtype vec24_4 is vec24_a (0 to 3);
    subtype vec25_4 is vec25_a (0 to 3);
    subtype vec30_4 is vec30_a (0 to 3);
    subtype vec32_4 is vec32_a (0 to 3);
    subtype vec48_4 is vec48_a (0 to 3);

    type mat1_4x4  is array (0 to 3) of vec1_4;
    type mat2_4x4  is array (0 to 3) of vec2_4;
    type mat8_4x4  is array (0 to 3) of vec8_4;
    type mat9_4x4  is array (0 to 3) of vec9_4;
    type mat12_4x4 is array (0 to 3) of vec12_4;
    type mat16_4x4 is array (0 to 3) of vec16_4;
    type mat18_4x4 is array (0 to 3) of vec18_4;
    type mat24_4x4 is array (0 to 3) of vec24_4;
    type mat25_4x4 is array (0 to 3) of vec25_4;
    type mat30_4x4 is array (0 to 3) of vec30_4;
    type mat32_4x4 is array (0 to 3) of vec32_4;
    type mat48_4x4 is array (0 to 3) of vec48_4;

end vec_mat_pkg;
