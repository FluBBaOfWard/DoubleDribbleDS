#ifdef __arm__

#include "Shared/EmuSettings.h"
#include "ARM6809/ARM6809mac.h"
#include "K005849/K005849.i"

	.global emuFlags
	.global romNum
//	.global scaling
	.global cartFlags
	.global romStart
	.global mainCpu
	.global vromBase0
	.global vromBase1
	.global promBase
	.global vlmBase
	.global bankReg
	.global EMU_RAM
	.global SOUND_RAM
	.global ROM_Space

	.global machineInit
	.global loadCart
	.global m6809Mapper
	.global updateBankReg


	.syntax unified
	.arm

	.section .rodata
	.align 2

rawRom:
/*
// Main CPU
	.incbin "ddribble/690c03.bin"
// CPU 1
	.incbin "ddribble/690c02.bin"
// CPU 2
	.incbin "ddribble/690b01.bin"
// GFX 1
	.incbin "ddribble/690a05.bin"
	.incbin "ddribble/690a06.bin"
// GFX 2
	.incbin "ddribble/690a10.bin"
	.incbin "ddribble/690a09.bin"
	.incbin "ddribble/690a08.bin"
	.incbin "ddribble/690a07.bin"
// PROMs
	.incbin "ddribble/690a11.i15"
// VLM Data
	.incbin "ddribble/690a04.bin"
// pld
	.incbin "ddribble/pal10l8-007553.bin"
*/
/*
	.incbin "ddribble/ebs_11-19.c19"
	.incbin "ddribble/eb_11-19.c12"
	.incbin "ddribble/master_sound.a6"
	.incbin "ddribble/v1a.e12"
	.incbin "ddribble/01a.e11"
	.incbin "ddribble/v1b.e13"
	.incbin "ddribble/01b.d14"
	.incbin "ddribble/v2a00.i13"
	.incbin "ddribble/v2a10.h13"
	.incbin "ddribble/v2b00.i12"
	.incbin "ddribble/v2b10.h12"
	.incbin "ddribble/02a00.i11"
	.incbin "ddribble/02a10.h11"
	.incbin "ddribble/02b00_11-4.i8.bin"
	.incbin "ddribble/02b10.h8"
	.incbin "ddribble/6301-1.i15"
	.incbin "ddribble/voice_00.e7"
	.incbin "ddribble/voice_10.d7"
	.incbin "ddribble/pal10l8-007553.bin"
*/
	.align 2
;@----------------------------------------------------------------------------
machineInit: 	;@ Called from C
	.type   machineInit STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	bl gfxInit
//	bl ioInit
	bl soundInit
	bl cpuInit

	ldmfd sp!,{lr}
	bx lr

	.section .ewram,"ax"
	.align 2
;@----------------------------------------------------------------------------
loadCart: 		;@ Called from C:  r0=rom number, r1=emuflags
	.type   loadCart STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}
	str r0,romNum
	str r1,emuFlags

//	ldr r7,=rawRom
	ldr r7,=ROM_Space
								;@ r7=rombase til end of loadcart so DON'T FUCK IT UP
//	str r7,romStart				;@ Set rom base
//	add r0,r7,#0x20000			;@ 0x20000
//	str r0,vromBase0			;@ Gfx1
//	add r0,r0,#0x40000
//	str r0,vromBase1			;@ Gfx2
//	add r0,r0,#0x80000
//	str r0,promBase				;@ Colour prom
//	add r0,r0,#0x100
//	str r0,vlmBase				;@ VLM rom data

;@----------------------------------------------------------------------------
	ldr r4,=MEMMAPTBL_
	ldr r5,=RDMEMTBL_
	ldr r6,=WRMEMTBL_
	adr r8,pageMappings

	mov r0,#0
	ldr r2,=mem6809R0
	ldr r3,=bank_W
tbLoop1:
	add r1,r7,r0,lsl#13
	bl initMappingPage
	add r0,r0,#1
	cmp r0,#0x08
	bne tbLoop1

	ldr r3,=rom_W
tbLoop2:
	add r1,r7,r0,lsl#13
	bl initMappingPage
	add r0,r0,#1
	cmp r0,#0x88
	bne tbLoop2

	ldmfd r8!,{r0-r3}
tbLoop3:
	bl initMappingPage
	add r0,r0,#1
	cmp r0,#0x100
	bne tbLoop3

	mov r9,#7
tbLoop4:
	ldmfd r8!,{r0-r3}
	bl initMappingPage
	subs r9,r9,#1
	bne tbLoop4


	bl gfxReset
	bl ioReset
	bl soundReset
	bl cpuReset

	ldr r0,=vlm5030Chip
	ldr r0,[r0]
	ldr r1,vlmBase
	mov r2,#0x10000				;@ ROM size
	blx VLM5030_set_rom

	ldmfd sp!,{r4-r11,lr}
	bx lr


