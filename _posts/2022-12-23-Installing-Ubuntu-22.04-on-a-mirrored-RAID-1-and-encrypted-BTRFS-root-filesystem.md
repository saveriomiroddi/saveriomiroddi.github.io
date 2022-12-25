---
layout: post
title: "Installing Ubuntu (22.04) on a mirrored (RAID-1) and encrypted BTRFS root filesystem"
tags: [filesystems,linux,shell_scripting,storage,sysadmin,ubuntu]
last_modified_at: 2022-12-25 01:32:03
---

Ubuntu (and derivatives) have been providing for some time a built-in way to setup last-generation systems (BTRFS, ZFS), however, the installer provides very limited (essentially, none) configuration.

In this article I'll explain how to setup a mirrored and encrypted BTRFS root filesystem.

Content:

- [Current outcome](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#current-outcome)
- [Comparison with ZFS](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#comparison-with-zfs)
- [Overview of the possible approaches](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#overview-of-the-possible-approaches)
  - [1. Setup the disks pre-installation](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#1-setup-the-disks-pre-installation)
  - [2. Setup the disks mid-installation](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#2-setup-the-disks-mid-installation)
  - [3. Setup the disks post-installation, via in-place filesystem conversion](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#3-setup-the-disks-post-installation-via-in-place-filesystem-conversion)
  - [4. Setup the disks post-installation, via filesystem copy](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#4-setup-the-disks-post-installation-via-filesystem-copy)
- [Procedure](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#procedure)
  - [1. Let Ubiquity setup the disk](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#1-let-ubiquity-setup-the-disk)
  - [2. Convert to the BTRFS filesystem](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#2-convert-to-the-btrfs-filesystem)
  - [3. Complete the installation](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#3-complete-the-installation)
  - [4. Setup the bootloader and password caching](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#4-setup-the-bootloader-and-password-caching)
  - [5. Completed!](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#5-completed)
- [Conclusion](/Installing-Ubuntu-22.04-on-a-mirrored-RAID-1-and-encrypted-BTRFS-root-filesystem#conclusion)

## Current outcome

The resulting setup is:

- Disk A: EFI, boot (BTRFS), encrypted swap, encrypted BTRFS root and home subvolumes
- Disk B: mirrors of the two BTRFS volumes

The EFI is not currently mirrored; the article will be updated in the near future with further improvements.

Note that for simplicity, on Disk B:

- corresponding to the EFI partition, an empty partition is created
- the Btrfs encrypted volume fills the space corresponding to the swap partition

## Comparison with ZFS

I've maintained a [ZFS installer](https://github.com/64kramsystem/zfs-installer) for a few years; I've ultimately archived it because, a ZFS setup comparable to the one proposed in this guide, is trivial to configure (just add a new device to the mirror after installation!).

Why choosing BTRFS over ZFS, then? In my opinion, there's no reason; ZFS is (again, in my opinion) superior in any aspect.

There are few exceptions where BTRFS is preferable:

1. when using very recent kernel versions (ZFS may not support them);
2. when hibernation is required (ZFS's support is not clear).

For users who don't have such requirements, I strongly advise against using BTRFS.

## Overview of the possible approaches

Any procedure that alters the standard course of installation is inherently unstable; the installer (Ubiquity) is very rough around the edges, and it doesn't help power users in any way, but most importantly, it doesn't have a specification. For this reason, even a well-written procedure that works at a point in time, may fail after some time for very minor, but still breaking, details.

A few strategies can be used; some of them have only a few moving parts, and they will likely be stable for a very long time.

Generally speaking, with solutions 3. and 4., barring architectural changes, the only potential for breakages is in the predefined names (but automated detection can be implemented, if one wants).

### 1. Setup the disks pre-installation

In this procedure, one does:

1. partially prepare the disk setup
2. patch the programs used
3. perform the installation as usual
4. complete the disk setup, and setup the bootloader

This procedure is the one described by the guides at [mutschler.dev](https://mutschler.dev) guides; it's not very stable, because there are many moving parts that can break the installer. Additionally, patching the programs is very unstable, and causes odd Ubiquity errors when it doesn't work.

### 2. Setup the disks mid-installation

In this procedure, one does:

1. let the installer partition the disk with its own LUKS setup
2. before proceeding, change the disk setup
3. perform the installation as usual
4. setup the bootloader and password caching

This procedure is a middle ground. There are considerably less moving parts than setting up the disks pre-installation, because the standard Ubuntu setup is used.

The disadvantage is that one still does some level of customization behind Ubiquity's back, which requires manually setting up the bootloader at the end.

### 3. Setup the disks post-installation, via in-place filesystem conversion

In this procedure, one does:

1. let the installer perform the whole setup
2. at the end, change the disk setup (the root filesystem is converted in-place)

This is a very stable procedure, as Ubiquity will do complete the installation without any underlying change. The only downside is that in-place conversion requires a few extra commands, because the converted partition is unoptimized.

### 4. Setup the disks post-installation, via filesystem copy

In this procedure, one does:

1. let the installer perform the whole setup
2. at the end, setup the second disk, copy the data, and mirror them back to the first disk

This is a very stable procedure, very much like #3. The only downside is that it's slower.

## Procedure

We assume the installation of Ubuntu 22.04 Jammy, on two disks, `sda` and `sdb`. If the devices are different, e.g. NVMe, just change the related variables.

### 1. Let Ubiquity setup the disk

- start Ubiquity, via `ubiquity --no-bootloader`
- at the partitioning step, choose "Advanced features", and set "Use LVM" and "Encrypt the installation"
- follow up with the installer, until the time zone step
- leave the installer open

It's not possible to make Ubiquity install the bootloader; with the btrfs changes, it crashes, without any meaningful message in the log. It's a bit odd, because installing and updating grub from a chrooted target, succeeds.

### 2. Convert to the BTRFS filesystem

- open a terminal, and switch to the root user
- set the following env variables accordingly:

```sh
# The options chosen below are indicative, and depend on the kernel version.
#
export BTRFS_OPTS=noatime,compress=zstd:1,space_cache=v2,discard=async
DISK1_DEV=/dev/sda
DISK2_DEV=/dev/sdb
PASSWORD=foo # same as the one entered during Ubiquity's setup
```

- then run the following script:

```sh
# This script doesn't require interaction; it displays some useful information during execution.

# Sample output:
#
#   /dev/mapper/vgubuntu--mate-root on /target type ext4 (rw,relatime,errors=remount-ro)
#   /dev/sda2 on /target/boot type ext4 (rw,relatime)
#   /dev/sda1 on /target/boot/efi type vfat (rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
#
mount | grep target

umount /target/boot/efi

# -rT: Copy content, including hidden files; not necessary, but better safe than sorry.
#
TEMP_DIR_BOOT=$(mktemp --directory)
cp -avrT /target/boot "$TEMP_DIR_BOOT"/

umount /target/boot

TEMP_DIR_TARGET=$(mktemp --directory)
cp -avrT /target "$TEMP_DIR_TARGET"/

umount /target

sgdisk $DISK1_DEV -R $DISK2_DEV
sgdisk -G $DISK2_DEV

CONTAINER2_NAME=$(basename $DISK2_DEV)3_crypt

echo -n "$PASSWORD" | cryptsetup luksFormat ${DISK2_DEV}3 -
echo -n "$PASSWORD" | cryptsetup luksOpen ${DISK2_DEV}3 "$CONTAINER2_NAME" -

# LUKS containers are not strictly necessary, however, it makes the second device structure consistent
# with the first; additionally, password caching is on volume groups.

# Display the containers; sample output:
#
#   sda3_crypt	(253, 0)
#   sdb3_crypt	(253, 3)
#
dmsetup ls --target=crypt

# Create a physical container.
#
pvcreate /dev/mapper/"$CONTAINER2_NAME"

# List physical containers; sample output:
#
#    PV                     VG            Fmt  Attr PSize  PFree
#    /dev/mapper/sda3_crypt vgubuntu-mate lvm2 a--  61.81g     0
#    /dev/mapper/sdb3_crypt               lvm2 ---  63.98g 63.98g
pvs

# Create a volume group.
#
vgcreate vgubuntu-mate-mirror /dev/mapper/"$CONTAINER2_NAME"

# Display the volume groups; sample output:
#
#  VG                   #PV #LV #SN Attr   VSize  VFree
#  vgubuntu-mate          1   2   0 wz--n- 61.81g     0
#  vgubuntu-mate-mirror   1   0   0 wz--n- 63.98g 63.98g
#
vgs

# Create a logical volume (in the volume group).
# [n]ame; [l] size in extents
#
lvcreate -l 100%FREE -n root vgubuntu-mate-mirror

# List the logical volumes; sample output:
#
#    LV     VG                   Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
#    root   vgubuntu-mate        -wi-a----- 58.16g
#    swap_1 vgubuntu-mate        -wi-ao---- <3.65g
#    root   vgubuntu-mate-mirror -wi-a----- 63.98g
#
lvs

mkfs.btrfs -f /dev/mapper/vgubuntu--mate-root

mount -o $BTRFS_OPTS /dev/mapper/vgubuntu--mate-root /target

btrfs device add /dev/mapper/vgubuntu--mate--mirror-root /target
btrfs balance start --full-balance --verbose -dconvert=raid1 -mconvert=raid1 /target

# Sample output:
#
#   Data,RAID1: Size:2.00GiB, Used:0.00B (0.00%)
#   Metadata,RAID1: Size:1.00GiB, Used:128.00KiB (0.01%)
#   System,RAID1: Size:64.00MiB, Used:16.00KiB (0.02%)
#
btrfs filesystem usage /target | grep -P '^\w+,'

btrfs subvolume create /target/@
btrfs subvolume create /target/@home

umount /target

mount -o subvol=@,$BTRFS_OPTS /dev/mapper/vgubuntu--mate-root /target
mkdir /target/home
mount -o subvol=@home,$BTRFS_OPTS /dev/mapper/vgubuntu--mate-root /target/home

cp -avrT "$TEMP_DIR_TARGET" /target/

mkfs.btrfs -f ${DISK1_DEV}2

mount -o $BTRFS_OPTS ${DISK1_DEV}2 /target/boot

btrfs device add /dev/sdb2 /target/boot
btrfs balance start --full-balance --verbose -dconvert=raid1 -mconvert=raid1 /target/boot

cp -avrT "$TEMP_DIR_BOOT" /target/boot/

mount ${DISK1_DEV}1 /target/boot/efi

sed -ie '/vgubuntu--mate-root/ d' /target/etc/fstab
sed -ie "/^# \/boot / i /dev/mapper/vgubuntu--mate-root /     btrfs defaults,subvol=@,$BTRFS_OPTS     0 1" /target/etc/fstab
sed -ie "/^# \/boot / i /dev/mapper/vgubuntu--mate-root /home btrfs defaults,subvol=@home,$BTRFS_OPTS 0 2" /target/etc/fstab
BOOT_PART_UUID=$(blkid -s UUID -o value ${DISK1_DEV}2)
sed -ie "/^UUID.* \/boot / c UUID=$BOOT_PART_UUID /boot btrfs defaults,$BTRFS_OPTS 0 2" /target/etc/fstab

# Can't set keyscript=decrypt_keyctl now; see the second part of the procedure.
#
LUKS_DISK2_PART_UUID=$(blkid -s UUID -o value ${DISK2_DEV}3)
echo "$CONTAINER2_NAME UUID=$LUKS_DISK2_PART_UUID none luks,discard" >> /target/etc/crypttab
```

### 3. Complete the installation

Now return to the installer, and complete the installation. At the end, click on "Continue"; don't reboot.

### 4. Setup the bootloader and password caching

- open a terminal, and switch to the root user
- set the following env variables accordingly:

```sh
export DISK1_DEV=/dev/sda
export BTRFS_OPTS=noatime,compress=zstd:1,space_cache=v2,discard=async # same as set in step #2
```

- then run the following script:

```sh
# This script doesn't require interaction.

mount -o subvol=@,$BTRFS_OPTS /dev/mapper/vgubuntu--mate-root /target
mount ${DISK1_DEV}2 /target/boot
mount ${DISK1_DEV}1 /target/boot/efi

for vdev in dev sys proc; do mount --bind /$vdev /target/$vdev; done

chroot /target
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf

# Cache the password, so that it's not asked twice for the two volume groups.
#
perl -i -pe 's/$/,keyscript=decrypt_keyctl/' /etc/crypttab

# The `keyutils` package is required in order to use `keyscript=decrypt_keyctl`.
# The `btrfs-progs` package is required to load the btrfs filesystem; without it, everything proceeds
# well, but on boot, the root filesystem won't load, opening busybox.
#
apt install -y grub-efi-amd64-signed keyutils btrfs-progs
grub-install ${DISK1_DEV}
update-grub

exit

umount --recursive /target
```

### 5. Completed!

The procedure has been completed. Reboot and enjoy!

## Conclusion

Ubiquity is a very limited and ultimately frustrating software. Fortunately, the operating system as a whole, has good support for BTRFS, so there is a range of options, which includes very stable, and conceptually simple (enough), solutions.

Happy mirroring 😁
