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

- [Page 12: JSR/RTS operation](/Machine-Code-Games-Routines-For-The-Commodore-64-Errata#page-12-jsrrts-operation)
- [Page 47: LDR and comment](#page-47-ldr-and-comment)

## Page 12: JSR/RTS operation

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

## Page 47: LDR and comment

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