# =============================================================================
# ModelSim simulation script for tb_virtual_jtag_rom_stream_core
# Usage: vsim -c -do run_virtual_jtag_rom_stream_core.do
# =============================================================================

vlib work

vcom -93 ../../rtl/io/virtual_jtag_rom_stream_core.vhd
vcom -93 ../../tb/io/tb_virtual_jtag_rom_stream_core.vhd

vsim work.tb_virtual_jtag_rom_stream_core
run -all
quit -f
