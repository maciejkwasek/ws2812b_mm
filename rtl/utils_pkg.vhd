package utils_pkg is

	function clog2(n : natural) return natural;

end package utils_pkg;


package body utils_pkg is

	function clog2(n : natural) return natural is
		 variable i : natural := 0;
		 variable v : natural := 1;
	begin
		 while v < n loop
			  v := v * 2;
			  i := i + 1;
		 end loop;
		 return i;
	end function;

end package body utils_pkg;