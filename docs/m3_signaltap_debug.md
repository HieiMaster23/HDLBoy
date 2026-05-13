# M3 SignalTap Debug Probes

This document describes the packed probes exposed by `cpu_integration_test_top`
for M3 hardware debug. Add these `stp_m3_*` nodes in SignalTap instead of the
individual `stp_debug_*` register bits.

## Clock

Use the CPU PLL clock as the SignalTap acquisition clock:

```text
pll_core:u_pll|altpll:altpll_component|pll_core_altpll:auto_generated|wire_pll1_clk[1]~clkctrl
```

This is the 4.194 MHz CPU clock.

## Primary Probes

## Beginner Scalar Probes

Quartus II 13.0 may not show packed buses as a range in Node Finder. For the
first SignalTap bring-up, search for these scalar names instead:

```text
stp_heartbeat_0
stp_heartbeat_1
stp_heartbeat_2
stp_heartbeat_3
stp_heartbeat_4
stp_heartbeat_5
stp_heartbeat_6
stp_heartbeat_7
stp_key0_raw
stp_key1_raw
stp_key2_raw
stp_key3_raw
stp_reset_button_n
stp_key_reset_n
stp_system_reset_n
stp_pll_locked
stp_reset_internal
```

The `stp_heartbeat_*` probes are the free-running debug counter bits. If they
toggle in SignalTap, the acquisition clock and analyzer path are working.

### `stp_m3_flow[31:0]`

```text
[31:16] debug_pc
[15:11] debug_state
[10:8]  checkpoint_index
[7]     final_passed
[6]     checker_failed
[5]     unsupported_opcode
[4]     mem_write
[3]     mem_read
[2]     internal reset
[1]     system_reset_n
[0]     key_reset_n
```

### `stp_m3_bus[31:0]`

```text
[31:16] mem_addr
[15:8]  mem_data_out
[7:0]   mem_data_in
```

### `stp_m3_regs_ab[31:0]`

```text
[31:24] A
[23:16] F
[15:8]  B
[7:0]   C
```

### `stp_m3_regs_dehl[31:0]`

```text
[31:24] D
[23:16] E
[15:8]  H
[7:0]   L
```

### `stp_m3_sp_flags[31:0]`

```text
[31:16] SP
[15:12] led_pattern
[11:0]  reserved
```

### `stp_m3_reset_keys[31:0]`

```text
[31:24] free-running debug counter
[23:20] raw key_n pins
[19]    reset_n pin
[18]    key_reset_n
[17]    system_reset_n
[16]    pll_locked
[15]    internal reset
[14:0]  reserved
```

## Recommended Initial Capture

Add only these nodes first:

```text
stp_m3_flow[31:0]
stp_m3_bus[31:0]
stp_m3_reset_keys[31:0]
```

Optional second pass:

```text
stp_m3_regs_ab[31:0]
stp_m3_regs_dehl[31:0]
stp_m3_sp_flags[31:0]
```

## Expected Checkpoints

The integration ROM writes checkpoint values to address `0xFF80`:

```text
01
04
08
09
0D
```

Then it writes the pass code to `0xFF81`:

```text
A5
```

At the end of a passing run:

```text
stp_m3_flow[7] = 1       -- final_passed
stp_m3_flow[6] = 0       -- checker_failed
stp_m3_flow[5] = 0       -- unsupported_opcode
stp_m3_reset_keys[16] = 1 -- pll_locked
```

## Trigger

Start with a simple trigger:

```text
stp_m3_flow[4] = 1  -- mem_write
```

For more precise captures, trigger on writes to the LED checkpoint register:

```text
stp_m3_flow[4] = 1              -- mem_write
stp_m3_bus[31:16] = 0xFF80      -- mem_addr
```

Use 256 or 512 samples when possible.
