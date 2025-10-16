
CPU registers and flags
Registers
16-bit	Hi	Lo	Name/Function
AF	A	-	Accumulator & Flags
BC	B	C	BC
DE	D	E	DE
HL	H	L	HL
SP	-	-	Stack Pointer
PC	-	-	Program Counter/Pointer

As shown above, most registers can be accessed either as one 16-bit register, or as two separate 8-bit registers.
The Flags Register (lower 8 bits of AF register)
Bit	Name	Explanation
7	z	Zero flag
6	n	Subtraction flag (BCD)
5	h	Half Carry flag (BCD)
4	c	Carry flag

Contains information about the result of the most recent instruction that has affected flags.
The Zero Flag (Z)

This bit is set if and only if the result of an operation is zero. Used by conditional jumps.
The Carry Flag (C, or Cy)

Is set in these cases:

    When the result of an 8-bit addition is higher than $FF.
    When the result of a 16-bit addition is higher than $FFFF.
    When the result of a subtraction or comparison is lower than zero (like in Z80 and x86 CPUs, but unlike in 65XX and ARM CPUs).
    When a rotate/shift operation shifts out a “1” bit.

Used by conditional jumps and instructions such as ADC, SBC, RL, RLA, etc.
The BCD Flags (N, H)

These flags are used by the DAA instruction only. N indicates whether the previous instruction has been a subtraction, and H indicates carry for the lower 4 bits of the result. DAA also uses the C flag, which must indicate carry for the upper 4 bits. After adding/subtracting two BCD numbers, DAA is used to convert the result to BCD format. BCD numbers range from $00 to $99 rather than $00 to $FF. Because only two flags (C and H) exist to indicate carry-outs of BCD digits, DAA is ineffective for 16-bit operations (which have 4 digits), and use for INC/DEC operations (which do not affect C-flag) has limits.



The Game Boy’s SM83 processor possesses a CISC, variable-length instruction set. This page attempts to shed some light on how the CPU decodes the raw bytes fed into it into instructions.

The first byte of each instruction is typically called the “opcode” (for “operation code”). By noticing that some instructions perform identical operations but with different parameters, they can be grouped together; for example, inc bc, inc de, inc hl, and inc sp differ only in what 16-bit register they modify.

In each table, one line represents one such grouping. Since many groupings have some variation, the variation has to be encoded in the instruction; for example, the above four instructions will be collectively referred to as inc r16. Here are the possible placeholders and their values:
	0	1	2	3	4	5	6	7
r8	b	c	d	e	h	l	[hl]	a
r16	bc	de	hl	sp	
r16stk	bc	de	hl	af	
r16mem	bc	de	hl+	hl-	
cond	nz	z	nc	c	
b3	A 3-bit bit index
tgt3	rst's target address, divided by 8
imm8	The following byte
imm16	The following two bytes, in little-endian order

These last two are a little special: if they are present in the instruction’s mnemonic, it means that the instruction is 1 (imm8) / 2 (imm16) extra bytes long.

[hl+] and [hl-] can also be notated [hli] and [hld] respectively (as in increment and decrement).

Groupings have been loosely associated based on what they do into separate tables; those have no particular ordering, and are purely for readability and convenience. Finally, the instruction “families” have been further grouped into four “blocks”, differentiated by the first two bits of the opcode.
Block 0
	7	6	5	4	3	2	1	0
nop	0	0	0	0	0	0	0	0
	7	6	5	4	3	2	1	0
ld r16, imm16	0	0	Dest (r16)	0	0	0	1
ld [r16mem], a	0	0	Dest (r16mem)	0	0	1	0
ld a, [r16mem]	0	0	Source (r16mem)	1	0	1	0
ld [imm16], sp	0	0	0	0	1	0	0	0
	7	6	5	4	3	2	1	0
inc r16	0	0	Operand (r16)	0	0	1	1
dec r16	0	0	Operand (r16)	1	0	1	1
add hl, r16	0	0	Operand (r16)	1	0	0	1
	7	6	5	4	3	2	1	0
