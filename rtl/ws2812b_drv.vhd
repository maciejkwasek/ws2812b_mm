library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ws2812b_pkg.all;

--
--
--
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

		te : out std_logic;

		brightness : unsigned(7 downto 0)
	);
end entity;

--
--
--
architecture rtl of ws2812b_drv is

	type gamma_table_t is array (0 to 255) of std_logic_vector(7 downto 0);

	type drv_state_t is
	(
		IDLE,
		RESET_PULSE,
		LOAD_PIXEL1,
		LOAD_PIXEL2,
		LOAD_PIXEL3,
		ALIGN_LOAD_BIT,
		LOAD_BIT,
		BIT_H,
		BIT_L
	);

	constant gamma22_lut : gamma_table_t :=
	(
		0=>x"00", 1=>x"00", 2=>x"00", 3=>x"00",
		4=>x"00", 5=>x"00", 6=>x"00", 7=>x"00",
		8=>x"00", 9=>x"00", 10=>x"00", 11=>x"00",
		12=>x"00", 13=>x"00", 14=>x"00", 15=>x"00",
		16=>x"01", 17=>x"01", 18=>x"01", 19=>x"01",
		20=>x"01", 21=>x"01", 22=>x"01", 23=>x"02",
		24=>x"02", 25=>x"02", 26=>x"02", 27=>x"03",
		28=>x"03", 29=>x"03", 30=>x"04", 31=>x"04",
		32=>x"04", 33=>x"05", 34=>x"05", 35=>x"06",
		36=>x"06", 37=>x"07", 38=>x"07", 39=>x"08",
		40=>x"09", 41=>x"09", 42=>x"0A", 43=>x"0B",
		44=>x"0B", 45=>x"0C", 46=>x"0D", 47=>x"0E",
		48=>x"0F", 49=>x"10", 50=>x"11", 51=>x"12",
		52=>x"13", 53=>x"14", 54=>x"15", 55=>x"16",
		56=>x"17", 57=>x"19", 58=>x"1A", 59=>x"1B",
		60=>x"1D", 61=>x"1E", 62=>x"1F", 63=>x"21",
		64=>x"22", 65=>x"24", 66=>x"25", 67=>x"27",
		68=>x"29", 69=>x"2A", 70=>x"2C", 71=>x"2E",
		72=>x"30", 73=>x"32", 74=>x"34", 75=>x"36",
		76=>x"38", 77=>x"3A", 78=>x"3C", 79=>x"3E",
		80=>x"40", 81=>x"42", 82=>x"45", 83=>x"47",
		84=>x"49", 85=>x"4C", 86=>x"4E", 87=>x"51",
		88=>x"53", 89=>x"56", 90=>x"58", 91=>x"5B",
		92=>x"5E", 93=>x"60", 94=>x"63", 95=>x"66",
		96=>x"69", 97=>x"6C", 98=>x"6F", 99=>x"72",
		100=>x"75", 101=>x"78", 102=>x"7B", 103=>x"7E",
		104=>x"82", 105=>x"85", 106=>x"88", 107=>x"8C",
		108=>x"8F", 109=>x"93", 110=>x"96", 111=>x"9A",
		112=>x"9D", 113=>x"A1", 114=>x"A5", 115=>x"A8",
		116=>x"AC", 117=>x"B0", 118=>x"B4", 119=>x"B8",
		120=>x"BC", 121=>x"C0", 122=>x"C4", 123=>x"C8",
		124=>x"CC", 125=>x"D0", 126=>x"D4", 127=>x"D9",
		128=>x"DD", 129=>x"E1", 130=>x"E6", 131=>x"EA",
		132=>x"EF", 133=>x"F3", 134=>x"F8", 135=>x"FC",
		136=>x"FF", 137=>x"FF", 138=>x"FF", 139=>x"FF",
		140=>x"FF", 141=>x"FF", 142=>x"FF", 143=>x"FF",
		others=>x"FF"
	);

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

	-- apply brightness setting on pixel color
	function brightnessCorrection(
		pixel : pixel_color_t;
		brightness : unsigned(7 downto 0)
	) return pixel_color_t is

		variable result : pixel_color_t := (others => '0');
		variable r : unsigned(15 downto 0) := (others => '0');
		variable g : unsigned(15 downto 0) := (others => '0');
		variable b : unsigned(15 downto 0) := (others => '0');

	begin
		-- should be 255 but x2 LE - 256 is aprox and is good enough
		r := unsigned(pixel(7 downto 0)) * brightness / 256;
		g := unsigned(pixel(15 downto 8)) * brightness / 256;
		b := unsigned(pixel(23 downto 16)) * brightness / 256;

		result(23 downto 16) := std_logic_vector(r(7 downto 0));
		result(15 downto 8) := std_logic_vector(g(7 downto 0));
		result(7 downto 0) := std_logic_vector(b(7 downto 0));

		return result;
	end function;

	-- apply gamma correction
	function gammaCorrection(pixel: pixel_color_t)
		return pixel_color_t is

		variable result : pixel_color_t := (others => '0');
		variable r : unsigned(7 downto 0) := (others => '0');
		variable g : unsigned(7 downto 0) := (others => '0');
		variable b : unsigned(7 downto 0) := (others => '0');
	begin
		r := unsigned(pixel(7 downto 0));
		g := unsigned(pixel(15 downto 8));
		b := unsigned(pixel(23 downto 16));

		result(7 downto 0) := gamma22_lut(to_integer(r));
		result(15 downto 8) := gamma22_lut(to_integer(g));
		result(23 downto 16) := gamma22_lut(to_integer(b));

		return result;
	end function;

	signal frame_buffer : frame_buffer_t(0 to LED_NUMBER-1) := init_frame;

	signal c_state : drv_state_t := IDLE;
	signal delay_cnt : natural := 0;

	signal bit_idx : natural := 0;
	signal led_idx : natural := 0;

	signal high_pulse_limit : natural := 0;
	signal low_pulse_limit : natural := 0;

	signal pixel_raw : pixel_color_t;
	signal pixel_gamma : pixel_color_t;
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
						c_state <= LOAD_PIXEL1;
						dout <= '1';
					else
						delay_cnt <= delay_cnt + 1;
					end if;
					
				when LOAD_PIXEL1 =>
					pixel_raw <= frame_buffer(led_idx);
					c_state <= LOAD_PIXEL2;

				when LOAD_PIXEL2 =>
					pixel_gamma <= gammaCorrection(pixel_raw);
					c_state <= LOAD_PIXEL3;

				when LOAD_PIXEL3 =>
					pixel_reg <= brightnessCorrection(pixel_gamma, brightness);
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
								c_state <= LOAD_PIXEL1;
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
