#ifdef __arm__

#include "Shared/nds_asm.h"
#include "Equates.h"
#include "ARM6809/ARM6809.i"
#include "K005849/K005849.i"

	.global gfxInit
	.global gfxReset
	.global paletteInit
	.global paletteTxAll
	.global refreshGfx
	.global endFrame
	.global gfxState
	.global gFlicker
	.global gTwitch
	.global g_scaling
	.global g_gfxMask
	.global vblIrqHandler
	.global yStart

	.global k005885_0
	.global k005885_1
	.global k005885Ram_0R
	.global k005885Ram_1R
	.global k005885_0R
	.global k005885_1R
	.global k005885Ram_0W
	.global k005885Ram_1W
	.global k005885_0W
	.global k005885_1W
	.global emuRAM0
	.global emuRAM1
	.global k005885Palette


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
gfxInit:					;@ Called from machineInit
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=OAM_BUFFER1			;@ No stray sprites please
	mov r1,#0x200+SCREEN_HEIGHT
	mov r2,#0x100
	bl memset_
	adr r0,scaleParms
	bl setupSpriteScaling

	ldr r0,=g_gammaValue
	ldrb r0,[r0]
	bl paletteInit				;@ Do palette mapping
	bl paletteTxAll				;@ Transfer it


	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
scaleParms:					;@  NH     FH     NV     FV
	.long OAM_BUFFER1,0x0000,0x0100,0xff01,0x0120,0xfee1