inc r8	0	0	Operand (r8)	1	0	0
dec r8	0	0	Operand (r8)	1	0	1
	7	6	5	4	3	2	1	0
ld r8, imm8	0	0	Dest (r8)	1	1	0
	7	6	5	4	3	2	1	0
rlca	0	0	0	0	0	1	1	1
rrca	0	0	0	0	1	1	1	1
rla	0	0	0	1	0	1	1	1
rra	0	0	0	1	1	1	1	1
daa	0	0	1	0	0	1	1	1
cpl	0	0	1	0	1	1	1	1
scf	0	0	1	1	0	1	1	1
ccf	0	0	1	1	1	1	1	1
	7	6	5	4	3	2	1	0
jr imm8	0	0	0	1	1	0	0	0
jr cond, imm8	0	0	1	Condition (cond)	0	0	0
	7	6	5	4	3	2	1	0
stop	0	0	0	1	0	0	0	0

stop is often considered a two-byte instruction, though the second byte is not always ignored.
Block 1: 8-bit register-to-register loads
	7	6	5	4	3	2	1	0
ld r8, r8	0	1	Dest (r8)	Source (r8)

Exception: trying to encode ld [hl], [hl] instead yields the halt instruction:
	7	6	5	4	3	2	1	0
halt	0	1	1	1	0	1	1	0
Block 2: 8-bit arithmetic
	7	6	5	4	3	2	1	0
add a, r8	1	0	0	0	0	Operand (r8)
adc a, r8	1	0	0	0	1	Operand (r8)
sub a, r8	1	0	0	1	0	Operand (r8)
sbc a, r8	1	0	0	1	1	Operand (r8)
and a, r8	1	0	1	0	0	Operand (r8)
xor a, r8	1	0	1	0	1	Operand (r8)
or a, r8	1	0	1	1	0	Operand (r8)
cp a, r8	1	0	1	1	1	Operand (r8)
Block 3
	7	6	5	4	3	2	1	0
add a, imm8	1	1	0	0	0	1	1	0
adc a, imm8	1	1	0	0	1	1	1	0
sub a, imm8	1	1	0	1	0	1	1	0
sbc a, imm8	1	1	0	1	1	1	1	0
and a, imm8	1	1	1	0	0	1	1	0
xor a, imm8	1	1	1	0	1	1	1	0
or a, imm8	1	1	1	1	0	1	1	0
cp a, imm8	1	1	1	1	1	1	1	0
	7	6	5	4	3	2	1	0
ret cond	1	1	0	Condition (cond)	0	0	0
ret	1	1	0	0	1	0	0	1
reti	1	1	0	1	1	0	0	1
jp cond, imm16	1	1	0	Condition (cond)	0	1	0
jp imm16	1	1	0	0	0	0	1	1
jp hl	1	1	1	0	1	0	0	1
call cond, imm16	1	1	0	Condition (cond)	1	0	0
call imm16	1	1	0	0	1	1	0	1
rst tgt3	1	1	Target (tgt3)	1	1	1
	7	6	5	4	3	2	1	0
pop r16stk	1	1	Register (r16stk)	0	0	0	1
push r16stk	1	1	Register (r16stk)	0	1	0	1
	7	6	5	4	3	2	1	0
Prefix (see block below)	1	1	0	0	1	0	1	1
	7	6	5	4	3	2	1	0
ldh [c], a	1	1	1	0	0	0	1	0
ldh [imm8], a	1	1	1	0	0	0	0	0
ld [imm16], a	1	1	1	0	1	0	1	0
ldh a, [c]	1	1	1	1	0	0	1	0
ldh a, [imm8]	1	1	1	1	0	0	0	0
ld a, [imm16]	1	1	1	1	1	0	1	0
	7	6	5	4	3	2	1	0
