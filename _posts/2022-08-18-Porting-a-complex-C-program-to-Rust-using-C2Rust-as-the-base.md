---
layout: post
title: "Porting a complex C program to Rust, using C2Rust as the base"
tags: [assembler,c,data_types,debugging,gamedev,performance,retrocomputing,rust]
last_modified_at: 0000-00-00 00:00:00
---

*INTRODUCTION*

Content:

- [Todo](#todo)
- [Refactoring](#refactoring)
- [C2Rust transpiling issues/nuisances](#c2rust-transpiling-issuesnuisances)
- [Convenient lints](#convenient-lints)
- [C patterns/APIs/port strategies/notes](#c-patternsapisport-strategiesnotes)
- [Bugs found](#bugs-found)
- [General considerations/ideas](#general-considerationsideas)
- [Mistakes](#mistakes)

## Todo

- check what exactly has been needed in order to make the project runnable after transpiling

## Refactoring

Useful regexes:

```sh
# print(b"foo\0" as ...,) -> port_temp_print_str("f00",)
# (optionally with newline)
#
perl -i -0777 -pe 's/print\((\n +)?b"(.+?)\\0" as .+?,/port_temp_print_str("$2",/g' *.rs

# printlong(pcs.highscores[1].score as ...,) -> printlong(pcs.highscores[1].score.to_string(),);
# Some may required copy-alignment (see https://github.com/rust-lang/rust/issues/82523).
#
perl -i -0777 -pe 's/print(int|long)\((\S+) as .+?,/port_temp_print_str(\&$2.to_string(),/g' *.rs
```

## C2Rust transpiling issues/nuisances

- comments are lost
- macros are not translated
  - symbolic constants are not translated (https://github.com/immunant/c2rust/issues/16)
- enums are translated with an adhoc typedef, and constants with numbers assigned
  - in theory this could work, but in practice it doesn't, because enums are stored as numbers in structs, and they're converted to/from numbers when used
  - see "C patterns" section
- postfix uses extra variables called `freshN`, which are unnecessary and confusing
- pointer arithmetic has much redundancy
  - example: `demoptr.offset_from(&mut *demobuffer.as_mut_ptr().offset(0) as *mut i8)`
    - `offset(0)`
    - the cast
    - `&mut`
  - clean: `demoptr.offset_from(demobuffer.as_ptr())`
- extensive usage of mutable pointers, even when they aren't required
- unnecessary casts, often double casts
  - even when comparing to literals (https://github.com/immunant/c2rust/issues/622)
- `-(1 as libc::c_int)` occurrences (https://github.com/immunant/c2rust/issues/623)
  - due to the C standard; interesting the edge case `-2147483648` (2147483648 is outside the signed int range)
- type is always specified in variable definition `let`, which is redundant
- lots of types duplication; functions and globals are all treated as imported C functions
  - makes it difficult to navigate
  - this is intentional ("modules are intended to be compiled in isolation in order to produce compatible object files")
- encodes for loops as while (https://github.com/immunant/c2rust/issues/621)
  - this generates unnecessarily complex code in some cases
- adds odd `fresh` variables on postincrements (https://github.com/immunant/c2rust/issues/333)
- `return value` at end of functions is not idiomatic
- `let`s have the data type defined, even if unnecessary (it can be inferred)
- code is polluted with wrapping adds/subs, because the transpiler has a hard time (or possibly, it doesn't try at all) to infer if a wrapping is impossible from constant values
- boolean data types are a bloody PITA
- `let`s are declarared and assigned a value c-style (top level), even if the assigned value is overwritten (requires `#![allow(unused_assignments)]`)
- non-structured workflow is implemented using random numbers

## Convenient lints

```rs
#![warn(
    clippy::assign_op_pattern,
    clippy::correctness,
    clippy::precedence,
    clippy::unnecessary_mut_passed,
    dead_code,                      // enable, and scan the code (decide what to allow and what to remove) (allowed by C2Rust)
    unused_mut,                     // (allowed by C2Rust)
    // unused_assignments,          // may hide bugs/special conditions; add it only after careful scrutiny (allowed by C2Rust)
)]
#![allow(
    clippy::identity_op,
    clippy::int_plus_one,
    clippy::missing_safety_doc,
    clippy::needless_return,
    clippy::nonminimal_bool,
    clippy::unnecessary_cast,
    clippy::wildcard_in_or_patterns,
    clippy::zero_ptr,
)]
```

## C patterns/APIs/port strategies/notes

- use slices+offsets instead of pointers + iteration pointer; this also aligns with BCK
- don't implement `Default`; when making safe, fields won't have a null initializer anymore!
- mutexes - split states
- fix `clippy::unnecessary_cast` from the beginning
- char sign: in the port, it was simple, because it was signed
- globals
  - convert to "state instances", and pass them around
  - later, convert to classes + instance variables
  - C-inherent: globals may override each other (bug)
- callbacks without payload (libc's `atexit`) require globals
  - some globals can't be safely used (no `Sync`)
- callbacks with payload
  - use raw boxes, but must be very careful about raw pointers aliasing
    - point to discussion
- memset
  - not an issue: array.fill
- memcpy
  - not an issue itself, but often used to partially copy struct instances
    - this is inherently unsafe, but can just implement an "update from" API
- enums
  - use Rust enums, and implement `From<EnumType>`
- C strings
  - one can use Cstr/CString; later, convert to String (or Path/Buf)
    - in a program like this, Path/Buf are not necessary, and can be avoided for simplicity
  - when converting an array to CString, don't forget _not_ to include the terminator
- signed ints are the base binary/character type
  - very annoying, since Rust base binary type is u8
  - at least, raw pointer casts are liberal
- pointers to buffers (`demoptr`)
  - convert them to usize

## Bugs found

- overflow bug in audio routine
- off-by-one bug in Carmack's code (warp[2], size=2)
- off-by-one bug in rleexpand (in the port; not verified the ASM source)
  - bug in buffer size (4096 -> 4338)
- pumping events while iterating them?

## General considerations/ideas

- Split c2rust in two; the most difficult part is the decompiler
- allocation/deallocation must be extremely careful; must be performed using the same allocator. If the data structures are complex (but in the transpiling domain it isn't), the data should be reassembled and dropped, instead of freed.
- find out if the variables of a struct are shared across files, or private to them
- clippy: find out which functions/blocks don't need unsafe anymore
- intellij's only relevant refactoring is [introduce parameter](https://plugins.jetbrains.com/plugin/8182-rust/docs/rust-refactorings.html#extractparam-refactoring)
- Incrementing pointers is easy 😄: `let mut src: &[xx] = &[...]; src = src[1..];`
  - But generally use an `usize` pointer
- Rust SDL (initialization) is compatible with C SDL, so the latter can be incrementally replaced 🤯

## Mistakes

- `bloadin`: don't change the allocator, but leave the old deallocator
- `let ch = b'0'; format!("{ch}")`: slighly different, but the principle is that ch is a u8 seeming a number char, but formatted as numeric value
