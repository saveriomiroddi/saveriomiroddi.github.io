---
layout: post
title: A precise guide to build a custom Linux kernel
tags: [linux,sysadmin,ubuntu]
last_modified_at: 2022-08-09 11:40:59
redirect_from:
- Quickly-building-a-custom-linux-ubuntu-kernel-with-modified-configuration-kernel-timer-frequency
---

Under certain circumstances, it can be necessary to build a customized Linux kernel, for example, with a different configuration, or with patches applied.

This is a relatively typical task, so there is plenty of information around, however, I've found lack of clarity about the concepts involved, outdated and incomplete information, etc.

For this reason, I've decided to write a small guide about this task, which can be used only as copy/paste reference, but also fully read, in order to get a better understanding of the concepts involved..

Content:

- [Requirements](/A-precise-guide-to-build-a-custom-linux-kernel#requirements)
- [Installing the required packages](/A-precise-guide-to-build-a-custom-linux-kernel#installing-the-required-packages)
- [Choosing the source code](/A-precise-guide-to-build-a-custom-linux-kernel#choosing-the-source-code)
- [Downloading the source code](/A-precise-guide-to-build-a-custom-linux-kernel#downloading-the-source-code)
- [Patching the kernel](/A-precise-guide-to-build-a-custom-linux-kernel#patching-the-kernel)
- [Kernel configuration concepts](/A-precise-guide-to-build-a-custom-linux-kernel#kernel-configuration-concepts)
- [Tools to set up and modify the kernel configuration](/A-precise-guide-to-build-a-custom-linux-kernel#tools-to-set-up-and-modify-the-kernel-configuration)
- [Necessary/convenient changes](/A-precise-guide-to-build-a-custom-linux-kernel#necessaryconvenient-changes)
- [Applying the desired customizations](/A-precise-guide-to-build-a-custom-linux-kernel#applying-the-desired-customizations)
- [Building the kernel](/A-precise-guide-to-build-a-custom-linux-kernel#building-the-kernel)
- [Conclusion](/A-precise-guide-to-build-a-custom-linux-kernel#conclusion)

## Requirements

This guide is based on Debian/Ubuntu systems, however, it can be easily adapter to other systems.

## Installing the required packages

In order to compile the kernel, some packages are required. They may change with time, so this is an approximate list:

```sh
sudo apt install libncurses5 libncurses5-dev libncurses-dev qtbase5-dev-tools flex \
  bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf
```

## Choosing the source code

There are different repositories available:

- `git@github.com:torvalds/linux.git`: Official (Torvalds') kernel repository; doesn't include patch versions
- `git://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/focal`: Canonical release versions (see [here](https://wiki.ubuntu.com/Kernel/Dev/KernelGitGuide))
- `git://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack`: Canonical mainline/testing versions

It's also possible to download the source code via Ubuntu kernel source packages, however, it's simpler to just use a repository.

For simplicity, we'll use the official kernel repository, but the procedure to configure and compile all the versions is identical.

In case one wants to use specific Canonical version, [this guide](https://ubuntu.com/kernel) explains how to find the reference kernel version corresponding to a Canonical one.

## Downloading the source code

Clone the (reference) repository:

```sh
git clone git@github.com:torvalds/linux.git
cd linux
```

Now, we checkout the desired version:

```sh
# In this example, we checkout the major.minor version corresponding to the running kernel (e.g. v5.15).
#
git checkout "$(uname -r | cut -d. -f1-2)"
```

## Patching the kernel

If we want to patch the kernel, this is the appropriate stage.

For example, this fixes the keyboard problem on modern AMD Zen systems (6800+):

```sh
git cherry-pick 9946e39fe8d0a5da9eb947d8e40a7ef204ba016e
```

## Kernel configuration concepts

The kernel compilation centers around the configuration file, `.config`.

This file doesn't come, directly, with the repository, so there are several considerations to make:

- which configuration should be used as base?
- what if we have an available configuration for an older version of the kernel?
- how to perform modifications?

There are different approaches to address these points.

Gathering the configuration of a certain kernel that is not currently running (therefore, from a 3rd party source) is not always feasible; there is a script in the repository for performing this operation (`extract-ikconfig`), however, it requires the given kernel to be compiled with a specific option.

In this guide, we'll therefore use the configuration of a running kernel as base.

## Tools to set up and modify the kernel configuration

This command copies the running kernel configuration, and applies the defaults for new settings added by the new kernel version:

```sh
make olddefconfig
```

There are two ways of making changes to the configuration: programmatic and interactive.

Programmatically, one uses the script `scripts/config` (which has different actions like setting and removing entries). However, this is dangerous; some logical changes require multiple settings to be changed, so it's easy to make mistakes.

The simplest and safest way is to run the interactive programs:

```sh
make xconfig    # X11
make menuconfig # terminal
```

Both will also run `make olddefconfig`, if this hasn't been done already.

The clearest way of observing kernel changes is via `scripts/diffconfig`, which is cleaner than a manual diff:

```sh
$ scripts/diffconfig .config{.old,}
HZ 250 -> 100
HZ_100 n -> y
HZ_250 y -> n

$ diff .config{.old,}
457,458c457,458
< # CONFIG_HZ_100 is not set
< CONFIG_HZ_250=y
---
> CONFIG_HZ_100=y
> # CONFIG_HZ_250 is not set
461c461
< CONFIG_HZ=250
---
> CONFIG_HZ=100
```

It's certainly possible, if one wants, to run the interactive program and perform changes, then run `scripts/diffconfig`, and convert them to `scripts/config` commands. In this case, don't forget to use the exact actions:

- `--undefine`: entirely remove
- `--disable`:  comment
- `--enable`:   uncommment
- `--set-val`:  set a value
- `--set-str`:  set a quoted value

## Necessary/convenient changes

Before proceeding with the customizations, there are some changes to apply.

The first is necessary on Ubuntu/Debian configurations; we must specify not to bake extra trusted X.509 keys into the kernel (used to verify kernel modules; see [here](https://cs4118.github.io/dev-guides/debian-kernel-compilation.html)):

```sh
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str SYSTEM_REVOCATION_KEYS ""
```

Without this change, the kernel compilation will raise an error like `No rule to make target 'debian/canonical-certs.pem', needed by 'certs/x509_certificate_list`.

Then, we disable the debug information; by default (as of v5.19), an extra 1.2 GiB package is generated, containing the kernel debugging information, which is not useful for the general public.

The easiest way to disable it interactively; the entry is located under `Kernel hacking` -> `Compile-time checks and compiler options` -> `Compile the kernel with debug info`.

On a v5.19 kernel, the corresponding programmatic changes are:

```sh
scripts/config --undefine DEBUG_INFO
scripts/config --undefine DEBUG_INFO_COMPRESSED
scripts/config --undefine DEBUG_INFO_REDUCED
scripts/config --undefine DEBUG_INFO_SPLIT
scripts/config --undefine GDB_SCRIPTS
scripts/config --set-val  DEBUG_INFO_DWARF5     n
scripts/config --set-val  DEBUG_INFO_NONE       y
```

## Applying the desired customizations

Now we can apply the desired customizations.

For example, the kernel timer frequency entry is listed under `Processor type and features` -> `Timer frequency`.

On a v5.15 kernel, the programmatic changes to set a 1000 Hz frequency are:

```sh
scripts/config --set-val HZ       1000
scripts/config --set-val HZ_1000  y
scripts/config --set-val HZ_250   n
```

## Building the kernel

Time to build the kernel!

It's common practice to add a version modifier, in order to make the kernel recognizable:

```sh
version_suffix="timer-100"
make -j "$(nproc)" deb-pkg LOCALVERSION=-"$version_suffix"
```

This will run `make clean`, and generate the desired deb packages (along with other files) in the parent directory; note that the firmware files are not included (they're in a separate repository).

If there are errors, the last error message is not informative; either scroll up, or run without `-j` (which makes the last error message informative).

If the build is interrupted, it's best to perform a complete reset:

```sh
make mrproper
```

If not done, temporary files may be left in the filesystem, which can cause very confusing errors on the next build attempt.

## Conclusion

Although I would have expected the procedure to be trivial, it wasn't. Once the involved concepts were clear though, the procedure became simple and straightforward.

It's now trivially possible for everybody to have a standard-as-desired kernel, with the intended customizations.

Happy kernel hacking!
