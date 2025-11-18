; Test DIV peripheral: 15 / 5 = 3 (quotient), 0 (remainder)

        ORG &H0

START:
        ; --- Write operands ---
        LOADI 15           ; ACC <- 15
        OUT   &H92         ; NUM (dividend) = 15

        LOADI 5            ; ACC <- 5
        OUT   &H93         ; DEN (divisor) = 5

        ; --- Start division: unsigned, OP_DIV=1, START=1 ---
        ; CTRL bits:
        ;   bit0 = START
        ;   bit1 = OP_DIV
        ;   bit2 = SIGNED (0 = unsigned here)
        ; So CTRL = 0b...0000000000000011 = 0x0003
        LOADI &H0003
        OUT   &H90         ; CTRL/STATUS write: start DIV

WAIT:
        ; --- Poll BUSY (bit 1) until it clears ---
        IN    &H90         ; ACC <- STATUS
        AND   &H0002       ; mask BUSY bit (bit 1)
        JNZ   WAIT         ; keep looping while BUSY != 0

        ; --- Read quotient and remainder ---
        IN      &H96       ; ACC <- QUO (quotient)
        STORE   RESULT_QUO

        IN      &H97       ; ACC <- REM (remainder)
        STORE   RESULT_REM

DONE:
        JUMP DONE          ; spin forever

; ------------------------------------------------
; Data section
; ------------------------------------------------
        ORG &H100
RESULT_QUO:  &H0000        ; expected 0x0003 (15 / 5 = 3)
RESULT_REM:  &H0000        ; expected 0x0000 (remainder)
