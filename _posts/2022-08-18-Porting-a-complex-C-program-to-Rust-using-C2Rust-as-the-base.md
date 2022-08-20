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

- overflow bug in audio routine
- off-by-one bug in Carmack's code (warp[2], size=2)
- off-by-one bug in rleexpand (in the port; not verified the ASM source)
  - bug in buffer size (4096 -> 4338)

## Unsorted notes

### Notes 1

Transpiling issues:

- there are lots of unnecessary casts, often double casts
  - even when comparing to literals
    - https://github.com/immunant/c2rust/issues/622
- lots of types are duplicated
- functions and globals are all treated as imported C functions
  - makes difficult to navigate
  - this is intentional ("modules are intended to be compiled in isolation in order to produce compatible object files")
- `-(1 as libc::c_int)` occurrences
  - opened issue
  - due to the C standard; interesting the edge case `-2147483648` (2147483648 is outside the signed int range)

- ideal/tools
  - find out if the variables of a struct are shared across files, or private to them
  - clippy: find out which functions/blocks don't need unsafe anymore
  - intellij's only relevant refactoring is [introduce parameter](https://plugins.jetbrains.com/plugin/8182-rust/docs/rust-refactorings.html#extractparam-refactoring)

- doubts/confirmations
  - for numeric comparisons against numbers, can u8 and i8 be interchangeably used?
    - `ch as i32 >= ' '` -> if ch was negative, this will be a wrong check!
    - `int a = -1; char c  = ' '; printf("c:%d, nc:%d", (uint)a > (uint)c, a > c);`
  - think about why functions are stored a C functions, and converted to C imports
  - double check endianness
  - is signed ints the base data type

- gotchas!
  - when converting an array to CString, don't forget _not_ to include the terminator

### Notes 2

- split c2rust in two; the most difficult part is the decompiler

c2 rust problems:

- duplication
- enums are not rustified
- enum matches uses numbers rather than enum entries (or at least, the consts)
- pollution with signed casts, even for literals, and even when it could be removed from both sides of an equality test
- encodes for loops as while
  - this generates unnecessarily complex code in some cases
  - https://github.com/immunant/c2rust/issues/621
- adds odd `fresh` variables on postincrements
  - https://github.com/immunant/c2rust/issues/333

c to rust strategies:

- de-global strategies
  - graph analizer; c helps because, up to a point, it can be easily parsed (not polymorphism)
  - use a globalstate (adviced!)
  - group globals into scopes, and covert the scopes to classes
    - secondary, as this is just a tidy up

### Poor man's refactorer: Cargo info

There's lots of other stuff; the below is related to the errors.

