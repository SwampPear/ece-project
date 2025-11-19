; Calculator.asm
; Six-function calculator using SCOMP + arithmetic coprocessor
;
; Modes (selected with SW0–3, SW8 when SW9 is down):
;   1   : Set ARG_A
;   2   : Set ARG_B
;   4   : Set current operation
;   8   : Outputs view
;   256 : Clear all
;
; Operations (CURR_OP):
;   1   : ADD
;   2   : SUB
;   4   : MULT (signed)
;   5   : MULT_UNSIGNED
;   8   : DIV (signed)
;   9   : DIV_UNSIGNED
;   16  : SQRT
;   32  : SIN/COS
;
; Coprocessor CTRL / STATUS bits (address 0x90):
;   bit 0 : START       (write 1 to begin operation)
;   bit 1 : OP_DIV      (1 = DIV, 0 = MUL unless SQRT/CORDIC)
;   bit 2 : SIGNED      (1 = signed MUL/DIV, 0 = unsigned)
;   bit 3 : OP_SQRT     (1 = SQRT)
;   bit 4 : OP_CORDIC   (1 = CORDIC)
; Status (overlaid in low bits on read):
;   bit 0 : ST_DONE
;   bit 1 : ST_BUSY
;   bit 2 : ST_DIV0     (divide-by-zero)

        ORG 0

CLEAR:  ; Reset arguments, outputs, and state
        LOADI 0
        STORE ARG_A
        STORE ARG_B
        STORE OUT_A
        STORE OUT_B
        STORE CURR_OP
        STORE CURR_LED_VALUE
        STORE CURR_OUT
        STORE CURR_MODE
        STORE CURR_CTRL

        CALL DISPLAY_LEDS
        CALL DISPLAY_OP
        CALL DISPLAY_OUT

OUTPUTS:
        ; --- Output phase: SW0 toggles between OUT_A and OUT_B ---
        IN    SWITCHES
        AND   BIT0_MASK
        ADDI  -1
        JZERO OUTPUTS_B          ; if SW0=1, show OUT_B

        ; Show OUT_A
        LOADI LED_OUTA
        STORE CURR_LED_VALUE
        LOAD  OUT_A
        STORE CURR_OUT
        JUMP  OUTPUTS_D

OUTPUTS_B:
        ; Show OUT_B
        LOADI LED_OUTB
        STORE CURR_LED_VALUE
        LOAD  OUT_B
        STORE CURR_OUT

OUTPUTS_D:
        CALL DISPLAY_LEDS
        CALL DISPLAY_OUT

        ; If SW9 is down, go to mode select
        CALL CHECK_SW9
        JZERO SET_MODE            ; AC=0 => SW9=1 => stay in outputs
        JUMP OUTPUTS

; ----------------------------------------------------------------------
; MODE SELECTION STATE
; ----------------------------------------------------------------------
SET_MODE:
        LOADI LED_SETM
        STORE CURR_LED_VALUE
        CALL DISPLAY_LEDS

        CALL CHECK_SW9
        JNZ  MODE_CONFIRMED       ; when SW9 is lowered (AC!=0), confirm mode
        JUMP SET_MODE

MODE_CONFIRMED:
        ; Read mode from switches (mask lower 9 bits)
        IN    SWITCHES
        AND   CURR_OP_MASK
        STORE CURR_MODE

        ; If next mode is OUTPUTS (8), go there immediately
        LOAD  CURR_MODE
        ADDI  -8
        JZERO OUTPUTS

        ; If next mode is CLEAR (256), go there immediately
        LOAD  CURR_MODE
        ADDI  -64
        ADDI  -64
        ADDI  -64
        ADDI  -64                 ; -64*4 = -256
        JZERO CLEAR

        ; Otherwise wait for SW9 to go back up before entering mode
        JUMP  WAITING

; ----------------------------------------------------------------------
; MODE: SET ARG_A
; ----------------------------------------------------------------------
SET_ARG_A:
        LOADI LED_SETA
        STORE CURR_LED_VALUE
        CALL DISPLAY_LEDS

        IN    SWITCHES
        AND   CURR_OP_MASK
        OUT   Hex0                ; echo switches on Hex0 while setting

        CALL CHECK_SW9
        JNZ  ARG_A_CONFIRMED      ; when SW9 is lowered
        JUMP SET_ARG_A

ARG_A_CONFIRMED:
        LOADI 0
        STORE CURR_MODE

        IN    SWITCHES
        AND   CURR_OP_MASK
        STORE ARG_A
        JUMP  WAITING

