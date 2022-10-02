#ifndef CART_HEADER
#define CART_HEADER

#ifdef __cplusplus
extern "C" {
#endif

extern u8 bankReg;

extern u8 EMU_RAM[0x2000];
extern u8 SOUND_RAM[0x800];
extern u8 ROM_Space[0x10012C];

void machineInit(void);
void loadCart(int, int);
void ejectCart(void);
void updateBankReg(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CART_HEADER
