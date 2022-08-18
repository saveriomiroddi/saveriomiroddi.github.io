---
layout: post
title: "Porting a complex C program to Rust, using C2Rust as the base"
tags: [assembler,c,data_types,debugging,gamedev,performance,retrocomputing,rust]
last_modified_at: 0000-00-00 00:00:00
---

*INTRODUCTION*

Content:

- [First Header](#first-header)

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

## C2Rust transpiling issues

- comments are lost
- macros are not translated
  - symbolic constants are not translated
    - https://github.com/immunant/c2rust/issues/16
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

## Convenient lints

```rs
#![deny(
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

## C patterns/APIs/port strategies

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
- signed ints are the base binary/character type
  - very annoying, since Rust base binary type is u8
  - at least, raw pointer casts are liberal
- pointers to buffers (`demoptr`)
  - convert them to usize

## Interesting bugs

- overflow bug
- off-by-one bug in Carmack's code (warp[2], size=2)
- off-by-one bug in rleexpand (in the port; not verified the ASM source)
