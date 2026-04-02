vlib work
vmap work work

vcom ../../rtl/utils_pkg.vhd
vcom ../../rtl/ws2812b_pkg.vhd
vcom ../../tb/ws2812b_mm_helper.vhd

vcom ../../rtl/ws2812b_drv.vhd
vcom ../../rtl/ws2812b_mm.vhd

vcom ../../tb/ws2812b_mm_tb.vhd

vsim work.ws2812b_mm_tb

add wave *

run 2 us
