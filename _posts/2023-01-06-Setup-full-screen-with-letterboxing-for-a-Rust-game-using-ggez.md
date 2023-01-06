---
layout: post
title: "Setup full screen (with letterboxing) for a Rust game using ggez"
tags: [gamedev,quick,rust]
last_modified_at: 0000-00-00 00:00:00
---

It took me a bit to figure out how to setup full screen/letterboxing for a game developed using ggez, because there is no useful documentation on the API, and the logic is unintuitive.

I've offered to extend the documentation, but since the maintainer didn't show any interest, I'm publishing the procedure, in order to help devs who need it.

Content:

- [First Header](#first-header)

## Introduction

In order to display a game in fullscreen, we need to set two things:

1. the origin of the viewport (so we don't need to consider the padding when drawing);
2. the size of the physical area corresponding to the viewport.

Ggez provides an API, [`set_screen_coordinates()`](https://github.com/ggez/ggez/blob/8504318a97174bda261d2f233a191d8df3815334/src/graphics/canvas.rs#L289), for this purpose (another API is actually needed, which is discussed later); we only need to perform the required calculations.

## Calculations and full implementation

WRITEME

## About ggez stability

The latest versions of ggez have been quite unstable. At least on Linux (X11) systems, fullscreen doesn't work on v0.7 (displaying corruption or incorrect geometry), and v0.8.1 is flat out broken (doesn't display images), so as of Jan/2022, one must either use the development version, or to wait for v0.8.2.

## Conclusion

WRITEME
