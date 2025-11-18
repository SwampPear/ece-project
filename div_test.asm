; Simple test for DIV peripheral: 15 / 5 = 3, remainder = 0

        ORG &H0

START:
        ; --- Write operands ---
        LOADI 15           ; ACC <- 15
        OUT   &H92         ; NUM (dividend) = 15

        LOADI 5            ; ACC <- 5
        OUT   &H93         ; DEN (divisor) = 5

        ; --- Start division (unsigned, DIV op assumed in hardware) ---
        ; Assumed CTRL/STATUS bits at 0x90:
        ;   bit 0 = START (write)
        ;   bit 1 = BUSY  (read)
        ;   bit 2 = DONE  (read, cleared on STATUS read)
        LOADI 1            ; START bit = 1
        OUT   &H90         ; CTRL/STATUS write: kick off DIV

WAIT:
        ; --- Poll BUSY until it clears ---
        IN    &H90         ; ACC <- STATUS
        AND   &H0002       ; mask BUSY bit (bit 1)
        JNZ   WAIT         ; keep looping while BUSY != 0

        ; --- Read quotient and remainder ---
        IN    &H96         ; ACC <- QUO (quotient)
        STORE RESULT_QUO

        IN    &H97         ; ACC <- REM (remainder)
        STORE RESULT_REM

DONE:
        JUMP  DONE         ; spin forever

; ------------------------------------------------
; Data section
; ------------------------------------------------
        ORG &H100
RESULT_QUO:  &H0000        ; expected 0x0003 (15 / 5 = 3)
RESULT_REM:  &H0000        ; expected 0x0000 (remainder)
