; vim:noet:sw=8:ts=8:sts=8:ai:syn=asm68k

	include "sys.i"


; Define macro for jsr without stack RAM
bl		macro
		lea	(.ret\@,pc),a6
		bra	\1
.ret\@:
		endm

; Return from subroutine to address in A6.
rl		macro
		jmp	(a6)
		endm


; ------------------------------------------------------------------------------
; Vectors
		
	section .bss.vectors

RAMVECTORS::
		dcb.l	256

	section	.vectors

VECTORS::
		dc.l	INITIAL_SP	;  0
		dc.l	RESET		;  1
		dc.l	VEC_BUSFAULT	;  2
		dc.l	VEC_ADERROR	;  3
		dc.l	VEC_ILLINSTR	;  4
		dc.l	VEC_DIVBY0	;  5
		dc.l	VEC_CHK		;  6
		dc.l	VEC_TRAPV	;  7
		dc.l	VEC_PRIVVIOL	;  8
		dc.l	VEC_TRACE	;  9
		dc.l	VEC_LINE1010	; 10
		dc.l	VEC_LINE1111	; 11
		dc.l	VEC_RESERVED	; 12
		dc.l	VEC_CCPUVIOL	; 13 - Coprocessor Protocol Violation (68020/30)
		dc.l	VEC_FMTERROR	; 14
		dc.l	VEC_UNINIVEC	; 15
	rept	8
		dc.l	VEC_RESERVED	; 16-23
	endr
		dc.l	VEC_SPURIOUS	; 24
		dc.l	VEC_AUTOVEC1	; 25
		dc.l	VEC_AUTOVEC2	; 26
		dc.l	VEC_AUTOVEC3	; 27
		dc.l	VEC_AUTOVEC4	; 28
		dc.l	VEC_AUTOVEC5	; 29
		dc.l	VEC_AUTOVEC6	; 30
		dc.l	VEC_AUTOVEC7	; 31
		dc.l	VEC_TRAP0	; 32
		dc.l	VEC_TRAP1	; 33
		dc.l	VEC_TRAP2	; 34
		dc.l	VEC_TRAP3	; 35
		dc.l	VEC_TRAP4	; 36
		dc.l	VEC_TRAP5	; 37
		dc.l	VEC_TRAP6	; 38
		dc.l	VEC_TRAP7	; 39
		dc.l	VEC_TRAP8	; 40
		dc.l	VEC_TRAP9	; 41
		dc.l	VEC_TRAP10	; 42
		dc.l	VEC_TRAP11	; 43
		dc.l	VEC_TRAP12	; 44
		dc.l	VEC_TRAP13	; 45
		dc.l	VEC_TRAP14	; 46
		dc.l	VEC_TRAP15	; 47
	rept	8
		dc.l	VEC_RESERVED	; 48-55 - Floating point exceptions
	endr
		dc.l	VEC_RESERVED	; 56 - MMU Configuration Error (68030)
		dc.l	VEC_RESERVED	; 57 - MMU Illegal Operation Error (68851)
		dc.l	VEC_RESERVED	; 58 - MMU Access Violation (68851)
	rept	5
		dc.l	VEC_RESERVED	; 59-63 - Reserved
	endr

	rept	192
		dc.l	VEC_RESERVED	; 192-255 - User deviced vectors
	endr

;-------------------------------------------------------------------------------
; Global Variables

	section .bss

INT1_CHECK:
		ds.l	1
INT2_CHECK:
		ds.l	1
INT3_CHECK:
		ds.l	1
INT4_CHECK:
		ds.l	1
INT5_CHECK:
		ds.l	1
INT6_CHECK:
		ds.l	1
INT7_CHECK:
		ds.l	1

;-------------------------------------------------------------------------------
; ENTRY POINT

	section	.text

RESET:

		; Try enabling instruction cache
		;move.l	#$00008000,d0
		;movec	d0,cacr

;DELAY10000:
		;move.l	#4,d2	; Wait for a bit (for some reason)
;.1:
		;dbra	d2,.1

		; Try reading continously from RAM

		;moveq.l	#$FF,d0			; Load count 256
		;move.l	#RAMVECTORS,a0		; RAM base in a0
