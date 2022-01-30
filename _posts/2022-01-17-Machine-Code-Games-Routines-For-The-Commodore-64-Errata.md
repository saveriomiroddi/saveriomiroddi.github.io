---
layout: post
title: "\"Machine Code Games Routines For The Commodore 64\" Errata (WIP)"
tags: [assembler,performance,retrocomputing]
last_modified_at: 2022-01-29 17:08:00
---

I'm reading the book [Machine Code Games Routines For The Commodore 64](https://archive.org/details/Machine_Code_Games_Routines_for_the_Commodore_64); since there is no errata, I'm publishing my findings.

The pages referred are the printed ones.

This article is a WIP; I'll update while I read (assuming I'll find other errata).

Content:

- [Page 012: JSR/RTS operation](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-012-jsrrts-operation)
- [Page 047: Spiral fill: LDR and comment](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-047-spiral-fill-ldr-and-comment)
- [Page 071: Small memory fill: Address off by one](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-071-small-memory-fill-address-off-by-one)

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
