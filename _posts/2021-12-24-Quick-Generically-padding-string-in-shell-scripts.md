---
layout: post
title: Quick&#58; Generically padding strings in shell scripts
tags: [linux,quick,shell_scripting,sysadmin]
---

Today is Christmas Eve, a notoriously famous day for experimenting with shell scripts! 😁

While updating a [script of mine](https://github.com/64kramsystem/openscripts/blob/master/convert_cb_archive_to_pdf), I came across the problem of padding a filename.

Padding a filename is simple task, however, finding the simplest possible way of doing it in a shell script, is actually not so simple.

In this article I'll explain the problem, and my solution.

Content:

- [Design disclaimer](/Quick-Generically-padding-string-in-shell-scripts#design-disclaimer)
- [The problem](/Quick-Generically-padding-string-in-shell-scripts#the-problem)
- [Issues with a typical find pipeline](/Quick-Generically-padding-string-in-shell-scripts#issues-with-a-typical-find-pipeline)
- [The st00pid simple solution](/Quick-Generically-padding-string-in-shell-scripts#the-st00pid-simple-solution)
  - [Regex-boosting the st00pid simple solution](/Quick-Generically-padding-string-in-shell-scripts#regex-boosting-the-st00pid-simple-solution)
- [The epic solution](/Quick-Generically-padding-string-in-shell-scripts#the-epic-solution)
- [Conclusion](/Quick-Generically-padding-string-in-shell-scripts#conclusion)

## Design disclaimer

This article is not an invitation to use arcane ("Perl-ish") solutions to problems.

When working in team, maintainability/readability are critical values; a verbose but evident solution is generally preferred. Therefore, this article should be read, in general terms, just for the lulz.

## The problem

Let's say we have a list of files:

```sh
$ rm -f *
$ touch bar.txt foo-1.jpg foo-9.jpg foo-10.jpg foo-100.jpg

$ ls -1 | sort -t- -k 2 -n
bar.txt
foo-1.jpg
foo-9.jpg
foo-10.jpg
foo-100.jpg
```

We need to process the `jpg` files with a program that orders them lexicographically; this is a problem, since the files are named with numeric ordering semantics. If we don't do anything, this is how the program will possibly order them:

```sh
$ ls -1 *.jpg
foo-100.jpg
foo-10.jpg
foo-1.jpg
foo-9.jpg
```

The concept of the solution is simple: just pad the digits with zeros. The implementation is not trivial, however, as we may have to go through several steps:

1. select only the jpg files
2. possible: strip everything except the digits
3. pad the digits (and adding the stripped chars back, if required)
4. rename the files

Some solutions don't require the "possible" steps, but roughly, doing all in a single, simple step, is challenging.

## Issues with a typical find pipeline

An intuitive approach is to use `find` with text processing programs, using its typical patterns.

This approach:

```sh
find . -name '*.jpg' | <processing> | xargs <move>
```

is possible, but rather ugly, because the processing step needs to send both the source and the processed filenames.

The exec-based alternatives:

```sh
find . -name '*.jpg' -exec bash -c '<move> + <processing>' - {} \;
find . -name '*.jpg' -exec bash -c '<processing>' - {} \; | xargs <move>
```

suffer from a similar problem.

We didn't even touch the processing itself; for example, `printf` could be used for the purpose, but it requires stripping the non-digits:

```sh
$ printf "%04i" "10"
0010

$ printf "%04i" "foo-10.jpg"
Error!
```

Using `printf` additionally restricts padding to zeros - what if we want to pad with smileys??

## The st00pid simple solution

If one:

- prioritizes simplicity in all the aspects
- doesn't need a generic solution
- and can use the `rename` tool (a convenient tool available in the repositories of all the Linux distributions)

then two commands will do the job:

```sh
$ rename 's/-(\d)\./-00$1./' *.jpg
$ rename 's/-(\d\d)\./-0$1./' *.jpg
$ ls -1 *.jpg
foo-001.jpg
foo-009.jpg
foo-010.jpg
foo-100.jpg
```

The lexicographic and numeric ordering will now match. This approach comes, of course, with the disclaimer that three digits ought to be enough for anybody 😉

### Regex-boosting the st00pid simple solution

For the sake of the regex lulz, we can boost the expression(s) used:

```sh
$ rename 's/-\K(\d)(?=\.)/00$1/' *.jpg
$ rename 's/-\K(\d\d)(?=\.)/0$1/' *.jpg
$ ls -1 *.jpg
foo-001.jpg
foo-009.jpg
foo-010.jpg
foo-100.jpg
```

What did we do here?

- the `\K` is a metacharacter that tells Perl not to replace anything before it (but still perform the whole pattern match); this allows not to specify `-` in the replacement expression;
- the lookahead `(?=...)` expresses a pattern that follows another (in this case, the literal dot (`.`)); this also performs a match but not a replacement, so we don't need to specify `.` in the replacement expression.

These features are just amusing in this context, but when needed in real world expressions, they're very useful. A typical pattern for the `\K` metachar is replacing configuration values:

```sh
perl -i -pe 's/mykey: \K.+/other_value/' /path/to/my.conf
```

the above will replace the value of the configuration entry named `mykey`; without `\K`, one needs to do capture the key name, and print it as well:

```sh
perl -i -pe 's/(mykey: ).+/$1other_value/' /path/to/my.conf
```

## The epic solution

Perl's substitution operator (`s///`) has a flag (`e`) that allows specifying a Perl statement (expression) as replacement; since the `rename` tool uses Perl behind the scenes, we can take advantage of it, and write the padding logic in programmatic form:

```sh
rename 's/(\d+)/"0" x (4 - length($1)) . $1/e' *.jpg
```

as long as we're aware of the Perl string operators `x` (string repetition) and `.` (string concatenation), and the regex capturing operators (`(...)` and `$1`), the logic is straightforward:

- search multiple digits and capture them;
- count the zeros required, by subtracting the length of the capture from the padded length (4, in this case);
- repeat the zeros;
- concatenate the original number.

Note that if the filenames contain other numeric substrings that we don't want to replace, we need to adjust the expression, but that's easily done.

## Conclusion

With the right tools, we've reached a solution that is straightforward and flexible (keeping in mind the design considerations).

As always, Unix and its tools FTW 😎
