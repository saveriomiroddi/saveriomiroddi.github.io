---
layout: post
title: Beginning x64 Assembly Programming Errata
tags: [assembler,performance]
last_modified_at: 2020-12-06 00:02:00
---

I've recently completed the book [Beginning x64 Assembly Programming Errata](https://www.oreilly.com/library/view/beginning-x64-assembly/9781484250761).

The book has several errors, at least a couple of which are significant; since there is no official errata, I'm publishing my findings.

Content:

- [Introduction](/Beginning-x64-Assembly-Programming-Errata#introduction)
- [Page 68: Addressing forms](/Beginning-x64-Assembly-Programming-Errata#page-68-addressing-forms)
- [Page 156: Using objdump](/Beginning-x64-Assembly-Programming-Errata#page-156-using-objdump)
- [Page 160: Working with I/O](/Beginning-x64-Assembly-Programming-Errata#page-160-working-with-io)
- [Page 206: Moving Strings](/Beginning-x64-Assembly-Programming-Errata#page-206-moving-strings)
- [Page 217: Using cpuid](/Beginning-x64-Assembly-Programming-Errata#page-217-using-cpuid)
- [Page 328: Matrix Print: printm4x4](/Beginning-x64-Assembly-Programming-Errata#page-328-matrix-print-printm4x4)
- [Page 384: Using More Than Four Arguments](/Beginning-x64-Assembly-Programming-Errata#page-384-using-more-than-four-arguments)
- [Conclusion](/Beginning-x64-Assembly-Programming-Errata#conclusion)

## Introduction

This book left me very conflicted. I was enthusiastic at the beginning, but I've found its production to be very unprofessional.

First, Apress didn't publish an errata (besides a small file with two corrections in the book's [companion repository](https://github.com/Apress/beginning-x64-assembly-programming/blob/master/errata.md)). One of the errors is also, very amusingly, caused by improper typography.

Second, the authors don't seem to take the subject seriously, either:

> We have carefully written and tested the code used in this book. However, if there are any typos in the text or bugs in the programs, we do not take any responsibility. We blame them on our two cats, who love to walk over our keyboard while we are typing.

It's worrying that two errors are conceptual (the explanations given are fundamentally wrong); after finishing the book I'm now questioning the quality of what I've learned.

Errors are a fact of life, and there's nothing wrong with them, but since readers consume time and hair because of them (I did), it's important for the topic to be recognized, and addressed in some way. At a minimum, a publisher can setup a simple web page with a table, where readers can submit their findings (I've seen this approach a few times).

But now, to the errors!

## Page 68: Addressing forms

I find this error very funny. In the following listing:

```asm
mov   rax, text1+1     ;load second character in rax
lea   rax, [text1+1]   ;load second character in rax
```

the operations actually load the _address_ of the second character in rax.

The funny part is that the text is actually there: copy/pasting reveals the missing text (`address`) is there, but due to a typographic error in the PDF, it's not visible.

## Page 156: Using objdump

This is one the two conceptual errors.

From page 156:

> The assembler took the liberty to change the sal instruction into shl, and that is for performance reasons.

The two instructions are exactly the same: they're actually one; therefore, the explanation of why `sal` is turned into `shl` is baseless.

Consequently, also the statement that follows the previous:

> As you remember from Chapter 16 on shifting instructions, this can be done without any problem in most cases.

is not exact; the change `sal` <> `shl` can be done without any problem in _any_ case, not in _most_ cases.

## Page 160: Working with I/O

In the following listing:

```asm
reads:
push rbp
mov  rbp, rsp
; rsi contains address of the inputbuffer
; rdi contains length of the inputbuffer
     mov  rax, 0  ; 0 = read
     mov  rdi, 1  ; 1 = stdin
     syscall
leave
ret
```

the length of `inputbuffer` is in rdx, not rdi.

## Page 206: Moving Strings

This is the other conceptual error, which I find alarming; it is also very interesting.

In page 206, there is a routine to print a string in reverse:

```asm
;reverse copy my_string to other_string
  prnt string6,40
  mov rax, 48   ;clear other_string
  mov rdi,other_string
  mov rcx, length
      rep stosb
  lea rsi,[my_string+length-4]
  lea rdi,[other_string+length]
  mov rcx, 27   ;copy only 27-1 characters
  std           ;std sets DF, cld clears DF
  rep movsb
  prnt other_string,length
leave
ret
```

The [companion repository](https://github.com/Apress/beginning-x64-assembly-programming/blob/9f33d5039627745ac77faa26219ea37e0a929391/Chapter%2024/24%20move_strings/move_strings.asm#L82) has an additional error in the comment; it reads "copy only 10 characters".

The paper version reads as above; since the string consists of the alphabet, it's intuitive that the loops count should be 26 instead of 27.

However, the authors don't notice this error, and in the following page, they give another baseless explanation to support the value 27:

> Why do we put 27 in rcx when there are only 26 characters? It turns out that rep decreases rcx by 1 before anything else in the loop. You can verify that with a debugger such as SASM.

Anybody who _really_ tries the routine in a debugger (I did) will find that it is incorrectly copying one byte more than it should (the first copied). As a consequence, also rsi and rdi should be decreased by one.

Something that I find mystyfying is that the authors themselves copy the specification of the `rep` instruction:

```
WHILE CountReg =/ 0
        DO
                Service pending interrupts (if any);
                Execute associated string instruction;
                CountReg ← (CountReg – 1);
                IF CountReg = 0
                    THEN exit WHILE loop; FI;
                IF (Repeat prefix is REPZ or REPE) and (ZF = 0)
                or (Repeat prefix is REPNZ or REPNE) and (ZF = 1)
                    THEN exit WHILE loop; FI;
        OD;
```

This is in conflict with their statement (the associated operation is performed _before_ rcx is decreased).

I find amusing that this bug is hidden (this is the likely reason why the authors didn't notice the bug(s)) by the fact that the `prnt` routine takes the string length as argument, so copying any text before or after the correct locations, doesn't yield any visible effect.

Above all, this bug leads to a fundamental reflection. It is an off-by-one error - a very famous type - which shows how difficult and utterly fragile Assembly programming is; so much, that the error found its way even in a book written by experienced programmers.

## Page 217: Using cpuid

In the following listing:

```asm
ssse3:
    test ecx,9h          ;test bit 0 (SSE 3)
    jz sse41             ;SSE 3 available
```

the correct values are:

```asm
    test ecx,200h        ; test bit 9 (SSE 3)
```

## Page 328: Matrix Print: printm4x4

In the following reference (emphasis mine):

> To align the stack on a 16-byte boundary, we cannot use the trick with the and instruction from _Chapter 16_.

the trick is actually in Chapter 15 (page 125).

## Page 384: Using More Than Four Arguments

The following listing shows how to perform a Windows call with more than four arguments:

```asm
  sub   rsp, 8
  mov   rcx, fmt
  mov   rdx, first
  mov   r8, second
  mov   r9, third
  push  tenth
  push  ninth
  push  eighth
  push  seventh
  push  sixth
  push  fifth
  push  fourth
  sub   rsp, 32       ;  shadow  space
  call  printf
  add   rsp, 32 + 8
```

However, the stack point reset following the call is not accounting for the (7) pushes; the correct reset is:

```asm
  add   rsp, 32 + 56 + 8    ; 56 = 7 * 8
```

In the alternative call structure, on pages 385/386, the stack pointer is correctly reset, by adding the value (32 + 56 + 8).

## Conclusion

I'm not sure if I should suggest this book or not.

For a casual user who wants a fun (!) read, it may be an effective book. On the other hand, motivated readers who wish quality knowledge, should definitely consider [The Art of 64-Bit Assembly](https://nostarch.com/art-64-bit-assembly), written by a veteran Assembly programmer (although, sadly, it's based on MASM/Windows).

Happy optimizing 😃