;.loop:
		;move.l	(a0)+,d2		; move a word
		;dbra	d0,.loop		; decrement d0 and loop (executes 256 times)

INIT_DUART:
		
		movea.l	#DUART_BASE,a0
		move.b	#$00,IMR(a0)		; reset interrupt mask register

		; Initialize channel A
		move.b	#$10,CRA(a0)		; reset mode register pointer
		move.b	#$13,MR1A(a0)		; no parity, 8 bits/char
		move.b	#$07,MR2A(a0)		; 1 stop bit
		move.b	#$BB,CSRA(a0)		; 9600-baud XMIT and RCV
		move.b	#$20,CRA(a0)		; reset the receiver
		move.b	#$30,CRA(a0)		; reset the transmitter
		move.b	#$05,CRA(a0)		; enable XMIT and RCV

		; Initialize channel B
		move.b	#$10,CRB(a0)		; reset mode register pointer
		move.b	#$13,MR1B(a0)		; no parity, 8 bits/char
		move.b	#$07,MR2B(a0)		; 1 stop bit
		move.b	#$BB,CSRB(a0)		; 9600-baud XMIT and RCV
		move.b	#$20,CRB(a0)		; reset the receiver
		move.b	#$30,CRB(a0)		; reset the transmitter

	section .rodata

.s_welcome:	dc.b	"\r\n68040pc booting...\r\n",0
		even

	section .text

		; Welcome!
		lea	.s_welcome,a0
		bl	early_puts


 ; Skip interrupt testing and RAM test
 ;	TODO: FPGA isn't ready for interrupts
 ;	TODO: Memory test isn't stable
		bra	COPY_VECTORS

TEST_INTS:

	section .rodata

.s_int1:	dc.b	"INT1: ",0
		even
.s_int2:	dc.b	"INT2: ",0
		even
.s_int3:	dc.b	"INT3: ",0
		even
.s_int4:	dc.b	"INT4: ",0
		even
.s_int5:	dc.b	"INT5: ",0
		even
.s_int6:	dc.b	"INT6: ",0
		even
.s_int7:	dc.b	"INT7: ",0
		even

.s_int_jmp	dc.l	.s_int1
		dc.l	.s_int2
		dc.l	.s_int3
		dc.l	.s_int4
		dc.l	.s_int5
		dc.l	.s_int6
		dc.l	.s_int7

.s_checkints:	dc.b	"\r\nChecking Interrupts...\r\n",0
		even
.s_pass:	dc.b	"pass\r\n",0
		even
.s_fail:	dc.b	"FAIL!\r\n",0
		even

	section .text

		lea	.s_checkints,a0
		bl	early_puts


		move.l	#.s_int_jmp,a3		; Base address of interrupt messages
		move.l	#INT1_CHECK,a4		; Base address for interrupt check flags
		move.l	#FPGA_BASE,a5

		; Clear test bits
		clr.l	$00(a4)
		clr.l	$04(a4)
		clr.l	$08(a4)
		clr.l	$0c(a4)
		clr.l	$10(a4)
		clr.l	$14(a4)
		clr.l	$18(a4)

		; Start with interrupt 1
		moveq	#1,d1

.loop:		cmpi.l	#8,d1			; Check if we've gone past interrupt 7
		beq	.end			; If yes, we're done

		; Print "INTn: "
		move.l	(a3)+,a0		; Load address of the next interrupt message
		bl	early_puts		; Call puts function to print the message

		; Trigger interrupt
		nop				; nop to synchronize pipeline
		move.b	d1,F_INT(a5)		; Write interrupt number to trigger it
		nop				; nop to synchronize pipeline

		; Check if the interrupt was successfully handled
		move.l	(a4)+,d0		; Load the result of the interrupt test
		beq	.fail			; If 0, jump to fail

		; If we reach here, the test passed
		move.l	#.s_pass,a0		; Address of "pass\n" message
		bra	.print			; Branch to print

.fail:		move.l	#.s_fail,a0		; Address of "FAIL!\n" message

.print:		bl	early_puts		; Print result

		addq	#1,d1			; Increment interrupt number
		bra	.loop
	
.end:


TEST_MEMORY:

	section .rodata

