---
layout: post
title: "Install VMWare Workstation 17.6.0 modules with fixes, on Linux"
tags: [linux,sysadmin,ubuntu,virtualization]
last_modified_at: 2024-09-11 14:17:00
---

In order to install VMWare Workstation on Linux, one needs to install the kernel modules.

The problem is that such modules (`vmmon` and `vmnet`) are poorly written and maintained; for this reason, some developers created fixes, in particular, to make the modules work on recent kernels.

The reference repository is [`mkubecek/vmware-host-modules`](https://github.com/mkubecek/vmware-host-modules), which, as of 11/Sep/2024, hasn't been updated to v17.6.0.

Since the forks are very messy, I've created a repository with the available patches, and a convenient installer.

The repository is [here](https://github.com/64kramsystem/vmware-host-modules-fork), and provide the following improvements:

- update to the lastest Workstation Pro version (17.6.0)
- @nan0desus' patches (allow compiling on 6.9+ kernels, and fix an out-of-bounds bug)
- fix of spurious network disconnections (from fluentreports.com)
- a small script to pack and install the patched modules
