---
layout: post
title: "Considerations about writing GUI programs in Ruby and Rust (2022)"
tags: [gui,packaging,ruby,rust]
last_modified_at: 2020-04-15 21:09:00
---

Around four years ago, I wrote an article about [writing GUI programs in Ruby]({% post_url 2018-03-13-An-overview-of-ruby-gui-development-in-2018 %}); recently, I needed a new program/functionality, very similar to the one that originally prompted me to write the article.

Since in the meanwhile I've learned Rust, now I could not only opt for multiple frameworks, but also two languages, with radically different philosophies.

In this article I'll expose my considerations about the two languages, in particular - but not exclusively - in the context of GUI progamming.

Content:

- [First Header](#first-header)

## The motivation behind the GUI program - past and present

One of the actions that I perform the most as a programmer, is file search and access.

Since the base concepts of such action are conceptually simple, and GUI programming is something that always made me curious (and many other devs, as the article popularity showed), I've decided to write my own tool.

Although I implemented a program that I've been using daily since then, GUI programming in Ruby hasn't been a very convenient experience.

Most of the Ruby - and Ruby GUI frameworks - problems are now past, but it's been a long time, so I thought it would have been interesting to investigate, and compare, alternative avenues.

I don't have much experience in Rust; I've only implemented a ray tracer (from the [famous book](http://raytracerchallenge.com/)) in parallel form, plus some minor projects.

On the other hand, this is actually a perfect starting point to investigate the question "How easy it is to write a small GUI program in Rust?", and "How does it compare to the equivalent Ruby implementation?".

## The Ruby problems - past and present

Writing the GUI program in Ruby hasn't been as rosy as I wished. The frameworks were pretty much all dead, excessive simple, or not very solid.

I've been very impressed by FXRuby, but I've experienced a showstopper bug (some time later fixed by the maintainers), which made me switch to the more conventional Tk framework.

