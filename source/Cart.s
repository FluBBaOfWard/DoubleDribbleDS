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
	.global SHARED_RAM
	.global SOUND_RAM
	.global ROM_Space

	.global machineInit
	.global loadCart
	.global updateBankReg


	.syntax unified
	.arm

	.section .text
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

	bl doCpuMappingDDribble
	bl doCpuMappingDDribbleCpu1
	bl doCpuMappingDDribbleCpu2

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
updateBankReg:
	.type   updateBankReg STT_FUNC
;@----------------------------------------------------------------------------
	ldrb r0,bankReg
	b mapBankReg
;@----------------------------------------------------------------------------
bank_W:						;@ Write ROM bank address, CPU0
;@----------------------------------------------------------------------------
	cmp addy,#0x8000
	bne rom_W
	and r0,r0,#0x07
	strb r0,bankReg
mapBankReg:
	ldr r1,mainCpu
	add r1,r1,r0,lsl#13
	sub r1,r1,#0x8000
	ldr r2,=m6809CPU0
	str r1,[r2,#m6809MemTbl+4*4]
	bx lr

;@----------------------------------------------------------------------------
doCpuMappingDDribble:
;@----------------------------------------------------------------------------
	adr r2,ddribbleMapping
	b do6809MainCpuMapping
;@----------------------------------------------------------------------------
doCpuMappingDDribbleCpu1:
;@----------------------------------------------------------------------------
	adr r2,ddribbleCpu1Mapping
	ldr r0,=m6809CPU1
	ldr r1,mainCpu
	b m6809Mapper
;@----------------------------------------------------------------------------
doCpuMappingDDribbleCpu2:
;@----------------------------------------------------------------------------
	adr r2,ddribbleCpu2Mapping
	ldr r0,=m6809CPU2
	ldr r1,mainCpu
	b m6809Mapper

;@----------------------------------------------------------------------------
ddribbleMapping:						;@ Double Dribble CPU0
	.long emptySpace, k005885_0R, k005885_0W					;@ IO
	.long GFX_RAM0, k005885Ram_0R, k005885Ram_0W				;@ GFX RAM
	.long SHARED_RAM, mem6809R2, ram_W							;@ RAM
	.long GFX_RAM1, k005885Ram_1R, k005885Ram_1W				;@ GFX RAM
	.long 4, mem6809R4, bank_W									;@ ROM
	.long 5, mem6809R5, bank_W									;@ ROM
	.long 6, mem6809R6, bank_W									;@ ROM
	.long 7, mem6809R7, bank_W									;@ ROM
;@----------------------------------------------------------------------------
ddribbleCpu1Mapping:					;@ Double Dribble CPU1
	.long SHARED_RAM, mem6809R0, ram_W							;@ RAM
	.long SOUND_RAM, DDribbleIO_R, DDribbleIO_W					;@ Sound RAM
	.long emptySpace, empty_R, empty_W							;@ Empty
	.long emptySpace, empty_R, empty_W							;@ Empty
	.long 8, mem6809R4, rom_W									;@ ROM
	.long 9, mem6809R5, rom_W									;@ ROM
	.long 0xA, mem6809R6, rom_W									;@ ROM
	.long 0xB, mem6809R7, rom_W									;@ ROM
;@----------------------------------------------------------------------------
ddribbleCpu2Mapping:					;@ Double Dribble CPU2
	.long SOUND_RAM, YM0_R, YM0_W								;@ Sound RAM
	.long emptySpace, empty_R, VLMData_W						;@ VLM write
	.long emptySpace, empty_R, empty_W							;@ Empty
	.long emptySpace, empty_R, empty_W							;@ Empty
	.long 0xC, mem6809R4, rom_W									;@ ROM
	.long 0xD, mem6809R5, rom_W									;@ ROM
	.long 0xE, mem6809R6, rom_W									;@ ROM
	.long 0xF, mem6809R7, rom_W									;@ ROM
;@----------------------------------------------------------------------------
do6809MainCpuMapping:
;@----------------------------------------------------------------------------
	ldr r0,=m6809CPU0
	ldr r1,mainCpu
;@----------------------------------------------------------------------------
m6809Mapper:		;@ Rom paging.. r0=cpuptr, r1=romBase, r2=mapping table.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r8,lr}

	add r7,r0,#m6809MemTbl
	add r8,r0,#m6809ReadTbl
	add lr,r0,#m6809WriteTbl

	mov r6,#8
m6809M2Loop:
	ldmia r2!,{r3-r5}
	cmp r3,#0x100
	addmi r3,r1,r3,lsl#13
	rsb r0,r6,#8
	sub r3,r3,r0,lsl#13

	str r3,[r7],#4
	str r4,[r8],#4
	str r5,[lr],#4
	subs r6,r6,#1
	bne m6809M2Loop
;@------------------------------------------
m6809Flush:		;@ Update cpu_pc & lastbank
;@------------------------------------------
	reEncodePC
	ldmfd sp!,{r4-r8,lr}
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
SHARED_RAM:
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
