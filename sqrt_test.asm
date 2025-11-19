; sqrt_test.asm
; Simple hardware sqrt test for numcoproc/sqrt_unit
; Shows ROOT on Hex0 and original input on Hex1 (both in hex)

        ORG 0

START:
        ; Clear HEX displays
        LOADI 0
        OUT   Hex0
        OUT   Hex1

        ; ---------------------------------------------------
        ; Load operand from memory into coprocessor register
        ; SQRT input uses OP_A at 0x92
        ; ---------------------------------------------------
        LOAD  SQRT_IN_VAL
        OUT   IN_IO            ; write to OP_A / SQRT input

        ; ---------------------------------------------------
        ; Start SQRT:
        ; CTRL bits: bit0=START, bit1=OP_DIV, bit2=SIGNED,
        ;            bit3=OP_SQRT, bit4=OP_CORDIC
        ;   START   = 1  (bit0)
        ;   OP_SQRT = 1  (bit3)
        ;   OP_DIV  = 0
        ;   SIGNED  = 0 (ignored for SQRT)
        ;   OP_CORDIC = 0
        ; => CTRL = 0b0000000000001001 = 0x0009
        ; ---------------------------------------------------
        LOADI &H0009
        OUT   CTRL_STATUS

WAIT_BUSY:
        ; Poll BUSY (bit 1) until it clears
        IN    CTRL_STATUS
        AND   BUSY_MASK         ; 0x0002
        JNZ   WAIT_BUSY         ; stay while BUSY != 0

        ; ---------------------------------------------------
        ; Read result:
        ;   SQRT_OUT at 0x98
        ; sqrt_unit outputs integer sqrt in low 8 bits
        ; ---------------------------------------------------
        IN    SQRT_OUT_IO
        STORE ROOT

        ; ---------------------------------------------------
        ; Display results:
        ;   ROOT      -> Hex0
        ;   SQRT_IN   -> Hex1
        ; ---------------------------------------------------
        LOAD  ROOT
        OUT   Hex0

        LOAD  SQRT_IN_VAL
        OUT   Hex1

DONE:
        JUMP  DONE              ; sit here forever


; ----------------------------------------------------------
; Data section
; Change SQRT_IN_VAL to test other values.
; Example: SQRT_IN_VAL = 0x0049 (73 decimal)
; sqrt(73) = 8 (0x0008), since 8^2=64 and 9^2=81
; ----------------------------------------------------------
        ORG  &H100

SQRT_IN_VAL: DW &H0049          ; test value (73)
ROOT:        DW 0

BUSY_MASK:   DW &H0002          ; bit 1 = BUSY


; ----------------------------------------------------------
; I/O address constants (matching numcoproc.vhd)
; ----------------------------------------------------------
Hex0:        EQU 004            ; 7-seg display 0
Hex1:        EQU 005            ; 7-seg display 1

CTRL_STATUS: EQU &H90           ; CTRL / STATUS register
IN_IO:       EQU &H92           ; OP_A (SQRT input)
SQRT_OUT_IO: EQU &H98           ; SQRT_OUT (result)