add sp, imm8	1	1	1	0	1	0	0	0
ld hl, sp + imm8	1	1	1	1	1	0	0	0
ld sp, hl	1	1	1	1	1	0	0	1
	7	6	5	4	3	2	1	0
di	1	1	1	1	0	0	1	1
ei	1	1	1	1	1	0	1	1

The following opcodes are invalid, and hard-lock the CPU until the console is powered off: $D3, $DB, $DD, $E3, $E4, $EB, $EC, $ED, $F4, $FC, and $FD.
$CB prefix instructions
	7	6	5	4	3	2	1	0
rlc r8	0	0	0	0	0	Operand (r8)
rrc r8	0	0	0	0	1	Operand (r8)
rl r8	0	0	0	1	0	Operand (r8)
rr r8	0	0	0	1	1	Operand (r8)
sla r8	0	0	1	0	0	Operand (r8)
sra r8	0	0	1	0	1	Operand (r8)
swap r8	0	0	1	1	0	Operand (r8)
srl r8	0	0	1	1	1	Operand (r8)
	7	6	5	4	3	2	1	0
bit b3, r8	0	1	Bit index (b3)	Operand (r8)
res b3, r8	1	0	Bit index (b3)	Operand (r8)
set b3, r8	1	1	Bit index (b3)	Operand (r8)



Comparison with 8080

The Game Boy CPU has a bit more in common with an older Intel 8080 CPU than the more powerful Zilog Z80 CPU. It is missing a handful of 8080 instructions but does support JR and almost all CB-prefixed instructions. Also, all known Game Boy assemblers use the more obvious Z80-style syntax, rather than the chaotic 8080-style syntax.

Unlike the 8080 and Z80, the Game Boy has no dedicated I/O bus and no IN/OUT opcodes. Instead, I/O ports are accessed directly by normal LD instructions, or by new LD (FF00+n) opcodes.

The sign and parity/overflow flags have been removed, as have the 12 RET, CALL, and JP instructions conditioned on them. So have EX (SP),HL (XTHL) and EX DE,HL (XCHG).
Comparison with Z80

In addition to the removed 8080 instructions, the other exchange instructions have been removed (including total absence of second register set).

All DD- and FD-prefixed instructions are missing. That means no IX- or IY-registers.

All ED-prefixed instructions are missing. That means 16-bit memory accesses are mostly missing, 16-bit arithmetic functions are heavily cut-down, and some other missing instructions. IN/OUT (C) are replaced with new LD ($FF00+C) opcodes. Block instructions are gone, but autoincrementing HL accesses are added.

The Game Boy operates approximately as fast as a 4 MHz Z80 (8 MHz in CGB double speed mode), with execution time of all instructions having been rounded up to a multiple of 4 cycles.
Moved, Removed, and Added Opcodes
Opcode	Z80	GB CPU
08	EX AF,AF	LD (nn),SP
10	DJNZ PC+dd	STOP
22	LD (nn),HL	LDI (HL),A
2A	LD HL,(nn)	LDI A,(HL)
32	LD (nn),A	LDD (HL),A
3A	LD A,(nn)	LDD A,(HL)
D3	OUT (n),A	-
D9	EXX	RETI
DB	IN A,(n)	-
DD	<IX> prefix	-
E0	RET PO	LD (FF00+n),A
E2	JP PO,nn	LD (FF00+C),A
E3	EX (SP),HL	-
E4	CALL P0,nn	-
E8	RET PE	ADD SP,dd
EA	JP PE,nn	LD (nn),A
EB	EX DE,HL	-
EC	CALL PE,nn	-
ED	<prefix>	-
F0	RET P	LD A,(FF00+n)
F2	JP P,nn	LD A,(FF00+C)
F4	CALL P,nn	-
F8	RET M	LD HL,SP+dd
FA	JP M,nn	LD A,(nn)
FC	CALL M,nn	-
FD	<IY> prefix	-
CB 3X	SLL r/(HL)	SWAP r/(HL)

Note: The unused (-) opcodes will lock up the Game Boy CPU when used.
