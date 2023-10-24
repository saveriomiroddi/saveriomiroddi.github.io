---
layout: post
title: "Tiny: Grepping a program's output while still displaying the progress"
tags: [linux,quick,ruby,shell_scripting,sysadmin,text_processing]
last_modified_at: 2023-10-24 23:25:32
---

I needed to perform an rsync operation, which displayed the progress while running, filtering out some lines matching a pattern.

This isn't solvable with a oneliner, but I wanted to solve it nonetheless, in a simple way; this tiny article will show how.

Content:

- [The requirement](/Tiny-Grepping-a-program-s-output-while-still-displaying-the-progress#the-requirement)
- [The problem](/Tiny-Grepping-a-program-s-output-while-still-displaying-the-progress#the-problem)
- [The solution](/Tiny-Grepping-a-program-s-output-while-still-displaying-the-progress#the-solution)
- [Conclusion](/Tiny-Grepping-a-program-s-output-while-still-displaying-the-progress#conclusion)

## The requirement

I often use `rsync` to keep some data in sync. In some cases I need to manually inspect the output, filtering out some noise (lines matching a certain pattern); also, I need to view the progress update.

## The problem

It's not possible to use grep - the logic is not simply "inspect a line, and if it doesn't match a pattern, print it"; progress is displayed by using special characters (the carriage return (`\r`)) that need to be printed immediately.

Following this logic, grep should hypothetically print the characters immediately, then, when a newline is found, inspect the line, and erase or print according to the match; this functionality is not supported.

## The solution

While a trivial (oneliner) solution is not possible, by using a scripting language, we can still implement a simple solution.

This is the implementation using Ruby:

```sh
  stdbuf -o0 rsync \
    --itemize-changes <other_params...> \
    | ruby -e '
      STDIN.each_char.each_with_object("") do |char, current_line|
        print char
        if char == "\n"
          print "\e[A\e[K" if current_line =~ /^[.<>][fd]\.\.[.t][.p]\.\.\.\.\./
          current_line.clear
        else
          current_line << char
        end
      end
    '
```

Explanation of the most important concepts:

- `stdbuf -o0` sets rsync output to unbuffered, forcing it to send individually each character to the pipe; normally, the output is buffered for performance reasons
- `"\e[A\e[K"` is an [ANSI escape sequence](https://en.wikipedia.org/wiki/ANSI_escape_code), that goes up one line, and clears the landing line
- `^[.<>][fd]\.\.[.t][.p]\.\.\.\.\.` is a pattern that matches lines indicating entries that have permissions or modification time changed (in the format enabled by `--itemize-changes`; for the details, see the man page, via `man rsync | less +/--itemize-changes, +n`); note that the regex could be simplified, but with the current structure, it's more readable

## Conclusion

While the solution is not a oneliner, it's still compact and intuitive; additionally, it can be easily separated into a script (e.g. `grep_progress`) that can be reused in such cases.

Happy scripting!
