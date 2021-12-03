#ifdef __arm__

#include "YM2203/YM2203.i"

	.global soundInit
	.global soundReset
	.global VblSound2
	.global setMuteSoundGUI
	.global setMuteSoundGame
	.global VLMData_W
	.global YM2203_0
	.global YM0_Run
	.global YM0_R
	.global YM0_W
	.global soundRamR
	.global soundRamW

	.extern pauseEmulation


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
soundInit:
	.type soundInit STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldmfd sp!,{lr}
//	bx lr

;@----------------------------------------------------------------------------
soundReset:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0				;@ No irq func
	ldr ymptr,=YM2203_0
	bl ym2203Reset			;@ Sound
	ldr ymptr,=YM2203_0
	ldr r0,=VLM_R
	str r0,[ymptr,#ayPortBInFptr]
	ldr r0,=VLM_W
	str r0,[ymptr,#ayPortAOutFptr]
	ldmfd sp!,{lr}
	bx lr

;@----------------------------------------------------------------------------
setMuteSoundGUI:
	.type   setMuteSoundGUI STT_FUNC
;@----------------------------------------------------------------------------
	ldr r1,=pauseEmulation		;@ Output silence when emulation paused.
	ldrb r0,[r1]
	strb r0,muteSoundGUI
	bx lr
;@----------------------------------------------------------------------------
setMuteSoundGame:			;@ For System E ?
;@----------------------------------------------------------------------------
	strb r0,muteSoundGame
	bx lr
;@----------------------------------------------------------------------------
VblSound2:					;@ r0=length, r1=pointer
;@----------------------------------------------------------------------------
;@	mov r11,r11
	stmfd sp!,{r0,r1,r4,lr}

	ldr r2,muteSound
	cmp r2,#0
	bne silenceMix

	ldr r1,pcmPtr0
	ldr ymptr,=YM2203_0
	bl ym2203Mixer

	ldmfd sp,{r0}
	ldr r1,pcmPtr1
	mov r2,r0,lsr#2
	ldr r0,=vlm5030Chip
	ldr r0,[r0]
	blx vlm5030_update_callback

	ldmfd sp,{r0,r1}
	ldr r12,pcmPtr0
	ldr r3,pcmPtr1
wavloop:
	ldrsh r4,[r3],#2

	ldrsh r2,[r12],#2
	add r2,r4,r2,asr#4
	mov r2,r2,asr#1
	strh r2,[r1],#2

	ldrsh r2,[r12],#2
	add r2,r4,r2,asr#4
	mov r2,r2,asr#1
	strh r2,[r1],#2

	ldrsh r2,[r12],#2
	add r2,r4,r2,asr#4
	mov r2,r2,asr#1
	strh r2,[r1],#2

	ldrsh r2,[r12],#2
	add r2,r4,r2,asr#4
	mov r2,r2,asr#1
	strh r2,[r1],#2

	subs r0,r0,#4
	bhi wavloop

	ldmfd sp!,{r0,r1,r4,lr}
	bx lr

silenceMix:
	ldmfd sp!,{r0,r1,r4}
	mov r12,r0
	mov r2,#0
silenceLoop:
	subs r12,r12,#1
	strhpl r2,[r1],#2
	bhi silenceLoop

	ldmfd sp!,{lr}
	bx lr


;@----------------------------------------------------------------------------
YM0_Run:
;@----------------------------------------------------------------------------
	mov r0,#230
	ldr ymptr,=YM2203_0
	b ym2203Run
;@----------------------------------------------------------------------------
VLM_R:
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}
	ldr r0,=vlm5030Chip
	ldr r0,[r0]
	blx VLM5030_BSY
	cmp r0,#0
	movne r0,#1
	ldmfd sp!,{r3,pc}
;@----------------------------------------------------------------------------
VLM_W:
;@----------------------------------------------------------------------------
	mov r1,r0
	ldr r0,=vlm5030Chip
	ldr r0,[r0]
	stmfd sp!,{r0,r1,r3,lr}

	mov r1,r1,lsr#3
	and r1,r1,#1
	ldr r3,=vlmBase
	ldr r3,[r3]
	add r1,r3,r1,lsl#16
	mov r2,#0x10000				;@ ROM size
	blx VLM5030_set_rom

	ldmfd sp,{r0,r1}
	mov r1,r1,lsr#6
	and r1,r1,#1
	blx VLM5030_RST

	ldmfd sp,{r0,r1}
	mov r1,r1,lsr#5
	and r1,r1,#1
	blx VLM5030_ST

	ldmfd sp!,{r0,r1}
	mov r1,r1,lsr#4
	and r1,r1,#1
	blx VLM5030_VCU

	ldmfd sp!,{r3,pc}
;@----------------------------------------------------------------------------
VLMData_W:
;@----------------------------------------------------------------------------
	mov r1,r0
	ldr r0,=vlm5030Chip
	ldr r0,[r0]
	stmfd sp!,{r3,lr}
	blx VLM5030_WRITE8
	ldmfd sp!,{r3,pc}
;@----------------------------------------------------------------------------
YM0_R:
;@----------------------------------------------------------------------------
	bic r1,r12,#0x0001
	cmp r1,#0x1000
	bne soundRamR
	tst r12,#1
	ldr ymptr,=YM2203_0
	bne ym2203DataR
	b ym2203StatusR
;@----------------------------------------------------------------------------
YM0_W:
;@----------------------------------------------------------------------------
	bic r1,r12,#0x0001
	cmp r1,#0x1000
	bne soundRamW
	tst r12,#1
	ldr ymptr,=YM2203_0
	bne ym2203DataW
	b ym2203IndexW
;@----------------------------------------------------------------------------
soundRamR:					;@ Ram read (0x0000-0x07FF / 0x2000-0x27FF)
;@----------------------------------------------------------------------------
	tst r12,#0x1800
	bxne lr
	bic r1,r12,#0x3F800
	ldr r2,=SOUND_RAM
	ldrb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
soundRamW:					;@ Ram write (0x0000-0x07FF / 0x2000-0x27FF)
;@----------------------------------------------------------------------------
	tst r12,#0x1800
	bxne lr
	bic r1,r12,#0x3F800
	ldr r2,=SOUND_RAM
	strb r0,[r2,r1]
	bx lr

;@----------------------------------------------------------------------------
pcmPtr0:	.long WAVBUFFER
pcmPtr1:	.long WAVBUFFER+0x800

muteSound:
muteSoundGUI:
	.byte 0
muteSoundGame:
	.byte 0
	.space 2

	.section .bss
	.align 2
YM2203_0:
	.space ymSize
WAVBUFFER:
	.space 0x1000
;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