; ----------------------------------------------------------------------
; MODE: SET ARG_B
; ----------------------------------------------------------------------
SET_ARG_B:
        LOADI LED_SETB
        STORE CURR_LED_VALUE
        CALL DISPLAY_LEDS

        IN    SWITCHES
        AND   CURR_OP_MASK
        OUT   Hex0                ; echo switches on Hex0 while setting

        CALL CHECK_SW9
        JNZ  ARG_B_CONFIRMED
        JUMP SET_ARG_B

ARG_B_CONFIRMED:
        LOADI 0
        STORE CURR_MODE

        IN    SWITCHES
        AND   CURR_OP_MASK
        STORE ARG_B
        JUMP  WAITING

; ----------------------------------------------------------------------
; MODE: SET OPERATION
; ----------------------------------------------------------------------
SET_OP:
        LOADI LED_SETOP
        STORE CURR_LED_VALUE
        CALL DISPLAY_LEDS

        IN    SWITCHES
        AND   CURR_OP_MASK
        OUT   Hex0                ; show op code on Hex0

        CALL CHECK_SW9
        JNZ  OP_CONFIRMED
        JUMP SET_OP

OP_CONFIRMED:
        LOADI 0
        STORE CURR_MODE

        IN    SWITCHES
        AND   CURR_OP_MASK
        STORE CURR_OP
        JUMP  RUN_OP

; ----------------------------------------------------------------------
; RUN_OP: choose operation based on CURR_OP
; ----------------------------------------------------------------------
RUN_OP:
        LOADI 0
        OUT   Hex0                ; clear Hex0
        CALL  DISPLAY_OP          ; show op on Hex1

        LOAD  CURR_OP
        ADDI  -1
        JZERO OP_ADD

        LOAD  CURR_OP
        ADDI  -2
        JZERO OP_SUB

        LOAD  CURR_OP
        ADDI  -4
        JZERO OP_MULT

        LOAD  CURR_OP
        ADDI  -5
        JZERO OP_MULT

        LOAD  CURR_OP
        ADDI  -8
        JZERO OP_DIV

        LOAD  CURR_OP
        ADDI  -9
        JZERO OP_DIV

        LOAD  CURR_OP
        ADDI  -16
        JZERO OP_SQRT

        LOAD  CURR_OP
        ADDI  -32
        JZERO OP_CORDIC

        ; Unknown operation → error
        JUMP  MODE_ERROR

; ----------------------------------------------------------------------
; WAITING: wait for SW9 to go back up (mode-selection handshake)
; ----------------------------------------------------------------------
WAITING:
        LOADI 0
        STORE CURR_LED_VALUE
        OUT   Hex0
        CALL  DISPLAY_LEDS

        CALL  CHECK_SW9
        JZERO GO_NEXT             ; SW9=1 => move into chosen mode
        JUMP  WAITING

GO_NEXT:
        LOAD  CURR_MODE
        JZERO SET_MODE

        ADDI  -1
        JZERO SET_ARG_A

        LOAD  CURR_MODE
        ADDI  -2
        JZERO SET_ARG_B

        LOAD  CURR_MODE
        ADDI  -4
        JZERO SET_OP

        ; Invalid mode -> error
        JUMP  MODE_ERROR

; ----------------------------------------------------------------------
; HELPER: CHECK_SW9
;   Returns AC = 0 if SW9=1 (up), non-zero if SW9=0 (down)
; ----------------------------------------------------------------------
CHECK_SW9:
        IN    SWITCHES
        SHIFT -9                  ; move SW9 down to bit 0
        AND   BIT0_MASK           ; keep just that bit
        ADDI  -1                  ; 1→0, 0→-1
        RETURN

; ----------------------------------------------------------------------
; HELPER: SET_CTRL
;   Writes CURR_CTRL to coprocessor CTRL/STATUS
; ----------------------------------------------------------------------
SET_CTRL:
        LOAD  CURR_CTRL
        OUT   CTRL/STATUS
        RETURN

; ----------------------------------------------------------------------
; HELPER: CHECK_DONE
;   - If DIV0 flag set, jumps to MODE_ERROR (never returns)
;   - Else if BUSY=0, jumps to EXIT_WORKING_LOOP (never returns)
;   - Else returns to caller (still working)
; ----------------------------------------------------------------------
CHECK_DONE:
        IN    CTRL/STATUS
        STORE TEMP_STATUS

        ; Check DIV0 (bit 2)
        LOAD  TEMP_STATUS
        AND   STATUS_DIV0_MASK    ; 0x0004
        JNZ   MODE_ERROR          ; divide-by-zero → blink error forever

        ; Check BUSY (bit 1)
        LOAD  TEMP_STATUS
        AND   STATUS_BUSY_MASK    ; 0x0002
        JZERO EXIT_WORKING_LOOP   ; BUSY=0 → op finished
        RETURN