.s_doneprint:	dc.b	"\r\nMade it out of printf!\r\n",0
		even
.s_begin:	dc.b	"\r\nTesting memory...\r\n",0
		even

	section	.text

		xref	detect_memory
		xref	test_memory

		move.l	#.s_begin,a0
		bl	early_puts

		move.l	#SRAM,a0		; Base address

		; TODO: Using printf requires working RAM. I just hope RAM works so I can see something here
		move.l	a0,-(sp)
		pea	str_membase
		jsr	printf_
		move.l	#.s_doneprint,a0
		bl	early_puts
		add.l	#4,sp
		move.l	(sp)+,a0		; Get membase back from stack

		jsr	detect_memory		; A0 input - memory base address
		; Now A1 has the detected end of memory
		
		; Print the supposed end of memory
		move.l	a1,-(sp)
		pea	str_memdet
		jsr	printf_
		add.l	#4,sp
		move.l	(sp)+,a1		; Get memory end back from stack

		; Test memory
		jsr	test_memory
		tst.l	d0
		beq	.memtest_ok
		pea	str_fail
		bra	.print_result
.memtest_ok:	
		pea	str_ok
.print_result:
		pea	str_memtest_s
		jsr	printf_
		add.l	#8,sp
		
COPY_VECTORS:
		moveq.l	#$FF,d0			; Load count 256 - 1 vectors
		move.l	#VECTORS,a0		; ROM base in a0
		move.l	#RAMVECTORS,a1		; RAM base in a1
.loop:
		move.l	(a0)+,(a1)+		; move a vector
		dbra	d0,.loop		; decrement d0 and loop (executes 256 times)

		; now we can move the VBR to SRAM
		move.l	#RAMVECTORS,a0
		movec.l	a0,vbr


FPU_IDENT:

	section	.rodata

.s_cpu:		dc.b	"CPU: Motorola 68%s040\r\n",0
		even
.s_cpu_lc:	dc.b	"LC",0
		even
.s_cpu_b:	dc.b	0
		even

	section	.text

		jsr	get_fpu			; d0 = 1: FPU, 0: LC (no FPU)
		move.b	d0,d0
		beq	.no_fpu
		pea	.s_cpu_b
		jmp	.print
.no_fpu:	pea	.s_cpu_lc
.print:		pea	.s_cpu
		jsr	printf_
		add.l	#8,sp

		; Enable instruction cache
		;cinva	ic
		;move.l	#$00008000,d0
		;movec	d0,cacr

		;move.l	#FPGA_BASE,d0

DIE:		bra	DIE

		even




; --------------------------------------
; early_puts - Print a string to UART A
;
; Inputs
; a0 - Address of the null-terminated string to print
; --------------------------------------
early_puts:
		movea.l	#DUART_BASE,a1		; DUART_BASE address in a0
.start:
		move.b	(a0)+,d0		; Load the next character from the 
						; string d0 and increment

		beq	.exit			; If the loaded byte is 0, exit.
.1		btst.b	#2,SRA(a1)		; Check if SR[2] is zero
		beq	.1			; If so, check again

		move.b	d0,TBA(a1)		; Move char to transmit buffer
		bra	.start
.exit:
		rl

; --------------------------------------
; puts - Print a string to UART A
;
; Inputs
; a0 - Address of the null-terminated string to print
; --------------------------------------
puts:
		move.b	(a0)+,d0		; Load the next character from the 
						; string d0 and increment

		beq	.exit			; If the loaded byte is 0, exit.
		jsr	putchar
		bra	puts
.exit
		rts


; --------------------------------------
; putchar - Print a character to UART A
;
; Inputs
; d0 - Character to print
; --------------------------------------
putchar:
		movea.l	#DUART_BASE,a0		; DUART_BASE address in a0
.1		btst.b	#2,SRA(a0)		; Check if SR[2] is zero
		beq	.1			; If so, check again

		move.b	d0,TBA(a0)		; Move char to transmit buffer
		rts

; External putchar for printf
_putchar::
		move.l	4(sp),d0
		jsr	putchar
		rts

; --------------------------------------
; print_long
;
; Inputs
; d0 - The number to print
;
; a0 is used for string operations
;---------------------------------------
print_long:

	section	.rodata

