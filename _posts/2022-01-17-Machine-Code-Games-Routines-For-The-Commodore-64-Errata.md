---
layout: post
title: "\"Machine Code Games Routines For The Commodore 64\" Errata"
tags: [assembler,performance,retrocomputing]
last_modified_at: 2022-02-27 20:26:00
---

I'm reading the book [Machine Code Games Routines For The Commodore 64](https://archive.org/details/Machine_Code_Games_Routines_for_the_Commodore_64); since there is no errata, I'm publishing my findings.

The pages referred are the printed ones.

Content:

- [Page 012: JSR/RTS operation](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-012-jsrrts-operation)
- [Page 047: Spiral fill: LDR and comment](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-047-spiral-fill-ldr-and-comment)
- [Page 071: Small memory fill: Address off by one](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-071-small-memory-fill-address-off-by-one)
- [Page 080: Fundamental Bomb Update: Start location](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-080-fundamental-bomb-update-start-location)
- [Page 081: Hail Of Barbs BASIC: Data read cycle and entry point](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-081-hail-of-barbs-basic-data-read-cycle-and-entry-point)
- [Page 085: 256 Bytes Continous Scroll: Wrong addressing mode](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-085-256-bytes-continous-scroll-wrong-addressing-mode)
- [Page 090: Joystick handling: Misplaced comment](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-090-joystick-handling-misplaced-comment)
- [Page 094: Attribute Flasher: Off-by-1 error](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-094-attribute-flasher-off-by-1-error)
- [Page 095: Alternate Sprite System: Encoded sprite missing entry](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-095-alternate-sprite-system-encoded-sprite-missing-entry)
- [Page 111: Invalid tune entry](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-111-invalid-tune-entry)
- [Pages 114/115: Mixed up Window Projection concepts](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#pages-114115-mixed-up-window-projection-concepts)
- [Page 116: Projecting a Landscape: Many bugs](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-116-projecting-a-landscape-many-bugs)

## Page 012: JSR/RTS operation

The book makes some confusion about the subroutine-related instructions `JSR` (`J`ump to `S`ub`R`outine) and RTS (`R`eturn `T`o `S`ubroutine):

> Every time a JSR is encountered, the return address is stored on the stack, the stack pointer adds 2 [...]
> On finding an RTS the stack pointer is lowered, an address is pulled off [...]

It seems that the author mixed the program counter increment, and followed the incorrect logic.

The correct sequence is:

- for a `JSR`:
  - the `PC` is incremented by 2
  - the current PC value is stored on the stack (`SP + $100`)
  - the `SP` is decreased by 2
- for an `RTS`:
  - the stack pointer is increased by 2
  - a 16 value is read from the stack (location `SP + 100`)...
  - ... and stored in the `PC` (effectively, jumping)

Note that the sequence is not the same as on x86, where, on push, the stack pointer is moved before writing on the stack (and viceversa for the pop).

References: [JSR](https://www.c64-wiki.com/wiki/JSR) and [Stack](https://www.c64-wiki.com/wiki/Stack).

## Page 047: Spiral fill: LDR and comment

The `LDR ADDR + 1` in the `:LL1` loop should be `LDA ADDR + 1`.

The routine is not really a spiral; more accurately, it prints centered, filled, rectangles of increasing size.

With the routine as is, the progress won't be visible (as it's too fast, and if repeated, there won't be any visible difference); in order to view the difference, and also make it look nicer, convert to a loop, and increase the fill character on each iteration:

```asm
// Replace `RTS` with:
//
inc CHARCODE
clc
bcc ll0
```

## Page 071: Small memory fill: Address off by one

The small (<256 bytes) memory fill described is:

```asm
      ldx #0
      lda #CHAR
loop: sta ADDR, x
      dex
      bne loop
      rts
```

This pseudocode is ambiguous about the counter (stored in the A register), whose number of cycles may be encoded with 0-based semantics (1 cycle -> X=0) or 1-based (1 cycle -> X=1).

The first case (0-based) cannot work in any case:

```asm
      ldx #0      // if this means 1 cycle...
      lda #CHAR
loop: sta ADDR, x
      dex         // ...this is 255 on the first cycle...
      bne loop    // ...and 256 chars are printed
      rts

      ldx #1      // if this means 2 cycles...
      lda #CHAR
loop: sta ADDR, x
      dex         // ...this is 0 on the first cycle...
      bne loop    // ...and 1 char is printed
      rts
```

In the second case (1-based), the address is off by one:

```asm
      ldx #1      // if this means 1 cycle...
      lda #CHAR
loop: sta ADDR, x // the last byte written is at (ADDR + 1)
      dex
      bne loop
      rts
```

The correct routine is therefore the second (1-based), with a fix that accounts for the 1 byte displacement:

```asm
      ldx #1
      lda #CHAR
loop: sta ADDR - 1, x // now the last byte written is at ADDR
      dex
      bne loop
      rts
```

Note that this logic can't print 0 chars in any case (which can be legitimate, depending on the use case); in order to allow this, the typical ASM loop pattern should be used:

```asm
      ldx #1
      beq exit        // note that in x86, typically this would be a jump; here, we take advantage of
loop: sta ADDR - 1, x // the fact that ldx affects the zero flag, and fall through if X is 0!
      dex
      bne loop
exit: rts
```

## Page 080: Fundamental Bomb Update: Start location

The listing start location is defined as `$08bf`:

```asm
; 191 + 256 * 8 = 2239 = $08bf
;
      lda #191
      sta 251
      lda #8
      sta 252
```

The correct location is instead `$07bf` ($0400 + 40 * (25 - 1) - 1) - the end of the beforelast line. The `$08bf`location is also off screen (whose memory interval is `$0400`-`$07e7`).

## Page 081: Hail Of Barbs BASIC: Data read cycle and entry point

The data read cycle on the listing runs infinitely:

```bas
60 P = 820
70 READ D : POKE P, D : P = P + 1 : GOTO 70
```

A for loop is a correct and convenient approach:

```bas
# REM THERE ARE 44 BYTES
60 FOR L = 820 TO 863 : READ D : POKE L, D : NEXT
```

Additionally, the entry point (invoked by SYS) is 820, not 830:

```bas
1010 POKE 1024 + INT(40 * RND(1)), 36 : SYS 820 : GOTO 1010
```

## Page 085: 256 Bytes Continous Scroll: Wrong addressing mode

The routine uses the X register for computing the current character displacement:

```asm
      lda ADDR, x
```

This addressing mode is the so-called "Indexed indirect" (generally represented as `lda (ADDR, x)`), which first adds the X value to the pointer, then loads the value from the memory, which is not correct - for example, if $0400 (endian-normalized) is stored at ADDR, and X = 2, the CPU will access the value at $0402, which will return an undefined value.

The intended addressing mode is the "Indirect indexed":

```asm
      lda (ADDR), y
```

This addressing mode first loads the value from memory, then adds the index, and finally accesses the resulting memory location; in this case, it will load $0400 from ADDR, then add 2 (Y), and finally access the resulting address ($0402).

## Page 090: Joystick handling: Misplaced comment

The comment:

```asm
      sta 53248
      lda TABLE+1, x    ; Update X
      clc
```

is one line below where it should be:

```asm
      sta 53248         ; Update X
      lda TABLE+1, x
      clc
```

## Page 094: Attribute Flasher: Off-by-1 error

The `TABLE` base reference:

```asm
      ldx #25
      // ...
      lda TABLE, x
      cmp #255
```

must be decreased by one byte, because the `x` value is in the close (both ends included) interval [1, 25]:

```asm
      ldx #25
      // ...
      lda TABLE - 1, x
      cmp #255
```

without this correction, the first read is at (`TABLE` + 1), and the last one at (`TABLE` + (screen lines count) + 1).

## Page 095: Alternate Sprite System: Encoded sprite missing entry

The sprite is encoded as:

```
      86, 39
      78, 1,
      37, 1,
      77, 38
      34, 1,
      34, 1,
      0,  -
```

Which represents a sprite like this (9 chars tot):

```
 X
/%\
"""
```

However, the table is missing the last symbol (another quote, #34):

```
      86, 39
      78, 1
      37, 1
      77, 38
      34, 1
      34, 1
      34, 1
      0,  -
```

## Page 111: Invalid tune entry

The beforelast entry of the tune:

```
0  0  255
```

is not valid, and it's not a part of the tune, so it should be removed.

## Pages 114/115: Mixed up Window Projection concepts

In the diagram in the page 114, the variable `C` and `R` have been mixed - their placement should be swapped. For example, in the inner loop, the test should be `C = WIDTH ?` instead of `R = WIDTH ?`, and in the outer loop, the test should be `R = HEIGHT ?` instead of `C = HEIGHT ?`.

In the listing in the page 115, the `Copy window` comment should be `Copy row`.

## Page 116: Projecting a Landscape: Many bugs

This routine has a lot of bugs:

- before the `SBC` instruction, `SEC` should be issued;
- the `LDY #30` should be `LDY #31`, as the amount of elements drawn must include the one including the spaceship (in total, 2 * radius + 1)
- the `LDA (TABLE, X)` uses the wrong addressing mode, since the correct one is `LDA (TABLE), Y`, in the whole routine, the `X` instructions must be replaced with `Y` counterpart, and viceversa
- the comment "Plot ship at coordinates (Y, A)" is wrong; it should be "Plot the element at coordinate Y, with value A"

The corrected version is:

```asm
        TYA
        SEC
        SBC #15
        TAY
        LDX #31
LOOP:   LDA (TABLE), Y
        JSR PLOT
        INY
        DEX
        BNE LOOP
        RTS
```