;@----------------------------------------------------------------------------
pageMappings:
	.long 0x88, emptySpace, empty_R, empty_W				;@ Empty
	.long 0xF8, EMU_RAM, mem6809R0, ram_W					;@ RAM
	.long 0xF9, SOUND_RAM, IO_R, IO_W						;@ Sound RAM
	.long 0xFA, SOUND_RAM, YM0_R, YM0_W						;@ Sound RAM
	.long 0xFC, emptySpace, empty_R, VLMData_W				;@ VLM write
	.long 0xFD, emuRAM1, k005885Ram_1R, k005885Ram_1W		;@ GFX RAM
	.long 0xFE, emuRAM0, k005885Ram_0R, k005885Ram_0W		;@ GFX RAM
	.long 0xFF, emptySpace, k005885_0R, k005885_0W			;@ IO
;@----------------------------------------------------------------------------
initMappingPage:	;@ r0=page, r1=mem, r2=rdMem, r3=wrMem
;@----------------------------------------------------------------------------
	str r1,[r4,r0,lsl#2]
	str r2,[r5,r0,lsl#2]
	str r3,[r6,r0,lsl#2]
	bx lr

;@----------------------------------------------------------------------------
//	.section itcm
;@----------------------------------------------------------------------------

;@----------------------------------------------------------------------------
updateBankReg:
	.type   updateBankReg STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{m6809ptr,lr}
	ldrb r1,bankReg
	mov r0,#0x10
	ldr m6809ptr,=m6809CPU0
	bl m6809Mapper
	ldmfd sp!,{m6809ptr,pc}
;@----------------------------------------------------------------------------
bank_W:						;@ Write ROM bank address, CPU0
;@----------------------------------------------------------------------------
	cmp addy,#0x8000
	bne rom_W
	and r1,r0,#0x07
	strb r1,bankReg
	mov r0,#0x10
;@----------------------------------------------------------------------------
m6809Mapper:		;@ Rom paging..
;@----------------------------------------------------------------------------
	ands r0,r0,#0xFF			;@ Safety
	bxeq lr
	stmfd sp!,{r3-r8,lr}
	ldr r5,=MEMMAPTBL_
	ldr r2,[r5,r1,lsl#2]!
	ldr r3,[r5,#-1024]			;@ RDMEMTBL_
	ldr r4,[r5,#-2048]			;@ WRMEMTBL_

	mov r5,#0
	cmp r1,#0xF9
	movmi r5,#12

	add r6,m6809ptr,#m6809ReadTbl
	add r7,m6809ptr,#m6809WriteTbl
	add r8,m6809ptr,#m6809MemTbl
	b m6809MemAps
m6809MemApl:
	add r6,r6,#4
	add r7,r7,#4
	add r8,r8,#4
m6809MemAp2:
	add r3,r3,r5
	sub r2,r2,#0x2000
m6809MemAps:
	movs r0,r0,lsr#1
	bcc m6809MemApl				;@ C=0
	strcs r3,[r6],#4			;@ readmem_tbl
	strcs r4,[r7],#4			;@ writemem_tb
	strcs r2,[r8],#4			;@ memmap_tbl
	bne m6809MemAp2

;@------------------------------------------
m6809Flush:		;@ Update cpu_pc & lastbank
;@------------------------------------------
	reEncodePC

	ldmfd sp!,{r3-r8,lr}
	bx lr

;@----------------------------------------------------------------------------

romNum:
	.long 0						;@ romnumber
romInfo:						;@ Keep emuflags/BGmirror together for savestate/loadstate
emuFlags:
	.byte 0						;@ emuflags      (label this so GUI.c can take a peek) see EmuSettings.h for bitfields
//scaling:
	.byte SCALED				;@ (display type)
	.byte 0,0					;@ (sprite follow val)
cartFlags:
	.byte 0 					;@ cartflags
	.space 3
bankReg:
	.long 0

romStart:
mainCpu:
	.long 0
vromBase0:
	.long 0
vromBase1:
	.long 0
promBase:
	.long 0
vlmBase:
	.long 0

	.section .bss
	.align 2
WRMEMTBL_:
	.space 256*4
RDMEMTBL_:
	.space 256*4
MEMMAPTBL_:
	.space 256*4
EMU_RAM:
	.space 0x2000
SOUND_RAM:
	.space 0x2000				;@ Actually 0x800
ROM_Space:
	.space 0x10012C
emptySpace:
	.space 0x2000
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