; ----------------------------------------------------------------------
; Delay loop using Timer
; ----------------------------------------------------------------------
DELAY:
        OUT   Timer
DELAY_L:
        IN    Timer
        ADDI  -10
        JNEG  DELAY_L
DELAY_E:
        RETURN

; ----------------------------------------------------------------------
; Display helpers
; ----------------------------------------------------------------------
DISPLAY_LEDS:
        LOAD  CURR_LED_VALUE
        OUT   LEDs
        RETURN

DISPLAY_OP:
        LOAD  CURR_OP
        OUT   Hex1
        RETURN

DISPLAY_OUT:
        LOAD  CURR_OUT
        OUT   Hex0
        RETURN

; ----------------------------------------------------------------------
; LED_WORKING_LOOP:
; snaking LEDs while waiting for coprocessor (BUSY)
; ----------------------------------------------------------------------
LED_WORKING_LOOP:
        CALL  CHECK_DONE

        LOADI 16
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY
        CALL  CHECK_DONE

        LOADI 8
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY
        CALL  CHECK_DONE

        LOADI 4
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY
        CALL  CHECK_DONE

        LOADI 2
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY
        CALL  CHECK_DONE

        LOADI 1
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY
        CALL  CHECK_DONE

        JUMP  LED_WORKING_LOOP

; ----------------------------------------------------------------------
; EXIT_WORKING_LOOP: coprocessor finished, branch by CURR_OP
; ----------------------------------------------------------------------
EXIT_WORKING_LOOP:
        LOAD  CURR_OP
        ADDI  -4
        JZERO RES_MULT

        LOAD  CURR_OP
        ADDI  -5
        JZERO RES_MULT

        LOAD  CURR_OP
        ADDI  -8
        JZERO RES_DIV

        LOAD  CURR_OP
        ADDI  -9
        JZERO RES_DIV

        LOAD  CURR_OP
        ADDI  -16
        JZERO RES_SQRT

        LOAD  CURR_OP
        ADDI  -32
        JZERO RES_CORDIC

        ; Should never happen, but be safe
        JUMP  MODE_ERROR

; ----------------------------------------------------------------------
; RESULT HANDLERS
; ----------------------------------------------------------------------
RES_MULT:
        IN    LO
        STORE OUT_A
        IN    HI
        STORE OUT_B
        JUMP  OUTPUTS

RES_DIV:
        ; DIV0 handled in CHECK_DONE already
        IN    QUO
        STORE OUT_A
        IN    REM
        STORE OUT_B
        JUMP  OUTPUTS

RES_SQRT:
        IN    SQR_OU
        STORE OUT_A
        LOADI 0
        STORE OUT_B
        JUMP  OUTPUTS

RES_CORDIC:
        IN    SIN
        STORE OUT_A
        IN    COS
        STORE OUT_B
        JUMP  OUTPUTS

; ----------------------------------------------------------------------
; LOAD_ARGS: writes ARG_A and ARG_B into coprocessor NUM/A and DEN/B
; ----------------------------------------------------------------------
LOAD_ARGS:
        LOAD  ARG_A
        OUT   ARG_AIO
        LOAD  ARG_B
        OUT   ARG_BIO
        RETURN

; ----------------------------------------------------------------------
; CPU-ONLY OPS
; ----------------------------------------------------------------------
OP_ADD:
        LOAD  ARG_A
        ADD   ARG_B
        STORE OUT_A
        LOADI 0
        STORE OUT_B
        JUMP  OUTPUTS

OP_SUB:
        LOAD  ARG_A
        SUB   ARG_B
        STORE OUT_A
        LOADI 0
        STORE OUT_B
        JUMP  OUTPUTS

; ----------------------------------------------------------------------
; OP_MULT: signed vs unsigned based on CURR_OP
;   CURR_OP=4 → signed (CTRL=5: START=1,SIGNED=1)
;   CURR_OP=5 → unsigned (CTRL=1: START=1)
; ----------------------------------------------------------------------
OP_MULT:
        CALL  LOAD_ARGS

        LOAD  CURR_OP
        ADDI  -5
        JZERO OP_MULT_UNSIGNED   ; 5 = MULT_UNSIGNED

        ; Signed multiply (op=4)
        LOADI 5                  ; START=1, SIGNED=1, OP_DIV=0
        STORE CURR_CTRL
        CALL  SET_CTRL
        JUMP  OP_MULT_C

OP_MULT_UNSIGNED:
        LOADI 1                  ; START=1, unsigned
        STORE CURR_CTRL
        CALL  SET_CTRL

