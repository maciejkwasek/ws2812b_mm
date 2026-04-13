library ieee;
use ieee.std_logic_1164.all;

library work;
use work.utils_pkg.all;
use work.ws2812b_mm_helper.all;

entity ws2812b_mm_tb is
end entity;

architecture sim of ws2812b_mm_tb is
	
	signal clk : std_logic;
	signal rst_n : std_logic;
	
	signal dout : std_logic;

	signal avs_addr : std_logic_vector(ADDR_MSB_BIT downto 0);

	signal avs_write : std_logic := '0';
	signal avs_writedata : std_logic_vector(31 downto 0);

	signal avs_read : std_logic := '0';
	signal avs_readdata : std_logic_vector(31 downto 0);

	signal avs_chipselect : std_logic := '0';
	signal avs_waitrequest : std_logic;

begin

	ws2812b_mm_inst : entity work.ws2812b_mm
		generic map
		(
			LED_NUMBER => LED_NUMBER
			
		)
		port map
		(
			clk => clk,
			rst_n => rst_n,
			
			dout => dout,
			
			avs_addr => avs_addr,

			avs_write => avs_write,
			avs_writedata => avs_writedata,

			avs_read => avs_read,
			avs_readdata => avs_readdata,

			avs_chipselect => avs_chipselect,
			avs_waitrequest => avs_waitrequest			
		);
		
	-- reset
   rst_n <= '0', '1' after 20 ns;
	
	-- clk
	process
	begin
		while true loop
			clk <= '1'; wait for 10 ns;
			clk <= '0'; wait for 10 ns;
		end loop;
	end process;
	
	-- test
	process
		variable readdata : std_logic_vector(31 downto 0);
	begin
	
		wait for 40 ns;
		wait until rising_edge(clk);

		avs_chipselect <= '1';
		-- read ctrl/status reg
		mm_readreg(clk, avs_addr, avs_read, avs_readdata, "00000", readdata);
		avs_chipselect <= '0';
		
		wait for 20 ns;
		wait until rising_edge(clk);
		
		avs_chipselect <= '1';
		-- fill fb
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10000", x"00111111");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10001", x"00222222");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10010", x"00333333");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10011", x"00444444");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10100", x"00555555");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10101", x"00666666");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10110", x"00777777");
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "10111", x"00888888");
		
		-- fire refresh
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "00000", x"00000001");

		loop
			-- wait for end bufs sync
			mm_readreg(clk, avs_addr, avs_read, avs_readdata, "00000", readdata);
			exit when readdata(0) = '0';
		end loop;

		-- brightness update & fire refresh
		mm_writereg(clk, avs_addr, avs_write, avs_writedata, "00000", x"00007f03");

		loop
			-- wait for end bufs sync
			mm_readreg(clk, avs_addr, avs_read, avs_readdata, "00000", readdata);
			exit when readdata(0) = '0';
		end loop;

		avs_chipselect <= '0';
	
		wait;
	end process;

end architecture;
