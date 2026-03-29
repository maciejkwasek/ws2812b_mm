library ieee;
use ieee.std_logic_1164.all;

package ws2812b_pkg is

	constant COLOR_NUM_BITS : natural := 24;

	subtype pixel_color_t is std_logic_vector(COLOR_NUM_BITS-1 downto 0);
	type frame_buffer_t is array (natural range <>) of pixel_color_t;

end package;
