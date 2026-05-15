# =============================================================================
# ModelSim GUI wave setup for the Blargg CPU ROM runner
# Usage from sim/modelsim:
#   vsim -do wave_cpu_rom_runner.do
# =============================================================================

vlib work

vcom -93 ../../rtl/common/gb_types_pkg.vhd
vcom -93 ../../rtl/cpu/alu.vhd
vcom -93 ../../rtl/cpu/registers.vhd
vcom -93 ../../rtl/cpu/decoder.vhd
vcom -93 ../../rtl/cpu/cpu.vhd
vcom -93 ../../rtl/io/timer.vhd
vcom -93 ../../tb/cpu/tb_cpu_rom_runner.vhd

vsim work.tb_cpu_rom_runner

view wave
view transcript

quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Simulation Control}
add wave -noupdate sim:/tb_cpu_rom_runner/clk
add wave -noupdate sim:/tb_cpu_rom_runner/reset
add wave -noupdate sim:/tb_cpu_rom_runner/sim_done

add wave -noupdate -divider {CPU Fetch/Execute}
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_pc
add wave -noupdate sim:/tb_cpu_rom_runner/u_dut/state_reg
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/opcode_reg
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/dec_class
add wave -noupdate sim:/tb_cpu_rom_runner/u_dut/instr_complete
add wave -noupdate sim:/tb_cpu_rom_runner/unsupported_opcode
add wave -noupdate sim:/tb_cpu_rom_runner/halted

add wave -noupdate -divider {Registers}
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_a
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_f
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_b
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_c
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_d
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_e
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_h
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_l
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/u_dut/debug_sp

add wave -noupdate -divider {Memory Bus}
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/mem_addr
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/mem_data_in
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/mem_data_out
add wave -noupdate sim:/tb_cpu_rom_runner/mem_read
add wave -noupdate sim:/tb_cpu_rom_runner/mem_write

add wave -noupdate -divider {Serial Output}
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/serial_sb_reg
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/serial_sc_reg
add wave -noupdate -radix unsigned sim:/tb_cpu_rom_runner/serial_count

add wave -noupdate -divider {Simulation I/O Stubs}
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/io_ly_reg
add wave -noupdate -radix hexadecimal sim:/tb_cpu_rom_runner/io_div_reg

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Reset released} {952 ns} 0} {{First serial title byte} {21151655 ns} 0} {{Passed begins} {168144739 ns} 0}
configure wave -namecolwidth 220
configure wave -valuecolwidth 90
configure wave -signalnamewidth 1
configure wave -timelineunits ns
update

# Run only through the title printing by default. Continue with "run -all"
# in the Transcript if you want to reach the final "Passed" marker.
run 35 ms
WaveRestoreZoom {0 ns} {35 ms}
