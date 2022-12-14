---
layout: post
title: "Enabling the S3 sleep state (suspend-to-RAM) on the Lenovo Yoga 7 AMD Gen 7 (and possibly, others)"
tags: [hardware,linux,sysadmin,ubuntu]
last_modified_at: 2022-12-14 23:10:17
---

The lack of support for the Suspend-to-RAM functionality (ie. S3 sleep state), and its replacement with the disastrous Connected Standby (ie. S0ix sleep state) is a well-known plague on modern laptops.

In this article I'll describe how to restore support for it on the Lenovo Yoga 7 AMD Gen 7. This method likely applies to other models; for example, the [HP ENVY x360](https://h30434.www3.hp.com/t5/Notebook-Hardware-and-Upgrade-Questions/ACPI-Problem-Can-t-suspend-to-RAM-S3-in-Linux/td-p/7682336)) has the same S3 conditional logic in the DSDT.

Content:

- [Procedure](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#procedure)
  - [Preliminary operations](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#preliminary-operations)
  - [Dumping and patching the DSDT](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#dumping-and-patching-the-dsdt)
  - [Overriding the DSDT](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#overriding-the-dsdt)
    - [Initrd hook](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#initrd-hook)
    - [Patching the kernel](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#patching-the-kernel)
    - [Prepending an initrd image](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#prepending-an-initrd-image)
    - [GRUB setting (not universal)](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#grub-setting-not-universal)
  - [Result](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#result)
  - [Debugging](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#debugging)
  - [Methods not working](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#methods-not-working)
- [References](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#references)
- [Conclusion](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others#conclusion)

## Procedure

### Preliminary operations

The procedure is generic, and can be performed on any Linux distribution; the difference should be just in the tools package; on Ubuntu, install the `acpica-tools`:

```sh
$ sudo apt install -y acpica-tools
```

In order to verify which sleep states the machine supports, run:

```sh
# This message comes from the kernel ring buffer, which rotates; if nothing is shown, reboot and
# rerun the command.
#
$ sudo dmesg | grep 'ACPI.*supports S'
[    0.309933] ACPI: PM: (supports S0 S4 S5)
```

### Dumping and patching the DSDT

Dump the DSDT:

```sh
# Can also be achieved via `acpidump -b`, which dumps more data (not required in this context).
#
$ sudo cat /sys/firmware/acpi/tables/DSDT > dsdt.dat
```

Disassemble it:

```sh
$ iasl -d dsdt.dat
```

The resulting disassembly, `dsdt.dsl`, is human readable. On the Lenovo Yoga 7 AMD Gen 7, one can see that the S3 state is supported, but with conditionals:

```
    If ((CNSB == Zero))
    {
        If ((DAS3 == One))
        {
            Name (_S3, Package (0x04)  // _S3_: S3 System State
            {
                0x03, 
                0x03, 
                Zero, 
                Zero
            })
        }
    }
```

I don't have domain knowledge, however, my educated guess is that this is (primarily) a check whether the option is set in the firmware (the Lenovo Yoga 7 AMD Gen 7 allows the user access only very basic firmware settings, and this is not included).

The fix is simply to remove the conditionals; this can be done with any editor, or with a Perl script:

```sh
# A backup file (`dsdt.dsl.bak`) is created.
#
# Regex: remove the four lines before "S3_: S3 System State" and the two lines after; keep the six
# lines in between.
#
perl -0777 -i.bak -pe 's/(.+\n){4}(.+_S3_: S3 System State\n(.+\n){6})(.+\n){2}/$2/m' dsdt.dsl
```

We also need to bump the DSDT revision, otherwise when booting, the patched DSDT will be overridden (this is not required if patching the kernel):

```sh
# Regex: replace the last value of the DSDT table header definition:
#
perl -i -pe 's/^DefinitionBlock.+\K0x00000001/0x00000002/' dsdt.dsl
```

Now we just reassemble the DSDT:

```sh
iasl -tc dsdt.dsl
```

This will generate multiple files - different override methods require different files.

### Overriding the DSDT

There are different approaches to overriding the DSDT. I'll describe what I've tested, and the pros/cons.

#### Initrd hook

The best method is to add an initrd hook; it's clean, and it doesn't require any maintenance:

```sh
# Create the initrd image, including the patched DSDT in the approprite directory, which corresponds
# to the `firmware/acpi` subdirectory of the `/sys` virtual filesystem.
#
mkdir -p kernel/firmware/acpi
cp patched-dsdt.aml kernel/firmware/acpi
find kernel | cpio -H newc --create | sudo tee /boot/acpi_override > /dev/null

# Now create the hook. Note that this is not the canonical style for hooks; it's been reduced to the
# simplest form, for clarity.
#
sudo tee /etc/initramfs-tools/hooks/acpi_override << 'SH'
#!/bin/sh

if [ "$1" = prereqs ]; then
  echo
else
  . /usr/share/initramfs-tools/hook-functions
  prepend_earlyinitramfs /boot/acpi_override
fi
SH

sudo chown root: /etc/initramfs-tools/hooks/acpi_override
sudo chmod 755 /etc/initramfs-tools/hooks/acpi_override

# Now update the initramfs (for all the kernels).
#
update-initramfs -k all -u
```

#### Patching the kernel

For those who use a patched kernel, it's just a matter of setting the related configuration symbol(s):

```sh
# Run from the kernel source root.
#
scripts/config --set-val CONFIG_ACPI_CUSTOM_DSDT      y
scripts/config --set-val CONFIG_ACPI_CUSTOM_DSDT_FILE '"/path/to/dsdt.hex"'
```

Then recompile and boot. Done!

#### Prepending an initrd image

This is a method that works, but it's discouraged, since requires repeating the operation every time the initrd image is regenerated (essentially, for any kernel update).

```sh
# Create the initrd image, including the patched DSDT in the approprite directory, which corresponds
# to the `firmware/acpi` subdirectory of the `/sys` virtual filesystem.
#
$ mkdir -p kernel/firmware/acpi
$ cp dsdt.aml kernel/firmware/acpi
$ find kernel | cpio -H newc --create > initrd-patched-dsdt.img

# Backup the initrd for the running kernel, and prepend the initrd image just created, to the
# regular kernel one.
#
$ cp /boot/initrd.img-"$(uname -r)" .
$ cat initrd-patched-dsdt.img initrd.img-"$(uname -r)" | sudo tee /boot/initrd.img-"$(uname -r)" > /dev/null
```

The source, for the generic method, is in the [kernel docs](https://docs.kernel.org/admin-guide/acpi/initrd_table_override.html).

#### GRUB setting (not universal)

Another clean and automatic method is to set the custom initrd image via GRUB. Note that this method has been reported to work, but it didn't on my O/S.

```sh
$ sudo cp dsdt.aml /boot/patched-dsdt.aml
$ echo acpi /boot/patched-dsdt.aml | sudo tee -a /boot/grub/custom.cfg
$ sudo update-grub
```

This should work on systems where the `/boot/grub/custom.cfg` is included by default; on Ubuntu, this rule is encoded in `/etc/grub.d/41_custom`:

```sh
$ cat /etc/grub.d/41_custom
#!/bin/sh
cat <<EOF
if [ -f  \${config_directory}/custom.cfg ]; then
  source \${config_directory}/custom.cfg
elif [ -z "\${config_directory}" -a -f  \$prefix/custom.cfg ]; then
  source \$prefix/custom.cfg
fi
EOF
```

In case a given distro doesn't include `/boot/grub/custom.cfg`, just add the rule file.

### Result

On reboot, support for S3 sleep state will be advertised:

```sh
$ sudo dmesg | grep 'ACPI.*supports S'
[    0.648536] ACPI: PM: (supports S0 S3 S4 S5)

# Go to sleep!
#
$ systemctl suspend
```

Watch out! After suspending, closing the laptop lid will wake up the system!! I don't know what precisely causes this, but fixing this behavior is outside the scope of the article.

### Debugging

If the procedure doesn't yield the desired effect, my advice is to first rule out problems with the boot override; disable the S4 sleep support (just comment or remove the corresponding block), and if, after boot, the change has been successfully applied:

```sh
$ sudo dmesg | grep 'ACPI.*supports S'
[    0.309933] ACPI: PM: (supports S0 S5)
```

then the problem is in the DSDT patch.

### Methods not working

The following methods either didn't work on my system, or they're not robust:

- [Setting `GRUB_EARLY_INITRD_LINUX_CUSTOM`](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others-https://gist.github.com/javanna/38d019a373085e1ba0c784597bc7ec73) won't work on at least some operating systems (ie. Fedora);
- [Loading the ACPI SSDTs from EFI variables](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others-https://www.kernel.org/doc/html/latest/admin-guide/acpi/ssdt-overlays.html#loading-acpi-ssdts-from-efi-variables) yielded a write error on my system;
- [Loading ACPI SSDTs from configfs](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others-https://www.kernel.org/doc/html/latest/admin-guide/acpi/ssdt-overlays.html#loading-acpi-ssdts-from-configfs) didn't work on my system as well, due to configfs not having the required directory after mount;
- Various ways to enable advanced firmware settings on the given laptop model.

I don't exclude that with appropriate changes, some of the methods above can work.

## References

- ACPI DSDT, on the [OSDev wiki](https://wiki.osdev.org/DSDT)
- Sleeping states, on [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/system-sleeping-states)
- S0ix sleeping state, on [Anandtech](https://www.anandtech.com/show/6355/intels-haswell-architecture/3) (but doesn't consider the downsides)
- [Another article](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others-https://valinet.ro/2020/12/08/Enable-S3-sleep-on-Lenovo-Yoga-Slim-7-14are05.html), with context, on enabling an S3 support on a different Yoga model, on Windows
- [Kernel DSDT patch](/Enabling-the-S3-sleep-suspend-on-the-Lenovo-Yoga-7-AMD-Gen-7-and-possibly-others-http://kernel.dk/acpi.patch) frequently mentioned

## Conclusion

Removal of the S3 sleep state is a terrible state of affairs, not for the technical problem itself, rather, because it shows how a misguided and obtuse decision from Microsoft had a profound effect on the whole computing ecosystem.

Some hardware producers do make available the S3 option in the firmware; vote with your wallet (and some noise 😁).
