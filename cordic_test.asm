; cordic_test.asm
; Simple hardware CORDIC test for numcoproc/cordic_unit
; Shows SIN on Hex0 and COS on Hex1 (both in hex, Q1.14)

        ORG 0

START:
        ; Clear HEX displays
        LOADI 0
        OUT   Hex0
        OUT   Hex1

        ; ---------------------------------------------------
        ; Load angle from memory into coprocessor register
        ; CORDIC angle input uses OP_A at 0x92
        ; ---------------------------------------------------
        LOAD  ANGLE
        OUT   ANG_IO          ; write theta_in (Q2.14) to OP_A

        ; ---------------------------------------------------
        ; Start CORDIC:
        ; CTRL bits: bit0=START, bit1=OP_DIV, bit2=SIGNED,
        ;            bit3=OP_SQRT, bit4=OP_CORDIC
        ;   START     = 1  (bit0)
        ;   OP_CORDIC = 1  (bit4)
        ;   OP_DIV    = 0
        ;   SIGNED    = 0 (ignored here)
        ;   OP_SQRT   = 0
        ; => CTRL = 0b0000000000010001 = 0x0011
        ; ---------------------------------------------------
        LOADI &H0011
        OUT   CTRL_STATUS

WAIT_BUSY:
        ; Poll BUSY (bit 1) until it clears
        IN    CTRL_STATUS
        AND   BUSY_MASK        ; 0x0002
        JNZ   WAIT_BUSY        ; stay while BUSY != 0

        ; ---------------------------------------------------
        ; Read results:
        ;   SIN at 0x99
        ;   COS at 0x9A
        ; Both are signed Q1.14 values
        ; ---------------------------------------------------
        IN    SIN_IO
        STORE SIN_VAL

        IN    COS_IO
        STORE COS_VAL

        ; ---------------------------------------------------
        ; Display results:
        ;   SIN   -> Hex0
        ;   COS   -> Hex1
        ; ---------------------------------------------------
        LOAD  SIN_VAL
        OUT   Hex0

        LOAD  COS_VAL
        OUT   Hex1

DONE:
        JUMP  DONE             ; sit here forever


; ----------------------------------------------------------
; Data section
; Change ANGLE to test other values.
;
; This example uses ANGLE ≈ +π/4:
;   π/4 ≈ 0.7854 rad
;   Q2.14 scaling: angle = 0.7854 * 2^14 ≈ 12868 = 0x3244
; Expected: sin ≈ cos ≈ 0.707 (about 0x2D80 in Q1.14)
; ----------------------------------------------------------
        ORG  &H100

ANGLE:     DW &H3244           ; ~45 degrees (π/4 in Q2.14)
SIN_VAL:   DW 0
COS_VAL:   DW 0

BUSY_MASK: DW &H0002           ; bit 1 = BUSY


; ----------------------------------------------------------
; I/O address constants (matching numcoproc.vhd)
; ----------------------------------------------------------
Hex0:        EQU 004           ; 7-seg display 0
Hex1:        EQU 005           ; 7-seg display 1

CTRL_STATUS: EQU &H90          ; CTRL / STATUS register
ANG_IO:      EQU &H92          ; OP_A (CORDIC angle input)
SIN_IO:      EQU &H99          ; CORDIC_SIN
COS_IO:      EQU &H9A          ; CORDIC_COS