.hexdigits	dc.b	'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
		even

	section .text

		move.l	d0,d1			; Copy number to d1 to work with it
		lea	.hexdigits,a1		; Address of hex digits map
		moveq	#28,d2			; Start with the most significant digit

.loop:		move.l	d1,d3			; Copy number to d3
		lsr.l	d2,d3			; Shift right to isolate the most significant hex digit
		andi.l	#$0F,d3			; Isolate a single hex digit
		move.b	(a1,d3.w),d0		; Get ASCII character from map
		movea.l	#DUART_BASE,a0		; DUART_BASE address in a0
.1		btst.b	#2,SRA(a0)		; Check if SR[2] is zero
		beq	.1			; If so, check again

		move.b	d0,TBA(a0)		; Move char to transmit buffer

		subq.l	#4,d2			; Move to the next hex digit
		bpl	.loop			; Loop until all digits are processed

		rl

; --------------------------------------
; get_fpu - Determine if an FPU is present
; REQUIRES VBR be located in RAM
;
; Outputs
; d0 - 1 if FPU, 0 if no FPU
; --------------------------------------
get_fpu:
		link	a5,#0
		movec	vbr,a1			; get VBR
		move.w	sr,-(sp)		; save IPL
		move.l	$2c(a1),-(sp)		; save old trap vector (Line F)
		or.w	#$700,sr		; disable interrupts
		move.l	#.1,$2c(a1)		; set .1 as new vector
		move.l	sp,a0			; save stack pointer
		moveq.l	#0,d0			; value with exception
		nop
		fnop				; is an FPU present
		nop
		moveq.l	#1,d0			; value if we come here
.1		move.l	a0,sp			; restore stack pointer
		move.l	(sp)+,$2c(a1)		; restore trap vector
		move.w	(sp)+,sr		; restore IPL
		unlk	a5
		rts

VEC_AUTOVEC1:
		move.l	#1,INT1_CHECK
		rte
VEC_AUTOVEC2:
		move.l	#1,INT2_CHECK
		rte
VEC_AUTOVEC3:
		move.l	#1,INT3_CHECK
		rte
VEC_AUTOVEC4:
		move.l	#1,INT4_CHECK
		rte
VEC_AUTOVEC5:
		move.l	#1,INT5_CHECK
		rte
VEC_AUTOVEC6:
		move.l	#1,INT6_CHECK
		rte
VEC_AUTOVEC7:
		move.l	#1,INT7_CHECK
		rte

VEC_ILLINSTR:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Illegal instruction\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_BUSFAULT:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Bus fault\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_ADERROR:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Address error\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_DIVBY0:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Division by zero\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_CHK:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Check\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAPV:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: TRAPV\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_PRIVVIOL:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Privilege violation\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRACE:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trace\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_LINE1010:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Line 1010 emulator\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_LINE1111:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Line 1111 emulator\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_RESERVED:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Reserved\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_CCPUVIOL:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: CCPUVIOL\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_FMTERROR:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Format error\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_UNINIVEC:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Unitialized interrupt\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_SPURIOUS:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Spurious interrupt\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP0:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #0\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP1:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #1\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP2:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #2\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP3:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #3\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP4:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #4\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP5:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #5\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP6:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #6\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP7:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #7\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP8:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #8\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP9:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #9\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP10:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #10\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP11:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #11\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP12:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #12\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP13:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #13\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP14:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #14\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC
VEC_TRAP15:
	section .rodata

.s_VECNAME:	dc.b	"\r\nEXCEPTION: Trap #15\r\n"
		even
	section .text
		lea	.s_VECNAME,a0
		bl	early_puts
		bra	PRINT_PC

PRINT_PC:
		; Print the address which caused the exception
		move.l	2(sp),d0
		bl	print_long
		bra	DIE
		

	section .rodata

str_ok:		dc.b	"OK!",0
		even
str_fail:	dc.b	"FAILED",0
		even
str_membase:	dc.b	"Memory base: %08x\n",0
		even
str_memdet:	dc.b	"Memory end?: %08x\n",0
		even
str_memok:	dc.b	"Memory end?: %08x\n",0
		even
str_memtest_s:	dc.b	"Memory test: %s\n",0
		even
