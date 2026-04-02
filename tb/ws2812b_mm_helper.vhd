library ieee;
use ieee.std_logic_1164.all;

library work;
use work.utils_pkg.all;


package ws2812b_mm_helper is

	constant LED_NUMBER : natural := 8;

	constant ADDR_WIDTH_BITS : natural := clog2(LED_NUMBER+16#10#);
	constant ADDR_MSB_BIT : natural := ADDR_WIDTH_BITS-1;

	procedure mm_readreg(
		signal clk : in std_logic;
		signal addr : out std_logic_vector(ADDR_MSB_BIT downto 0);
		signal readena : out std_logic;
		signal readdata : in std_logic_vector(31 downto 0);
		regaddr : in std_logic_vector(ADDR_MSB_BIT downto 0);
		variable data : out std_logic_vector(31 downto 0));
		
	procedure mm_writereg(
		signal clk : in std_logic;
		signal addr : out std_logic_vector(ADDR_MSB_BIT downto 0);
		signal writeena : out std_logic;
		signal writedata : out std_logic_vector(31 downto 0);
		regaddr : in std_logic_vector(ADDR_MSB_BIT downto 0);
		data : in std_logic_vector(31 downto 0));

end package;

package body ws2812b_mm_helper is

	procedure mm_readreg(
		signal clk : in std_logic;
		signal addr : out std_logic_vector(ADDR_MSB_BIT downto 0);
		signal readena : out std_logic;
		signal readdata : in std_logic_vector(31 downto 0);
		regaddr : in std_logic_vector(ADDR_MSB_BIT downto 0);
		variable data : out std_logic_vector(31 downto 0)) is
	begin
		addr <= regaddr;
		readena <= '1';
		wait until rising_edge(clk);
		data := readdata;
		readena <= '0';
		wait until rising_edge(clk);
	end procedure;
	
	procedure mm_writereg(
		signal clk : in std_logic;
		signal addr : out std_logic_vector(ADDR_MSB_BIT downto 0);
		signal writeena : out std_logic;
		signal writedata : out std_logic_vector(31 downto 0);
		regaddr : in std_logic_vector(ADDR_MSB_BIT downto 0);
		data : in std_logic_vector(31 downto 0)) is
	begin
		addr <= regaddr;
		writedata <= data;
		writeena <= '1';
		wait until rising_edge(clk);
		writeena <= '0';
		wait until rising_edge(clk);
	end procedure;	

end package body;
