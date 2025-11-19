ORG &H0
START:  
	LOADI 3		; ACC <- 3
    OUT &H92	; A = 3
    
    LOADI 5		; ACC <- 3
    OUT &H93	; B = 3
    
    LOADI 5		; ACC <- 1
    OUT &H90	; CTRL/STATUS write: set START
    
WAIT:   ; --- Poll until BUSY clears (or DONE sets) ---
	IN &H90     ; ACC <- STATUS
    AND &H0001  ; mask START/BUSY/DONE as needed
    JNZ WAIT    ; keep looping while bit is non-zero
                           
    ; --- Read result LO/HI ---
    IN      &H94        ; ACC <- LO word (low 16 bits of product)
    STORE   RESULT_LO   ; store to memory
    OUT Hex1

    IN      &H95        ; ACC <- HI word (high 16 bits of product)
    STORE   RESULT_HI
    OUT Hex0

DONE:
	JUMP DONE

; Data section
ORG &H100
	RESULT_LO:  &H0000   ; expected 0x000F (15)
	RESULT_HI: 	&H0000   ; expected 0x0000


Hex0: EQU 004
Hex1: EQU 005