; mul_test.asm
; Simple hardware multiplication test for numcoproc/mul_unit
; Shows PROD_LO on Hex0 and PROD_HI on Hex1 (both in hex)

        ORG 0

START:
        ; Clear HEX displays
        LOADI 0
        OUT   Hex0
        OUT   Hex1

        ; ---------------------------------------------------
        ; Load operands from memory into coprocessor registers
        ; A = 0x92, B = 0x93
        ; ---------------------------------------------------
        LOAD  MULT_A
        OUT   A_IO           ; op_a

        LOAD  MULT_B
        OUT   B_IO           ; op_b

        ; ---------------------------------------------------
        ; Start UNSIGNED multiply:
        ; CTRL bits: bit0=START, bit1=OP_DIV, bit2=SIGNED
        ;   START = 1
        ;   OP_DIV = 0   (multiply, not divide)
        ;   SIGNED = 0   (unsigned)
        ; => CTRL = 0b0000000000000001 = 0x0001
        ; ---------------------------------------------------
        LOADI &H0001
        OUT   CTRL_STATUS

WAIT_BUSY:
        ; Poll BUSY (bit 1) until it clears
        IN    CTRL_STATUS
        AND   BUSY_MASK       ; 0x0002
        JNZ   WAIT_BUSY       ; stay while BUSY != 0

        ; ---------------------------------------------------
        ; Read results:
        ;   LO at 0x94
        ;   HI at 0x95
        ; ---------------------------------------------------
        IN    LO_IO
        STORE PROD_LO

        IN    HI_IO
        STORE PROD_HI

        ; ---------------------------------------------------
        ; Display results:
        ;   PROD_LO -> Hex0
        ;   PROD_HI -> Hex1
        ; ---------------------------------------------------
        LOAD  PROD_LO
        OUT   Hex0

        LOAD  PROD_HI
        OUT   Hex1

DONE:
        JUMP  DONE            ; sit here forever


; ----------------------------------------------------------
; Data section
; Change MULT_A / MULT_B to test other values.
; Example: MULT_A = 15 (0x000F), MULT_B = 5 (0x0005)
; Expected product: 15 * 5 = 75 = 0x004B
;   PROD_LO = 0x004B
;   PROD_HI = 0x0000
; ----------------------------------------------------------
        ORG  &H100

MULT_A:    DW &H000F          ; 15
MULT_B:    DW &H0005          ; 5

PROD_LO:   DW 0
PROD_HI:   DW 0

BUSY_MASK: DW &H0002          ; bit 1 = BUSY


; ----------------------------------------------------------
; I/O address constants (matching numcoproc.vhd)
; ----------------------------------------------------------
Hex0:        EQU 004          ; 7-seg display 0
Hex1:        EQU 005          ; 7-seg display 1

CTRL_STATUS: EQU &H90         ; CTRL / STATUS register
A_IO:        EQU &H92         ; op_a (A)
B_IO:        EQU &H93         ; op_b (B)
LO_IO:       EQU &H94         ; prod_lo
HI_IO:       EQU &H95         ; prod_hi
