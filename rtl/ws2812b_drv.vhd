library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ws2812b_pkg.all;

entity ws2812b_drv is
	generic
	(
		-- 8x8 leds
		LED_NUMBER : natural := 64;
	
		-- 20ms @ 50MHz
		REFRESH_PERIOD_CLK : natural := 1_000_000;

		-- 200us @ 50MHz
		T_RESET_CLK : natural := 10000;
	
		-- 400ns and 800ns @ 50MHz
		T0H_CLK : natural := 20; -- 400ns
		T0L_CLK : natural := 40; -- 800ns

		-- 800ns and 400ns @ 50MHz
		T1H_CLK : natural := 40;
		T1L_CLK : natural := 20
	);

	port
	(
		clk : in std_logic;
		rst_n : in std_logic;

		dout : out std_logic;

		pixel_data: in pixel_color_t;
		pixel_valid : in std_logic;

		te : out std_logic
	);
end entity;

architecture rtl of ws2812b_drv is

	-- led test pattern
	function init_frame return frame_buffer_t is
		 variable tmp : frame_buffer_t(0 to LED_NUMBER-1);
		 constant RED   : std_logic_vector(COLOR_NUM_BITS-1 downto 0) := x"000f00";
		 constant GREEN : std_logic_vector(COLOR_NUM_BITS-1 downto 0) := x"0f0000";
		 constant BLUE  : std_logic_vector(COLOR_NUM_BITS-1 downto 0) := x"00000f";
	begin
		 for i in 0 to LED_NUMBER-1 loop
			  case i mod 3 is
					when 0 =>
						 tmp(i) := RED;
					when 1 =>
						 tmp(i) := GREEN;
					when others =>
						 tmp(i) := BLUE;
			  end case;
		 end loop;

		 return tmp;
	end function;

	signal frame_buffer : frame_buffer_t(0 to LED_NUMBER-1) := init_frame;

	type drv_state_t is
	(
		IDLE,
		RESET_PULSE,
		LOAD_PIXEL,
		ALIGN_LOAD_BIT,
		LOAD_BIT,
		BIT_H,
		BIT_L
	);
	
	signal c_state : drv_state_t := IDLE;
	signal delay_cnt : natural := 0;
	
	signal bit_idx : natural := 0;
	signal led_idx : natural := 0;
	
	signal high_pulse_limit : natural := 0;
	signal low_pulse_limit : natural := 0;
	
	signal pixel_reg : pixel_color_t;
	signal pixel_idx : natural := 0;

begin

	-- handle writing do fb
	process(clk, rst_n)
	begin
		if rst_n = '0' then
			--
			-- nothing to do
		elsif rising_edge(clk) then
			if pixel_valid = '1' then
				frame_buffer(pixel_idx) <= pixel_data;
				
				if pixel_idx < LED_NUMBER-1 then
					pixel_idx <= pixel_idx + 1;
				end if;
			else
					pixel_idx <= 0;
			end if;
		end if;
	end process;

	-- handle ws2812b protocol and timings
	process(clk, rst_n)
	begin
		if rst_n = '0' then
			
			delay_cnt <= 0;
			led_idx <= 0;
			bit_idx <= 0;
			c_state <= IDLE;
			dout <= '0';
			
		elsif rising_edge(clk) then

			case c_state is
				when IDLE =>				
					if delay_cnt = REFRESH_PERIOD_CLK-1 then
						c_state <= RESET_PULSE;
						delay_cnt <= 0;
						led_idx <= 0;
						bit_idx <= 0;
						dout <= '0';
					else
						delay_cnt <= delay_cnt + 1;
					end if;

				when RESET_PULSE =>
					if delay_cnt = T_RESET_CLK-1 then
						delay_cnt <= 0;
						c_state <= LOAD_PIXEL;
						dout <= '1';
					else
						delay_cnt <= delay_cnt + 1;
					end if;
					
				when LOAD_PIXEL =>
					pixel_reg <= frame_buffer(led_idx);
					c_state <= LOAD_BIT;

				when ALIGN_LOAD_BIT =>
					c_state <= LOAD_BIT;

				when LOAD_BIT =>
						if pixel_reg(COLOR_NUM_BITS-1-bit_idx) = '1' then
							high_pulse_limit <= T1H_CLK-2;
							low_pulse_limit <= T1L_CLK;
						else
							high_pulse_limit <= T0H_CLK-2;
							low_pulse_limit <= T0L_CLK;
						end if;

						c_state <= BIT_H;
						dout <= '1';

				when BIT_H =>
					if delay_cnt = high_pulse_limit-1 then
						delay_cnt <= 0;
						dout <= '0';
						c_state <= BIT_L;
					else
						delay_cnt <= delay_cnt + 1;
					end if;

				when BIT_L =>
					if delay_cnt = low_pulse_limit-1 then
						delay_cnt <= 0;

						if bit_idx = COLOR_NUM_BITS-1 then
							bit_idx <= 0;

							if led_idx < LED_NUMBER-1 then
								led_idx <= led_idx + 1;
								c_state <= LOAD_PIXEL;
							else
								c_state <= IDLE;
							end if;
						else
							bit_idx <= bit_idx + 1;
							c_state <= ALIGN_LOAD_BIT;
						end if;

						dout <= '1';
					else
						delay_cnt <= delay_cnt + 1;
					end if;
			end case;
		end if;
	end process;

	te <= '1' when c_state = IDLE and delay_cnt < REFRESH_PERIOD_CLK/2 else '0';

end architecture;
