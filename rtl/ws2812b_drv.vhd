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

	constant gamma_table : gamma_table_t :=
	(
		0=>x"00", 1=>x"00", 2=>x"00", 3=>x"01",
		4=>x"01", 5=>x"01", 6=>x"02", 7=>x"02",
		8=>x"02", 9=>x"03", 10=>x"03", 11=>x"03",
		12=>x"03", 13=>x"04", 14=>x"04", 15=>x"04",
		16=>x"05", 17=>x"05", 18=>x"06", 19=>x"06",
		20=>x"07", 21=>x"07", 22=>x"08", 23=>x"08",
		24=>x"09", 25=>x"09", 26=>x"0A", 27=>x"0A",
		28=>x"0B", 29=>x"0B", 30=>x"0B", 31=>x"0C",
		32=>x"0C", 33=>x"0D", 34=>x"0D", 35=>x"0E",
		36=>x"0E", 37=>x"0F", 38=>x"10", 39=>x"10",
		40=>x"11", 41=>x"11", 42=>x"12", 43=>x"13",
		44=>x"13", 45=>x"14", 46=>x"14", 47=>x"14",
		48=>x"15", 49=>x"15", 50=>x"16", 51=>x"16",
		52=>x"16", 53=>x"17", 54=>x"17", 55=>x"18",
		56=>x"18", 57=>x"18", 58=>x"19", 59=>x"19",
		60=>x"1A", 61=>x"1A", 62=>x"1B", 63=>x"1B",
		64=>x"1B", 65=>x"1C", 66=>x"1C", 67=>x"1D",
		68=>x"1D", 69=>x"1E", 70=>x"1E", 71=>x"1F",
		72=>x"20", 73=>x"20", 74=>x"21", 75=>x"21",
		76=>x"22", 77=>x"22", 78=>x"23", 79=>x"23",
		80=>x"24", 81=>x"25", 82=>x"25", 83=>x"26",
		84=>x"27", 85=>x"27", 86=>x"28", 87=>x"28",
		88=>x"29", 89=>x"2A", 90=>x"2A", 91=>x"2B",
		92=>x"2C", 93=>x"2C", 94=>x"2D", 95=>x"2E",
		96=>x"2F", 97=>x"2F", 98=>x"30", 99=>x"31",
		100=>x"31", 101=>x"32", 102=>x"33", 103=>x"34",
		104=>x"35", 105=>x"35", 106=>x"36", 107=>x"37",
		108=>x"38", 109=>x"38", 110=>x"39", 111=>x"3A",
		112=>x"3B", 113=>x"3C", 114=>x"3D", 115=>x"3E",
		116=>x"3E", 117=>x"3F", 118=>x"40", 119=>x"41",
		120=>x"42", 121=>x"43", 122=>x"44", 123=>x"45",
		124=>x"46", 125=>x"46", 126=>x"47", 127=>x"48",
		128=>x"49", 129=>x"4A", 130=>x"4B", 131=>x"4C",
		132=>x"4D", 133=>x"4E", 134=>x"4F", 135=>x"50",
		136=>x"51", 137=>x"52", 138=>x"53", 139=>x"54",
		140=>x"55", 141=>x"56", 142=>x"57", 143=>x"58",
		144=>x"59", 145=>x"5B", 146=>x"5C", 147=>x"5D",
		148=>x"5E", 149=>x"5F", 150=>x"60", 151=>x"61",
		152=>x"62", 153=>x"63", 154=>x"65", 155=>x"66",
		156=>x"67", 157=>x"68", 158=>x"69", 159=>x"6A",
		160=>x"6C", 161=>x"6D", 162=>x"6E", 163=>x"6F",
		164=>x"70", 165=>x"72", 166=>x"73", 167=>x"74",
		168=>x"75", 169=>x"77", 170=>x"78", 171=>x"79",
		172=>x"7A", 173=>x"7C", 174=>x"7D", 175=>x"7E",
		176=>x"80", 177=>x"81", 178=>x"82", 179=>x"84",
		180=>x"85", 181=>x"86", 182=>x"88", 183=>x"89",
		184=>x"8A", 185=>x"8C", 186=>x"8D", 187=>x"8F",
		188=>x"90", 189=>x"91", 190=>x"93", 191=>x"94",
		192=>x"96", 193=>x"97", 194=>x"99", 195=>x"9A",
		196=>x"9C", 197=>x"9D", 198=>x"9F", 199=>x"A0",
		200=>x"A2", 201=>x"A4", 202=>x"A5", 203=>x"A7",
		204=>x"A8", 205=>x"AA", 206=>x"AC", 207=>x"AD",
		208=>x"AF", 209=>x"B1", 210=>x"B2", 211=>x"B4",
		212=>x"B6", 213=>x"B7", 214=>x"B9", 215=>x"BB",
		216=>x"BD", 217=>x"BE", 218=>x"C0", 219=>x"C2",
		220=>x"C4", 221=>x"C5", 222=>x"C7", 223=>x"C9",
		224=>x"CB", 225=>x"CC", 226=>x"CE", 227=>x"D0",
		228=>x"D2", 229=>x"D4", 230=>x"D6", 231=>x"D8",
		232=>x"D9", 233=>x"DB", 234=>x"DD", 235=>x"DF",
		236=>x"E1", 237=>x"E3", 238=>x"E5", 239=>x"E7",
		240=>x"E9", 241=>x"F1", 242=>x"F3", 243=>x"F5",
		244=>x"F7", 245=>x"F9", 246=>x"FB", 247=>x"FD",
		248=>x"FF", 249=>x"FF", 250=>x"FF", 251=>x"FF",
		252=>x"FF", 253=>x"FF", 254=>x"FF", 255=>x"FF"
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

		result(7 downto 0) := gamma_table(to_integer(r));
		result(15 downto 8) := gamma_table(to_integer(g));
		result(23 downto 16) := gamma_table(to_integer(b));

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