;@----------------------------------------------------------------------------
gfxReset:					;@ Called with CPU reset
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}

	ldr r0,=gfxState
	mov r1,#5					;@ 5*4
	bl memclr_					;@ Clear GFX regs

	mov r1,#REG_BASE
	ldr r0,=0x00FF				;@ start-end
	strh r0,[r1,#REG_WIN0H]
	mov r0,#SCREEN_HEIGHT		;@ start-end
	strh r0,[r1,#REG_WIN0V]
	mov r0,#0x0000
	strh r0,[r1,#REG_WINOUT]

	ldr r0,=cpu01SetNMI
	ldr r1,=cpu01SetFIRQ
	ldr r2,=cpu012SetIRQ
	ldr r3,=emuRAM0
	bl k005885Reset0
	ldr r0,=BG_GFX+0x8000		;@ Tile ram 2
	str r0,[koptr,#bgrGfxDest]
	ldr r0,=Gfx1Bg
	str r0,[koptr,#bgrRomBase]
	ldr r0,=Gfx1Obj				;@ r0=SRC SPR tileset
	str r0,[koptr,#spriteRomBase]
	mov r0,#0xF
	strb r0,[koptr,#spritePaletteOffset]

	ldr r0,[koptr,#bgrRomBase]	;@ Dest
	ldr r1,=vromBase0			;@ r1 = even bytes
	ldr r1,[r1]
	add r2,r1,#0x20000			;@ r2 = odd bytes
	mov r3,#0x40000				;@ Length
	bl convertTiles5885

	mov r0,#0
	mov r1,#0
	mov r2,#0
	ldr r3,=emuRAM1
	bl k005885Reset1
	ldr r0,=BG_GFX+0x10000		;@ Tile ram 4
	str r0,[koptr,#bgrGfxDest]
	ldr r0,=Gfx2Bg
	str r0,[koptr,#bgrRomBase]
	ldr r0,=Gfx2Obj				;@ r0=SRC SPR tileset
	str r0,[koptr,#spriteRomBase]
	ldr r0,=0x1FF
	str r0,[koptr,#spriteMask]

	ldr r0,[koptr,#bgrRomBase]
	ldr r1,=vromBase1			;@ r1 = even bytes
	ldr r1,[r1]
	add r2,r1,#0x20000			;@ r2 = odd bytes
	mov r3,#0x40000				;@ Length
	bl convertTiles5885

	ldr r0,[koptr,#spriteRomBase]
	ldr r1,=vromBase1			;@ r1 = source
	ldr r1,[r1]
	add r1,r1,#0x40000			;@ Offset to sprites
	add r2,r1,#0x20000			;@ r2 = odd bytes
	mov r3,#0x40000				;@ Length
	bl convertTiles5885

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
paletteInit:		;@ r0-r3 modified.
	.type paletteInit STT_FUNC
;@ Called by ui.c:  void paletteInit(u8 gammaVal);
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r9,lr}
	mov r1,r0					;@ Gamma value = 0 -> 4
	ldr r8,=k005885Palette
	mov r7,#0xF8
	ldr r6,=MAPPED_RGB
	mov r4,#64					;@ Double Dribble rgb, r1=R, r2=G, r3=B
noMap:							;@ Map 0rrrrrgggggbbbbb  ->  0bbbbbgggggrrrrr
	ldrb r9,[r8],#1
	ldrb r0,[r8],#1
	orr r9,r0,r9,lsl#8
	and r0,r7,r9,lsr#7			;@ Blue ready
	bl gPrefix
	mov r5,r0

	and r0,r7,r9,lsr#2			;@ Green ready
	bl gPrefix
	orr r5,r0,r5,lsl#5

	and r0,r7,r9,lsl#3			;@ Red ready
	bl gPrefix
	orr r5,r0,r5,lsl#5

	strh r5,[r6],#2
	subs r4,r4,#1
	bne noMap

	ldmfd sp!,{r4-r9,lr}
	bx lr

;@----------------------------------------------------------------------------
gPrefix:
	orr r0,r0,r0,lsr#5
;@----------------------------------------------------------------------------
gammaConvert:	;@ Takes value in r0(0-0xFF), gamma in r1(0-4),returns new value in r0(0-0x1F)
;@----------------------------------------------------------------------------
	rsb r2,r0,#0x100
	mul r3,r2,r2
	rsbs r2,r3,#0x10000
	rsb r3,r1,#4
	orr r0,r0,r0,lsl#8
	mul r2,r1,r2
	mla r0,r3,r0,r2
	mov r0,r0,lsr#13

	bx lr
;@----------------------------------------------------------------------------
paletteTxAll:				;@ Called from ui.c
	.type paletteTxAll STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r5}

	ldr r2,=promBase			;@ Proms
	ldr r2,[r2]
	ldr r3,=MAPPED_RGB
	ldr r4,=EMUPALBUFF
	add r5,r4,#512
	mov r1,#256
noMap2:
	rsb r0,r1,#0x100
	and r0,r0,#0x3F
	orr r0,r0,#0x10
	mov r0,r0,lsl#1
	ldrh r0,[r3,r0]
	strh r0,[r4],#2
	subs r1,r1,#1
	bne noMap2

	mov r1,#256
noMap3:
	ldrb r0,[r2],#1
	and r0,r0,#0x0F
	mov r0,r0,lsl#1
	ldrh r0,[r3,r0]
	strh r0,[r5],#2
	subs r1,r1,#1
	bne noMap3

	sub r5,r5,#0x20
	mov r1,#0x10
noMap4:
	rsb r0,r1,#0x30
	mov r0,r0,lsl#1
	ldrh r0,[r3,r0]
	strh r0,[r5],#2
	subs r1,r1,#1
	bne noMap4

	ldmfd sp!,{r3-r5}
	bx lr

;@----------------------------------------------------------------------------
vblIrqHandler:
	.type vblIrqHandler STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r8,lr}
	bl calculateFPS

	ldrb r0,g_scaling
	cmp r0,#UNSCALED
	moveq r6,#0
	ldrne r6,=0x80000000 + ((GAME_HEIGHT-SCREEN_HEIGHT)*0x10000) / (SCREEN_HEIGHT-1)		;@ NDS 0x2B10 (was 0x2AAB)
	ldrbeq r8,yStart
	movne r8,#0
	add r8,r8,#0x10
	mov r7,r8,lsl#16

	ldr r0,gFlicker
	eors r0,r0,r0,lsl#31
	str r0,gFlicker
	addpl r6,r6,r6,lsl#16

	ldr r5,=SCROLLBUFF
	mov r4,r5

	ldr r2,=scrollTemp
	ldr r3,=scrollTemp2
	mov r12,#SCREEN_HEIGHT
scrolLoop2:
	ldr r0,[r2,r8,lsl#2]
	ldr r1,[r3,r8,lsl#2]
	add r0,r0,r7
	add r1,r1,r7
//	mov r1,r0
	stmia r4!,{r0-r1}
	adds r6,r6,r6,lsl#16
	addcs r7,r7,#0x10000
	adc r8,r8,#1
	subs r12,r12,#1
	bne scrolLoop2



	mov r6,#REG_BASE
	strh r6,[r6,#REG_DMA0CNT_H]	;@ DMA0 stop

	add r1,r6,#REG_DMA0SAD
	mov r2,r5					;@ Setup DMA buffer for scrolling:
	ldmia r2!,{r4-r5}			;@ Read
	add r3,r6,#REG_BG0HOFS		;@ DMA0 always goes here
	stmia r3,{r4-r5}			;@ Set 1st value manually, HBL is AFTER 1st line
	ldr r4,=0x96600002			;@ noIRQ hblank 32bit repeat incsrc inc_reloaddst, 2 word
	stmia r1,{r2-r4}			;@ DMA0 go

	add r1,r6,#REG_DMA3SAD

	ldr r2,dmaOamBuffer			;@ DMA3 src, OAM transfer:
	mov r3,#OAM					;@ DMA3 dst
	mov r4,#0x84000000			;@ noIRQ 32bit incsrc incdst
	orr r4,r4,#128*2			;@ 128 sprites * 2 longwords
	stmia r1,{r2-r4}			;@ DMA3 go

	ldr r2,=EMUPALBUFF			;@ DMA3 src, Palette transfer:
	mov r3,#BG_PALETTE			;@ DMA3 dst
	mov r4,#0x84000000			;@ noIRQ 32bit incsrc incdst
	orr r4,r4,#0x100			;@ 256 words (1024 bytes)
	stmia r1,{r2-r4}			;@ DMA3 go

	ldr koptr,=k005885_1
	ldrb r5,[koptr,#sprBank]
	ldr r0,=0x0412
//	and r1,r5,#0x3				;@ Tile bank
//	add r0,r0,r1,lsl#4
	tst r5,#0x80				;@ Screen width 240/256? Tilemap width 256/512?
	orreq r0,r0,#0x4000
	strh r0,[r6,#REG_BG1CNT]
	ldrne r0,=0x08F8			;@ start-end
	ldreq r0,=0x00FF			;@ start-end
	strh r0,[r6,#REG_WIN0H]

	mov r0,#0x0013
	ldrb r1,g_gfxMask
	bic r0,r0,r1
	strh r0,[r6,#REG_WININ]

	blx scanKeys
	ldmfd sp!,{r4-r8,pc}


;@----------------------------------------------------------------------------
gFlicker:		.byte 1
				.space 2
gTwitch:		.byte 0

g_scaling:		.byte 1
g_gfxMask:		.byte 0
yStart:			.byte 0
				.byte 0
;@----------------------------------------------------------------------------
refreshGfx:					;@ Called from C when changing scaling.
	.type refreshGfx STT_FUNC
;@----------------------------------------------------------------------------
	adr koptr,k005885_0
;@----------------------------------------------------------------------------
endFrame:		;@ Called just before screen end (~line 240)	(r0-r2 safe to use)
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,koptr,lr}

	adr r0,k005885_1
	cmp koptr,r0
	ldmfdeq sp!,{r3,koptr,pc}

	ldr koptr,=k005885_1
	ldr r0,=scrollTemp2
	bl copyScrollValues
	ldr r0,=BG_GFX+0x2000
	bl convertTileMapDD
	ldr r0,tmpOamBuffer		;@ Destination
	bl convertSprites5885
;@--------------------------
	ldr r0,[koptr,#sprMemAlloc]
	ldrb r1,[koptr,#sprMemReload]
	ldr koptr,=k005885_0
	str r0,[koptr,#sprMemAlloc]
	cmp r1,#0
	strbne r1,[koptr,#sprMemReload]

	ldr r0,=scrollTemp
	bl copyScrollValues
	ldr r0,=BG_GFX
	bl convertTileMapDDFG
	ldr r0,tmpOamBuffer		;@ Destination
	add r0,r0,#64*8
	bl convertSprites5885
;@--------------------------
	ldr r0,[koptr,#sprMemAlloc]
	ldrb r1,[koptr,#sprMemReload]
	ldr koptr,=k005885_1
	str r0,[koptr,#sprMemAlloc]
	cmp r1,#0
	strbne r1,[koptr,#sprMemReload]

	ldr r0,dmaOamBuffer
	ldr r1,tmpOamBuffer
	str r0,tmpOamBuffer
	str r1,dmaOamBuffer

	mov r0,#1
	str r0,oamBufferReady

	ldr r0,=windowTop			;@ Load wtop, store in wtop+4.......load wtop+8, store in wtop+12
	ldmia r0,{r1-r3}			;@ Load with increment after
	stmib r0,{r1-r3}			;@ Store with increment before

	ldmfd sp!,{r3,koptr,lr}
	bx lr

;@----------------------------------------------------------------------------
DMA0BUFPTR:			.long 0

tmpOamBuffer:		.long OAM_BUFFER1
dmaOamBuffer:		.long OAM_BUFFER2

oamBufferReady:		.long 0
pcePaletteReady:	.long 0
;@----------------------------------------------------------------------------
k005885Reset0:			;@ r0=periodicIrqFunc, r1=frameIrqFunc, r2=frame2IrqFunc
;@----------------------------------------------------------------------------
	adr koptr,k005885_0
	b k005849Reset
;@----------------------------------------------------------------------------
k005885Reset1:			;@ r0=periodicIrqFunc, r1=frameIrqFunc, r2=frame2IrqFunc
;@----------------------------------------------------------------------------
	adr koptr,k005885_1
	b k005849Reset
;@----------------------------------------------------------------------------
k005885Ram_0R:				;@ Ram read (0x2000-0x3FFF)
;@----------------------------------------------------------------------------
	stmfd sp!,{addy,lr}
	mov r1,addy
	adr koptr,k005885_0
	bl k005885Ram_R
	ldmfd sp!,{addy,pc}
;@----------------------------------------------------------------------------
k005885Ram_1R:				;@ Ram read (0x6000-0x7FFF)
;@----------------------------------------------------------------------------
	stmfd sp!,{addy,lr}
	mov r1,addy
	adr koptr,k005885_1
	bl k005885Ram_R
	ldmfd sp!,{addy,pc}
;@----------------------------------------------------------------------------
k005885_0R:					;@ I/O read, 0x0000-0x005F
k005885_1R:					;@ I/O read, 0x0800-0x085F
;@----------------------------------------------------------------------------
	cmp addy,#0x0860
	bpl paletteRead
	stmfd sp!,{addy,lr}
	bic r1,addy,#0x0800
	tst addy,#0x0800
	adreq koptr,k005885_0
	adrne koptr,k005885_1
	bl k005885_R
	ldmfd sp!,{addy,pc}

;@----------------------------------------------------------------------------
k005885Ram_0W:				;@ Ram write (0x2000-0x3FFF)
;@----------------------------------------------------------------------------
	stmfd sp!,{addy,lr}
	mov r1,addy
	adr koptr,k005885_0
	bl k005885Ram_W
	ldmfd sp!,{addy,pc}
;@----------------------------------------------------------------------------
k005885Ram_1W:				;@ Ram write (0x6000-0x7FFF)
;@----------------------------------------------------------------------------
	stmfd sp!,{addy,lr}
	mov r1,addy
	adr koptr,k005885_1
	bl k005885Ram_W
	ldmfd sp!,{addy,pc}
;@----------------------------------------------------------------------------
k005885_0W:					;@ I/O write  (0x0000-0x005F)
k005885_1W:					;@ I/O write  (0x0800-0x085F)
;@----------------------------------------------------------------------------
	cmp addy,#0x0860
	bpl paletteWrite
	stmfd sp!,{addy,lr}
	bic r1,addy,#0x0800
	tst addy,#0x0800
	adreq koptr,k005885_0
	adrne koptr,k005885_1
	bl k005885_W
	ldmfd sp!,{addy,pc}

;@----------------------------------------------------------------------------
paletteRead:
;@----------------------------------------------------------------------------
	subs r1,addy,#0x1800
	bmi empty_IO_R
	cmp r1,#0x80
	bpl empty_IO_R
	ldr r2,=k005885Palette
	ldrb r0,[r2,r1]
	bx lr

;@----------------------------------------------------------------------------
paletteWrite:
;@----------------------------------------------------------------------------
	subs r1,addy,#0x1800
	bmi empty_IO_W
	cmp r1,#0x80
	bpl empty_IO_W
	ldr r2,=k005885Palette
	strb r0,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
k005885_0:
	.space k005849Size
k005885_1:
	.space k005849Size

gfxState:
adjustBlend:
	.long 0
windowTop:
	.long 0
wTop:
	.long 0,0,0		;@ windowtop  (this label too)   L/R scrolling in unscaled mode

	.byte 0
	.byte 0
	.byte 0
	.byte 0

	.pool
	.section .bss
	.align 2
scrollTemp:
	.space 0x100*4
scrollTemp2:
	.space 0x100*4
OAM_BUFFER1:
	.space 0x400
OAM_BUFFER2:
	.space 0x400
DMA0BUFF:
	.space 0x200
SCROLLBUFF:
	.space 0x400*2				;@ Scrollbuffer.
MAPPED_RGB:
	.space 0x2000				;@ 8 * 0x400
EMUPALBUFF:
	.space 0x400
k005885Palette:
	.space 0x80
emuRAM0:
	.space 0x2000
	.space SPRBLOCKCOUNT*4
	.space BGBLOCKCOUNT*4
emuRAM1:
	.space 0x2000
	.space SPRBLOCKCOUNT*4
	.space BGBLOCKCOUNT*4

	.align 9
Gfx1Bg:
	.space 0x20000
Gfx1Obj:
	.space 0x20000
Gfx2Bg:
	.space 0x40000
Gfx2Obj:
	.space 0x40000

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
