library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ws2812b_pkg.all;
use work.utils_pkg.all;

entity ws2812b_mm is

	generic
	(
		LED_NUMBER : natural := 64
	);
	
	port
	(
		clk : in std_logic;
		rst_n : in std_logic;
		
		dout : out std_logic;

		avs_addr : in std_logic_vector(clog2(LED_NUMBER+16#10#)-1 downto 0);

		avs_write : in std_logic;
		avs_writedata : in std_logic_vector(31 downto 0);

		avs_read : in std_logic;
		avs_readdata : out std_logic_vector(31 downto 0);

		avs_chipselect : in std_logic;
		avs_waitrequest : out std_logic
	);
end entity;

architecture rtl of ws2812b_mm is

	constant CTRLSTAT_REG : natural := 16#00#;	
	constant FB_OFFSET : natural := 16#10#;
	
	constant LAST_ADDR : natural := FB_OFFSET + LED_NUMBER - 1;

	signal pixel_data : pixel_color_t := (others => '0');
	signal pixel_valid : std_logic := '0';
	signal te : std_logic;
	
	signal shadow_fb : frame_buffer_t(0 to LED_NUMBER-1);

	signal pixel_idx : natural range 0 to LED_NUMBER-1;
	signal refresh_req : std_logic := '0';
	signal refresh_ack : std_logic := '0';

	
	type refresh_state_t is (REFRESH_IDLE, REFRESH_BUSY, REFRESH_DONE);
	signal refresh_state : refresh_state_t := REFRESH_IDLE;
	
	signal brightness : unsigned(7 downto 0) := (others => '1');

begin

	ws2812b_inst : entity work.ws2812b_drv
		generic map
		(
			LED_NUMBER => LED_NUMBER
		)
		port map
		(
			clk => clk,
			rst_n => rst_n,
			
			dout => dout,
			
			pixel_data => pixel_data,
			pixel_valid => pixel_valid,

			te => te,
			brightness => brightness

		);

		--
		-- avs write process
		--
		process(clk, rst_n)
			variable addr : natural;
		begin
			if rst_n = '0' then
				refresh_req <= '0';
			elsif rising_edge(clk) then
				if avs_chipselect = '1' and avs_write = '1' then
					addr := to_integer(unsigned(avs_addr));
					case addr is
						when CTRLSTAT_REG =>

							-- bit 0 - refresh
							refresh_req <= avs_writedata(0);

							-- bit 1 - update brightness
							if avs_writedata(1) = '1' then
								brightness <= unsigned(avs_writedata(15 downto 8));
							end if;

						-- leds data
						when others =>
							if addr >= FB_OFFSET and addr <= LAST_ADDR then
								-- write to shadow_fb
								shadow_fb(addr-FB_OFFSET) <= avs_writedata(COLOR_NUM_BITS-1 downto 0);
							end if;
					end case;
				end if;
				
				-- clear req when refresh is completed
				if refresh_ack = '1' and refresh_req = '1' then
					refresh_req <= '0';
				end if;
			end if;
		end process;

		--
		-- avs read process
		--
		process(
			avs_chipselect,
			avs_read,
			avs_addr,
			refresh_req,
			brightness
		)
			variable addr : natural;
		begin
			avs_readdata <= (others => '0');
			if avs_chipselect = '1' and avs_read = '1' then
				addr := to_integer(unsigned(avs_addr));
				case addr is
					when CTRLSTAT_REG =>
						avs_readdata(0) <= refresh_req;
						avs_readdata(15 downto 8) <= std_logic_vector(brightness);
						avs_readdata(27 downto 16) <= std_logic_vector(to_unsigned(LED_NUMBER, 12));

					when others =>
						avs_readdata <= (others => '0');
				end case;
			end if;
		end process;
		
		avs_waitrequest <= '0';
		
		--
		-- refresh process
		--
		process(clk, rst_n)
		begin
			if rst_n = '0' then

				pixel_valid <= '0';
				pixel_idx <= 0;
				refresh_state <= REFRESH_IDLE;

			elsif rising_edge(clk) then
			
					pixel_valid <= '0';
					
					case refresh_state is
						when REFRESH_IDLE =>
							if refresh_req = '1' and te = '1' then
								refresh_state <= REFRESH_BUSY;
								pixel_idx <= 0;
							end if;

						when REFRESH_BUSY =>
							pixel_data <= shadow_fb(pixel_idx);
							pixel_valid <= '1';
							
							if pixel_idx = LED_NUMBER-1 then
								refresh_state <= REFRESH_DONE;
							else
								pixel_idx <= pixel_idx + 1;
							end if;

						when REFRESH_DONE =>
							if refresh_req = '0' then
								refresh_state <= REFRESH_IDLE;
							end if;
					end case;
			end if;
		end process;
		
		refresh_ack <= '1' when refresh_state = REFRESH_DONE else '0';

end architecture;
