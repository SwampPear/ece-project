# SCOMP Calculator on DE10 – User Guide

This document explains how to **use the `calculator.asm` application** with your **DE10 board + SCOMP core + arithmetic coprocessor (`numcoproc`)**.

The calculator lets you:

- Enter two 16-bit operands `ARG_A` and `ARG_B`
- Choose an operation:
  - ADD, SUB (CPU)
  - MUL (signed / unsigned)
  - DIV (signed / unsigned)
  - SQRT (integer)
  - SIN/COS (CORDIC)
- Run the operation on the **hardware coprocessor**
- View the results on the **7-segment displays** and LEDs

---

## 1. Hardware / I/O Overview

The calculator assumes the following I/O mapping (matches your VHDL):

- **Switches & LEDs**
  - `SW[9:0]` → I/O address `0` (`SWITCHES`)
  - `LED[9:0]` → I/O address `1` (`LEDs`)
  - `Timer` → I/O address `2` (`Timer`)

- **7-segment**
  - `Hex0` → I/O address `4` (right 7-seg group)
  - `Hex1` → I/O address `5` (left 7-seg group)

> On a 6-digit 7-segment setup: `Hex0` controls the **right 3 digits**, `Hex1` controls the **left 3 digits**.  
> Each `OUT HexX` writes a 16-bit hex value; you’ll see its **lower 3 hex digits** on the physical display.

- **Coprocessor I/O window (`numcoproc.vhd`)**
  - `CTRL/STATUS` → `0x90`
  - `ARG_AIO`      → `0x92` (A / NUM / SQRT input / CORDIC angle)
  - `ARG_BIO`      → `0x93` (B / DEN)
  - `LO`           → `0x94` (MUL low 16 bits)
  - `HI`           → `0x95` (MUL high 16 bits)
  - `QUO`          → `0x96` (DIV quotient)
  - `REM`          → `0x97` (DIV remainder)
  - `SQR_OU`       → `0x98` (SQRT result)
  - `SIN`          → `0x99` (CORDIC sine)
  - `COS`          → `0x9A` (CORDIC cosine)

---

## 2. High-Level UI Model

- **SW9** is the “mode select / confirm” switch.
- **SW0–3, SW8** choose what you want to do when SW9 is in “mode select”.
- **Hex0** is the **main value display**:
  - In Outputs mode: shows either `OUT_A` or `OUT_B`
  - In Set modes: shows the current value you’re editing
- **Hex1** typically shows the **current operation code** (`CURR_OP`) in hex.
- **LEDs** show what the calculator is doing:
  - `LED0` → Setting ARG_A
  - `LED1` → Setting ARG_B
  - `LED2` → Setting current operation
  - `LED3` → Displaying `OUT_A`
  - `LED4` → Displaying `OUT_B`
  - `LED0 + LED9` → Mode selection screen
  - `LED4..LED0` snaking → Coprocessor is running
  - `LED9..LED0` blinking → ERROR (e.g., divide-by-zero)

---

## 3. Modes and Operation Codes

### 3.1 Mode Select (what you want to do next)

When in **mode select**, the calculator reads `CURR_MODE` from the switches:

- **SW0** = `1` → Set `ARG_A`
- **SW1** = `2` → Set `ARG_B`
- **SW2** = `4` → Set current operation
- **SW3** = `8` → Go to Outputs (view results)
- **SW8** = `256` → Clear everything

> Internally the code masks with `0x01FF`, so it’s just reading the **lower 9 bits** of the switch word.

---

### 3.2 Operation Codes (`CURR_OP`)

When you’re in **Set Operation** mode, the switches define `CURR_OP`:

- `1`  → ADD
- `2`  → SUB
- `4`  → MULT (signed)
- `5`  → MULT_UNSIGNED
- `8`  → DIV (signed)
- `9`  → DIV_UNSIGNED
- `16` → SQRT
- `32` → SIN/COS (CORDIC)

These op values are stored in `CURR_OP` and later used by `RUN_OP`:

- CPU ops:
  - `1` ADD: `OUT_A = ARG_A + ARG_B`
  - `2` SUB: `OUT_A = ARG_A – ARG_B`
- Hardware ops:
  - `4` / `5` → use the multiplier
  - `8` / `9` → use the divider
  - `16` → uses the sqrt unit
  - `32` → uses the cordic unit (sine & cosine)

`Hex1` will show this `CURR_OP` value in hex once the operation is run.

---

## 4. Step-by-Step: How to Use the Calculator

Assume **switch up = 1 (“ON”)**, **switch down = 0 (“OFF”)**.

### 4.1 On Reset

1. Load your bitstream with the SCOMP core + `numcoproc` + arithmetic units.
2. Assemble and load `calculator.asm` at address `0` (the program’s `ORG 0`).
3. Reset the CPU.
4. The `CLEAR` routine runs:
   - `ARG_A`, `ARG_B`, `OUT_A`, `OUT_B` are zeroed.
   - `Hex0` and `Hex1` should show `0000`.
   - LEDs are off.

