#include <nds.h>

#include "DoubleDribble.h"
#include "Gui.h"
#include "Cart.h"
#include "Gfx.h"
#include "cpu.h"
#include "ARM6809/ARM6809.h"
#include "K005849/K005849.h"

static int saveRam(void *statePtr);
static int loadRam(const void *statePtr);
static int getRamSize();


int packState(void *statePtr) {
	int size = 0;
	size += saveRam(statePtr+size);
	size += k005849SaveState(statePtr+size, &k005885_1);
	size += k005849SaveState(statePtr+size, &k005885_0);
	size += m6809SaveState(statePtr+size, &m6809CPU2);
	size += m6809SaveState(statePtr+size, &m6809CPU1);
	size += m6809SaveState(statePtr+size, &m6809OpTable);
	return size;
}

void unpackState(const void *statePtr) {
	int size = 0;
	size += loadRam(statePtr+size);
	size += k005849LoadState(&k005885_1, statePtr+size);
	size += k005849LoadState(&k005885_0, statePtr+size);
	size += m6809LoadState(&m6809CPU2, statePtr+size);
	size += m6809LoadState(&m6809CPU1, statePtr+size);
	m6809LoadState(&m6809OpTable, statePtr+size);
	paletteInit(g_gammaValue);
	paletteTxAll();
}

int getStateSize() {
	int size = 0;
	size += getRamSize();
	size += k005849GetStateSize();
	size += k005849GetStateSize();
	size += m6809GetStateSize();
	size += m6809GetStateSize();
	size += m6809GetStateSize();
	return size;
}


int saveRam(void *state) {
	int size = 0;
	memcpy(state+size, EMU_RAM, sizeof(EMU_RAM));
	size += sizeof(EMU_RAM);
	memcpy(state+size, SOUND_RAM, sizeof(SOUND_RAM));
	size += sizeof(SOUND_RAM);
	memcpy(state+size, k005885Palette, sizeof(k005885Palette));
	size += sizeof(k005885Palette);
	memcpy(state+size, &bankReg, 4);
	size += 4;
	return size;
}

int loadRam(const void *state) {
	int size = 0;
	memcpy(EMU_RAM, state+size, sizeof(EMU_RAM));
	size += sizeof(EMU_RAM);
	memcpy(SOUND_RAM, state+size, sizeof(SOUND_RAM));
	size += sizeof(SOUND_RAM);
	memcpy(k005885Palette, state+size, sizeof(k005885Palette));
	size += sizeof(k005885Palette);
	memcpy(&bankReg, state+size, 4);
	size += 4;
	updateBankReg();
	return size;
}

int getRamSize() {
	return sizeof(EMU_RAM) + sizeof(SOUND_RAM) + sizeof(k005885Palette) + 4;
}

static const ArcadeRom ddribbleRoms[12] = {
	// ROM_REGION( 0x10000, "maincpu", 0 ) /* 64K for the CPU #0 */
	{"690c03.bin", 0x10000, 0x07975a58},
	// ROM_REGION( 0x10000, "cpu1", 0 ) /* 64 for the CPU #1 */
	{"690c02.bin", 0x08000, 0xf07c030a},
	// ROM_REGION( 0x10000, "cpu2", 0 )    /* 64k for the SOUND CPU */
	{"690b01.bin", 0x08000, 0x806b8453},
	// ROM_REGION( 0x40000, "gfx1", 0 )
	{"690a05.bin", 0x20000, 0x6a816d0d},
	{"690a06.bin", 0x20000, 0x46300cd0},
	// ROM_REGION( 0x80000, "gfx2", 0 )
	{"690a10.bin", 0x20000, 0x61efa222},
	{"690a09.bin", 0x20000, 0xab682186},
	{"690a08.bin", 0x20000, 0x9a889944},
	{"690a07.bin", 0x20000, 0xfaf81b3f},
	// ROM_REGION( 0x0100, "proms", 0 )
	{"690a11.i15", 0x0100, 0xf34617ad},
	// ROM_REGION( 0x20000, "vlm", 0 ) /* 128k for the VLM5030 data */
	{"690a04.bin", 0x20000, 0x1bfeb763},
	// ROM_REGION( 0x0100, "plds", 0 )
	{"pal10l8-007553.bin", 0x002c, 0x0ae5a161},
};

static const ArcadeRom ddribblepRoms[18] = {
	// ROM_REGION( 0x10000, "maincpu", 0 ) /* 64K for the CPU #0 */
	{"ebs_11-19.c19",   0x10000, 0x0a81c926},
	// ROM_REGION( 0x10000, "cpu1", 0 ) /* 64 for the CPU #1 */
	{"eb_11-19.c12",    0x08000, 0x22130292},
	// ROM_REGION( 0x10000, "cpu2", 0 )    /* 64k for the SOUND CPU */
	{"master_sound.a6", 0x08000, 0x090e3a31},
	// ROM_REGION( 0x40000, "gfx1", 0 ) /* same content as parent */
	{"v1a.e12",         0x10000, 0x53724765},
	{"01a.e11",         0x10000, 0x1ae5d725},
	{"v1b.e13",         0x10000, 0xd9dc6f1a},
	{"01b.d14",         0x10000, 0x054c5242},
	// ROM_REGION( 0x80000, "gfx2", 0 ) /* same content as parent */
	{"v2a00.i13",       0x10000, 0xa33f7d6d},
	{"v2a10.h13",       0x10000, 0x8fbc7454},
	{"v2b00.i12",       0x10000, 0xe63759bb},
	{"v2b10.h12",       0x10000, 0x8a7d4062},
	{"02a00.i11",       0x10000, 0x6751a942},
	{"02a10.h11",       0x10000, 0xbc5ff11c},
	{"02b00_11-4.i8.bin", 0x10000, 0x460aa7b4},
	{"02b10.h8",        0x10000, 0x2cc7ee28},
	// ROM_REGION( 0x0100, "proms", 0 )
	{"6301-1.i15",      0x0100, 0xf34617ad},
	// ROM_REGION( 0x20000, "vlm", 0 )  /* same content as parent */ /* 128k for the VLM5030 data */
	{"voice_00.e7",     0x10000, 0x8bd0fcf7},
	{"voice_10.d7",     0x10000, 0xb4c97494},
};

const ArcadeGame games[GAME_COUNT] = {
	{"ddribble", "Double Dribble", 12, ddribbleRoms},
	{"ddribblep", "Double Dribble (prototype?)", 18, ddribblepRoms},
};