OP_MULT_C:
        JUMP  LED_WORKING_LOOP

; ----------------------------------------------------------------------
; OP_DIV: signed vs unsigned based on CURR_OP
;   CURR_OP=8 → signed  (CTRL=7: START=1,OP_DIV=1,SIGNED=1)
;   CURR_OP=9 → unsigned(CTRL=3: START=1,OP_DIV=1,SIGNED=0)
; ----------------------------------------------------------------------
OP_DIV:
        CALL  LOAD_ARGS

        LOAD  CURR_OP
        ADDI  -9
        JZERO OP_DIV_UNSIGNED    ; 9 = DIV_UNSIGNED

        ; Signed divide (op=8)
        LOADI 7                  ; START=1, OP_DIV=1, SIGNED=1
        STORE CURR_CTRL
        CALL  SET_CTRL
        JUMP  OP_DIV_C

OP_DIV_UNSIGNED:
        LOADI 3                  ; START=1, OP_DIV=1, SIGNED=0
        STORE CURR_CTRL
        CALL  SET_CTRL

OP_DIV_C:
        JUMP  LED_WORKING_LOOP

; ----------------------------------------------------------------------
; OP_SQRT: unary SQRT on ARG_A
;   CTRL = 0x0009 (START=1,OP_SQRT=1)
; ----------------------------------------------------------------------
OP_SQRT:
        LOAD  ARG_A
        OUT   ARG_AIO
        LOADI 8                  ; 0b01000 → OP_SQRT
        ADDI 1                   ; + START bit → 0x0009
        STORE CURR_CTRL
        CALL  SET_CTRL
        JUMP  LED_WORKING_LOOP

; ----------------------------------------------------------------------
; OP_CORDIC: use ARG_A as angle
;   CTRL = 0x0011 (START=1,OP_CORDIC=1)
; ----------------------------------------------------------------------
OP_CORDIC:
        LOAD  ARG_A
        OUT   ARG_AIO
        LOADI 16                 ; 0b10000 → OP_CORDIC
        ADDI 1                   ; + START → 0x0011
        STORE CURR_CTRL
        CALL  SET_CTRL
        JUMP  LED_WORKING_LOOP

; ----------------------------------------------------------------------
; MODE_ERROR: blink all LEDs forever
; ----------------------------------------------------------------------
MODE_ERROR:
        LOAD  LED_ERROR
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY

        LOADI 0
        STORE CURR_LED_VALUE
        CALL  DISPLAY_LEDS
        CALL  DELAY

        JUMP  MODE_ERROR

; ----------------------------------------------------------------------
; DATA / CONSTANTS
; ----------------------------------------------------------------------
ARG_A:          DW 0
ARG_B:          DW 0
OUT_A:          DW 0
OUT_B:          DW 0
CURR_OP:        DW 0
CURR_OP_MASK:   DW &H01FF        ; mask lower 9 switch bits
BIT0_MASK:      DW &H0001

CURR_CTRL:      DW 0
CURR_OUT:       DW 0
CURR_MODE:      DW 0

CURR_LED_VALUE: DW 0
TEMP_STATUS:    DW 0

; Status masks (low bits from CTRL/STATUS read)
STATUS_BUSY_MASK: DW &H0002      ; bit 1 = BUSY
STATUS_DIV0_MASK: DW &H0004      ; bit 2 = DIV0

; LED constants
LED_SETA:   EQU 001              ; setting ARG_A
LED_SETB:   EQU 002              ; setting ARG_B
LED_SETOP:  EQU 004              ; setting operation
LED_OUTA:   EQU 008              ; displaying OUT_A
LED_OUTB:   EQU 016              ; displaying OUT_B
LED_SETM:   EQU 513              ; LED0 + LED9 for mode select
LED_ERROR:  DW  &H03FF           ; LEDs 9..0 all on

; I/O ports (SCOMP)
SWITCHES:   EQU 000
LEDs:       EQU 001
Timer:      EQU 002
Hex0:       EQU 004
Hex1:       EQU 005

; Coprocessor I/O window (0x90–0x9F)
CTRL/STATUS: EQU &H90
ARG_AIO:     EQU &H92            ; OP_A (A / NUM / SQRT / ANG)
ARG_BIO:     EQU &H93            ; OP_B (B / DEN)
LO:          EQU &H94            ; MUL_LO
HI:          EQU &H95            ; MUL_HI
QUO:         EQU &H96            ; DIV_QUO
REM:         EQU &H97            ; DIV_REM
SQR_OU:      EQU &H98            ; SQRT_OUT
SIN:         EQU &H99            ; CORDIC_SIN
COS:         EQU &H9A            ; CORDIC_COS