You’re now in **Outputs mode**.

---

### 4.2 Outputs Mode (default view)

- **Hex0** shows either `OUT_A` or `OUT_B` (depending on SW0).
- **Hex1** shows `CURR_OP` (the last operation you ran).
- **LEDs:**
  - `LED3` ON → viewing `OUT_A`
  - `LED4` ON → viewing `OUT_B`

Behavior:

- If **SW0 = 0** → shows `OUT_A`
- If **SW0 = 1** → shows `OUT_B`

To **enter Mode Select**:

1. Flip **SW9 up (to 1)**.
2. The program notices SW9=1 and jumps to **SET_MODE**.

---

### 4.3 Mode Select (LED0 + LED9 ON)

In **Mode Select**, you see:

- LEDs: `LED0` and `LED9` ON (pattern `LED_SETM = 513`).
- `Hex0`/`Hex1` aren’t critical here; you’re picking a mode via switches.

Now, with **SW9 still up**:

- Set **exactly one** of the following bits (for simplicity):
  - SW0=1 → Set `ARG_A`
  - SW1=1 → Set `ARG_B`
  - SW2=1 → Set OP
  - SW3=1 → Go to Outputs
  - SW8=1 → Clear all

Then:

1. **Flip SW9 down (to 0)** to confirm the mode.

What happens next:

- If you chose:
  - **SW3 = Outputs (8)** → you go straight back to **Outputs mode**.
  - **SW8 = Clear (256)** → the program jumps to `CLEAR`, resets everything, then goes to Outputs.
- For **Set ARG_A / Set ARG_B / Set OP**, the calculator:
  - Saves `CURR_MODE`.
  - Moves to a short **WAITING** state that requires SW9 to go high again before it actually enters the chosen mode.

So the sequence is:

> Outputs → (raise SW9) → Mode Select → choose mode with SW0/SW1/SW2/SW3/SW8 → (lower SW9) → WAITING → (raise SW9) → enter chosen mode.

---

### 4.4 Setting ARG_A

1. From Outputs:
   - Raise SW9 → Mode Select.
   - Set SW0=1 (others 0) → mode code `1`.
   - Lower SW9 to confirm.
   - Raise SW9 again → you enter **SET_ARG_A**.

2. In **SET_ARG_A**:
   - `LED0` is ON (ARG_A mode).
   - `Hex0` shows the current switch value (masked by `0x01FF`).
   - Adjust **SW0–SW8** to represent the value you want for `ARG_A`.  
     - The value is treated as a 16-bit unsigned number, but only bits 0–8 can be set from switches.

3. When you’re happy with the value:
   - **Lower SW9** → `ARG_A` is stored.
   - The calculator goes to **WAITING**.
   - **Raise SW9** again → it exits WAITING and returns to Mode Select or Outputs flow (depending on what you do next).

---

### 4.5 Setting ARG_B

Exactly like ARG_A but with **SW1** and **LED1**:

1. From Outputs → Mode Select → set SW1=1 → lower SW9 → raise SW9 → enter **SET_ARG_B**.
2. In SET_ARG_B:
   - `LED1` ON.
   - `Hex0` shows live value from switches (`SW0–SW8`).
3. Lower SW9 to confirm ARG_B; then follow the same WAITING / SW9 handshake.

---

### 4.6 Setting Operation (CURR_OP)

1. From Outputs → Mode Select → set **SW2=1** → lower SW9 → raise SW9 → enter **SET_OP**.
2. In **SET_OP**:
   - `LED2` ON.
   - `Hex0` shows the **raw operation code** defined by `SW0–SW8`.
3. Use switch combinations to select the operation:

   | Operation          | Code | Switch pattern (example)   |
   |--------------------|------|----------------------------|
   | ADD                | 1    | SW0=1                      |
   | SUB                | 2    | SW1=1                      |
   | MULT (signed)      | 4    | SW2=1                      |
   | MULT_UNSIGNED      | 5    | SW2=1 & SW0=1 (4+1)        |
   | DIV (signed)       | 8    | SW3=1                      |
   | DIV_UNSIGNED       | 9    | SW3=1 & SW0=1 (8+1)        |
   | SQRT               | 16   | SW4=1                      |
   | SIN/COS (CORDIC)   | 32   | SW5=1                      |

4. When satisfied:
   - **Lower SW9** → the selected code is stored in `CURR_OP`.
   - The calculator immediately calls `RUN_OP`.

---

## 5. Running Operations

### 5.1 ADD / SUB (CPU only)

- If `CURR_OP = 1` (ADD):

  ```asm
  OUT_A = ARG_A + ARG_B
  OUT_B = 0
