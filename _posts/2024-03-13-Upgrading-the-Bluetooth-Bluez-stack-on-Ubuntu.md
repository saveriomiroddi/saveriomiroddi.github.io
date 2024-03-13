---
layout: post
title: "Upgrading the Bluetooth (Bluez) stack on Ubuntu"
tags: [bluetooth,bluez,hardware,linux,quick,sysadmin,ubuntu]
last_modified_at: 2024-03-13 11:44:51
---

In some cases, it's desirable to upgrade the Bluez (Bluetooth stack) version on Ubuntu; for example, on the stock Ubuntu 22.04 Jammy, some headphones may not work.

In this article, I'll describe the procedure to perform the upgrade, using the source code.

Content:

- [Procedure](/Upgrading-the-Bluetooth-Bluez-stack-on-Ubuntu#procedure)

## Procedure

First, install the required libraries:

```sh
apt install -y libical3-dev python3-docutils
```

Find the latest release on the official repository:

```sh
latest_release=$(
  git ls-remote https://github.com/bluez/bluez.git |
  perl -lne 'print $1 if /refs\/tags\/([\d.]+)$/' |
  sort -V |
  tail -n 1
)
```

Perform a shallow clone:

```sh
git clone --depth 1 https://github.com/bluez/bluez.git -b "$latest_release"
cd bluez
```

Bootstrap and configure the compilation:

```sh
./bootstrap

# The `--libexecdir` is required to match the Ubuntu paths configuration, otherwise, `/usr/libexec
# is used by default.
#
./configure \
  --prefix=/usr --mandir=/usr/share/man --sysconfdir=/etc --localstatedir=/var \
  --libexecdir=/usr/lib
```

Compile and install:

```sh
make -j "$(nproc)"

# The file `/usr/lib/cups/backend/bluetooth` is also owned by the `bluez-cups` package; it's not
# clear if it needs to be up to date, but if one doesn't use it, it doesn't matter.
# In theory, the `--disable-cups` configure option can be used, but it causes a configure error
# (not mentioned by the documentation).
#
make install
```

Finally, hold the `bluez` package:

```sh
apt-mark hold bluez
```

As general practice, it's advisable to watch the repository releases on the [GitHub project](https://github.com/bluez/bluez), so that one can perform an upgrade, especially in case of a security fix.
