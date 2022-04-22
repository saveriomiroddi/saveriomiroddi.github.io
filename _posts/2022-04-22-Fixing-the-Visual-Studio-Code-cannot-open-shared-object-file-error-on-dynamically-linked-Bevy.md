---
layout: post
title: "Fixing the Visual Studio Code \"cannot open shared object file\" error on dynamically linked Bevy"
tags: [gamedev,rust]
last_modified_at: 2022-04-22 18:30:28
---

There are a few strategies to improve Bevy's compilation time; one of them is to enable dynamic linking (`features = ["dynamic"]`).

While this works fine when manually invoking Cargo, attempting to launch a debug session from Visual Studio Code will raise this error:

```
/path/to/project/target/debug/project: error while loading shared libraries: libbevy_dylib-ae04813e8bd66866.so: cannot open shared object file: No such file or directory
```

This is a relatively common topic on the net, but the solutions presented are not very clear.

What one exactly needs to do is to add this entry to the launch configuration (in `launch.json`):

```json
"env": {
  "LD_LIBRARY_PATH": "${workspaceFolder}/target/debug/deps:${env:HOME}/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib",
}
```

This assumes that the dev uses Rustup and the nightly toolchain; if one uses the stable toolchain, replace `nightly` with `stable`.

Happy debugging 🙂
