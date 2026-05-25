transcript on
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vcom -2002 ../../rtl/memory/sdram_rom_reader.vhd
vcom -2002 ../../tb/memory/tb_sdram_rom_reader.vhd
vsim work.tb_sdram_rom_reader
run -all
quit -f
