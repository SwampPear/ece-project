; div_test.asm
; Simple hardware division test for numcoproc/div_unit
; Shows QUOTIENT on Hex0 and REMAINDER on Hex1 (both in hex)

        ORG 0

START:
        ; Clear HEX displays
        LOADI 0
        OUT   Hex0
        OUT   Hex1

        ; ---------------------------------------------------
        ; Load operands from memory into coprocessor registers
        ; NUM = 0x92, DEN = 0x93
        ; ---------------------------------------------------
        LOAD  DIVIDEND
        OUT   NUM_IO          ; NUM (dividend)

        LOAD  DIVISOR
        OUT   DEN_IO          ; DEN (divisor)

        ; ---------------------------------------------------
        ; Start UNSIGNED division:
        ; CTRL bits: bit0=START, bit1=OP_DIV, bit2=SIGNED
        ;   START = 1
        ;   OP_DIV = 1
        ;   SIGNED = 0  -> unsigned division
        ; => CTRL = 0b0000000000000011 = 0x0003
        ; ---------------------------------------------------
        LOADI &H0003
        OUT   CTRL_STATUS

WAIT_BUSY:
        ; Poll BUSY (bit 1) until it clears
        IN    CTRL_STATUS
        AND   BUSY_MASK       ; 0x0002
        JNZ   WAIT_BUSY       ; stay while BUSY != 0

        ; ---------------------------------------------------
        ; Read results:
        ;   QUO at 0x96
        ;   REM at 0x97
        ; ---------------------------------------------------
        IN    QUO_IO
        STORE QUO

        IN    REM_IO
        STORE REM

        ; ---------------------------------------------------
        ; Display results:
        ;   QUO   -> Hex0
        ;   REM   -> Hex1
        ; ---------------------------------------------------
        LOAD  QUO
        OUT   Hex0

        LOAD  REM
        OUT   Hex1

DONE:
        JUMP  DONE            ; sit here forever


; ----------------------------------------------------------
; Data section
; Change DIVIDEND/DIVISOR to test other values.
; This example:  DIVIDEND = 69 (0x0045), DIVISOR = 7
; Expected: QUO = 9 (0x0009), REM = 6 (0x0006)
; ----------------------------------------------------------
        ORG  &H100

DIVIDEND:  DW &H0045          ; 69
DIVISOR:   DW &H0007          ; 7 (non-zero!)

QUO:       DW 0
REM:       DW 0

BUSY_MASK: DW &H0002          ; bit 1 = BUSY


; ----------------------------------------------------------
; I/O address constants (matching numcoproc.vhd)
; ----------------------------------------------------------
Hex0:        EQU 004          ; 7-seg display 0
Hex1:        EQU 005          ; 7-seg display 1

CTRL_STATUS: EQU &H90         ; CTRL / STATUS register
NUM_IO:      EQU &H92         ; dividend (NUM)
DEN_IO:      EQU &H93         ; divisor (DEN)
QUO_IO:      EQU &H96         ; quotient
REM_IO:      EQU &H97         ; remainder