```json
[
  {
    "reason": "compiler-message",
    "package_id": "catacomb 0.1.0 (path+file:///home/saverio/code/catacomb_ii-64k)",
    "manifest_path": "/home/saverio/code/catacomb_ii-64k/Cargo.toml",
    "target": {
      "kind": [
        "staticlib",
        "rlib"
      ],
      "crate_types": [
        "staticlib",
        "rlib"
      ],
      "name": "catacomb_lib",
      "src_path": "/home/saverio/code/catacomb_ii-64k/src/catacomb-lib.rs",
      "edition": "2018",
      "doc": true,
      "doctest": true,
      "test": true
    },
    "message": {
      "rendered": "error[E0609]: no field `xormask` on type `&mut PcrlibAState`\n   --> src/cpanel.rs:446:9\n    |\n446 |     pas.xormask = 0;\n    |         ^^^^^^^ unknown field\n    |\n    = note: available fields are: `SoundData`, `soundmode`, `SndPriority`, `_dontplay`, `AudioMutex` ... and 19 others\n\n",
      "children": [
        {
          "children": [],
          "code": null,
          "level": "note",
          "message": "available fields are: `SoundData`, `soundmode`, `SndPriority`, `_dontplay`, `AudioMutex` ... and 19 others",
          "rendered": null,
          "spans": []
        }
      ],
      "code": {
        "code": "E0609",
        "explanation": "Attempted to access a non-existent field in a struct.\n\nErroneous code example:\n\n```compile_fail,E0609\nstruct StructWithFields {\n    x: u32,\n}\n\nlet s = StructWithFields { x: 0 };\nprintln!(\"{}\", s.foo); // error: no field `foo` on type `StructWithFields`\n```\n\nTo fix this error, check that you didn't misspell the field's name or that the\nfield actually exists. Example:\n\n```\nstruct StructWithFields {\n    x: u32,\n}\n\nlet s = StructWithFields { x: 0 };\nprintln!(\"{}\", s.x); // ok!\n```\n"
      },
      "level": "error",
      "message": "no field `xormask` on type `&mut PcrlibAState`",
      "spans": [
        {
          "byte_end": 14049,
          "byte_start": 14042,
          "column_end": 16,
          "column_start": 9,
          "expansion": null,
          "file_name": "src/cpanel.rs",
          "is_primary": true,
          "label": "unknown field",
          "line_end": 446,
          "line_start": 446,
          "suggested_replacement": null,
          "suggestion_applicability": null,
          "text": [
            {
              "highlight_end": 16,
              "highlight_start": 9,
              "text": "    pas.xormask = 0;"
            }
          ]
        }
      ]
    }
  },
  {
    "reason": "compiler-message",
    "package_id": "catacomb 0.1.0 (path+file:///home/saverio/code/catacomb_ii-64k)",
    "manifest_path": "/home/saverio/code/catacomb_ii-64k/Cargo.toml",
    "target": {
      "kind": [
        "staticlib",
        "rlib"
      ],
      "crate_types": [
        "staticlib",
        "rlib"
      ],
      "name": "catacomb_lib",
      "src_path": "/home/saverio/code/catacomb_ii-64k/src/catacomb-lib.rs",
      "edition": "2018",
      "doc": true,
      "doctest": true,
      "test": true
    },
    "message": {
      "rendered": "error[E0560]: struct `PcrlibAState` has no field named `xormask`\n   --> src/pcrlib_a_state.rs:106:13\n    |\n106 |             xormask,\n    |             ^^^^^^^ `PcrlibAState` does not have this field\n    |\n    = note: available fields are: `SoundData`, `soundmode`, `SndPriority`, `_dontplay`, `AudioMutex` ... and 19 others\n\n",
      "children": [
        {
          "children": [],
          "code": null,
          "level": "note",
          "message": "available fields are: `SoundData`, `soundmode`, `SndPriority`, `_dontplay`, `AudioMutex` ... and 19 others",
          "rendered": null,
          "spans": []
        }
      ],
      "code": {
        "code": "E0560",
        "explanation": "An unknown field was specified into a structure.\n\nErroneous code example:\n\n```compile_fail,E0560\nstruct Simba {\n    mother: u32,\n}\n\nlet s = Simba { mother: 1, father: 0 };\n// error: structure `Simba` has no field named `father`\n```\n\nVerify you didn't misspell the field's name or that the field exists. Example:\n\n```\nstruct Simba {\n    mother: u32,\n    father: u32,\n}\n\nlet s = Simba { mother: 1, father: 0 }; // ok!\n```\n"
      },
      "level": "error",
      "message": "struct `PcrlibAState` has no field named `xormask`",
      "spans": [
        {
          "byte_end": 2899,
          "byte_start": 2892,
          "column_end": 20,
          "column_start": 13,
          "expansion": null,
          "file_name": "src/pcrlib_a_state.rs",
          "is_primary": true,
          "label": "`PcrlibAState` does not have this field",
          "line_end": 106,
          "line_start": 106,
          "suggested_replacement": null,
          "suggestion_applicability": null,
          "text": [
            {
              "highlight_end": 20,
              "highlight_start": 13,
              "text": "            xormask,"
            }
          ]
        }
      ]
    }
  },
  {
    "reason": "build-finished",
    "success": false
  }
]
```
