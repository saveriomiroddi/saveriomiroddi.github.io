---
layout: post
title: Shell scripting adventures (Part 3, Terminal-based dialog boxes&colon; Whiptail)
tags: [gui,shell_scripting,sysadmin]
last_modified_at: 2019-10-11 19:16:00
---

This is the Part 3 (of 3) of the shell scripting adventures.

*Updated on 11/Oct/2019: Use `mapfile` for the check list widget returned entries.*

The following subjects are described in this part:

- [Introduction to Whiptail](/Shell-scripting-adventures-part-3#introduction-to-whiptail)
- [The mysterious redirections (`3>&1 1>&2 2>&3`)](/Shell-scripting-adventures-part-3#the-mysterious-redirections-31-12-23)
- [Widgets, with snippets](/Shell-scripting-adventures-part-3#widgets-with-snippets)
  - [Message box](/Shell-scripting-adventures-part-3#message-box)
  - [Yes/no box](/Shell-scripting-adventures-part-3#yesno-box)
  - [Gauge](/Shell-scripting-adventures-part-3#gauge)
  - [Radio list](/Shell-scripting-adventures-part-3#radio-list)
  - [Check list](/Shell-scripting-adventures-part-3#check-list)
  - [Password box](/Shell-scripting-adventures-part-3#password-box)
- [Other widgets](/Shell-scripting-adventures-part-3#other-widgets)
  - [Input box](/Shell-scripting-adventures-part-3#input-box)
  - [Text box](/Shell-scripting-adventures-part-3#text-box)
  - [Menus](/Shell-scripting-adventures-part-3#menus)

Since Whiptail is simple to use, the objective of this post is rather to show some useful code snippets/patterns.

The examples are taken from my [ZFS installer project](https://github.com/saveriomiroddi/zfs-installer) and [RPi VPN Router project](https://github.com/saveriomiroddi/rpi_vpn_router/blob/master/install_vpn_router.sh) installation scripts.

Previous chapters:

- [Introduction]({% post_url 2017-11-02-Shell-scripting-adventures-introduction %})
- [Part 1]({% post_url 2017-11-08-Shell-scripting-adventures-part-1 %})
- [Part 2]({% post_url 2017-11-22-Shell-scripting-adventures-part-2 %})

## Introduction to Whiptail

Whiptail is a dialog boxes program, with some useful widgets, which makes shell scripting more user-friendly; it's included in all the Debian-based distributions.

## The mysterious redirections (`3>&1 1>&2 2>&3`)

First, we start by explaining a related subject: the mysterious `3>&1 1>&2 2>&3`. Why is this typically used with Whiptail?

When we expect a "return value" from a command, we invoke a subshell (`$(...)`) and assign the output to a variable:

```sh
user_answer=$(whitptail ...)
```

But there's something important to be aware of: technically speaking, there is no "return value" (which is an improper definition) - what is assigned to the variable is the *stdout* output (*stderr* is not assigned!).

See this example:

```sh
$ result=$(echo value)               # `echo` defaults to stdout; nothing is printed, because stdout is captured!
$ echo $result
value
$ result=$(echo value > /dev/stderr) # this is printed, as it's stderr!
value
$ echo $result                       # empty!

```

Now, the way whiptail works is that the widgets are printed to stdout, while the return value is printed to stderr. We can capture only from stdout though, so what do we do?

Simple! We swap stdout and stderr! Printing the widgets to stderr is perfectly valid, and we get the "return value" in stdout.

The formal expression of that is `3>&1 1>&2 2>&3`, which means:

- we create a temporary file descriptor (#3) and point it to stdout (1)
- we redirect stdout (1) to stderr (2)
- we redirect stderr (2) to the temporary file descriptor (3), which points to stdout (due to the first step)

Result: stdout and stderr are switched ????

For some more details, there is a good [Stackoverflow explanation](https://unix.stackexchange.com/questions/42728/what-does-31-12-23-do-in-a-script)).

## Widgets, with snippets

### Message box

The message box shows a message, waiting for the user to hit the OK button:

 ![Message box]({{ "/images/2017-12-23-Shell-scripting-adventures-part-3/message_box.png" }})

Command:

```sh
$ message="Hello! This script will prepare an SDCard for using un a RPi3 as VPN router.
>
> Please note that device events (eg. automount) are disabled during the script execution."

$ whiptail --msgbox --title "Introduction" "$message" 20 78
```

The parameters are:

- `--title` specifies the title;
- then, the body message;
- finally, the last two parameters specify height and width, in number of characters.

### Yes/no box

The yes/no works like the message box, but has two buttons:

 ![Message box]({{ "/images/2017-12-23-Shell-scripting-adventures-part-3/yesno_box.png" }})

Commands:

```sh
$ message=$'Disable on board wireless (WiFi/Bluetooth, on RPi3)?
>
> On RPi 3, it\'s advised to choose `Yes`, since the traffic will go through eth0; choosing `No` will yield a working VPN Router nonetheless.
>
> On other models, the choice won\'t have any effect.'

$ if (whiptail --yesno "$message" 20 78); then
>   v_disable_on_board_wireless=1
> fi
```

Whiptail will return 1/255 if the user, respectively, hits No or Esc, and 0 in case of Yes.

The `if` condition branch, in this format, will be executed in case of Yes.

The message variable is quoted using [ANSI C Quoting](http://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html), which is helpful when we don't want string interpolation, but at the same time we want to avoid the awkward bash single quote quoting (`'\''`).

### Gauge

The gauge is a very interesting widget used for displaying a progress:

 ![Gauge]({{ "/images/2017-12-23-Shell-scripting-adventures-part-3/gauge.png" }})

The widget reads from the stdin a numeric value from 0 to 100, which regulates the progress, and exits when the stream is closed.

While the principle is easy, it can be tricky to convert the output of a given program to the format required; this is a real-world example:

```sh
$ (dd status=progress if="$v_os_image_filename" of="$v_sdcard_device") 2>&1 | \
>   stdbuf -o0 awk -v RS='\r' "/copied/ { printf(\"%0.f\n\", \$1 / $os_image_size * 100) }" | \
>   whiptail --title "Image writing" --gauge "Burning the image on the SD card..." 20 78 0
```

The last parameter is `0`, which is used for specifying the progress via stdin (otherwise, the passed percentage is displayed).

The functioning of this example is explained in detail in a section of [the previous post]({% post_url 2017-11-22-Shell-scripting-adventures-part-2 %}#progress-bars-processing-with-awk-and-stdbuf).

### Radio list

The radio list provides a list of entries, for choosing one:

 ![Radio list]({{ "/images/2017-12-23-Shell-scripting-adventures-part-3/radio_list.png" }})

An interesting way of implementing this functionality is to use a Bash arrays and associative arrays:

```sh
$ declare -A v_usb_storage_devices=([/dev/sdb]="My USB Key" [/dev/sdc]="My external HDD")

$ entry_options=()
$ entries_count=${#v_usb_storage_devices[@]}
$ message=$'Choose an external device. THE DEVICE WILL BE COMPLETELY ERASED.\n\nAvailable (USB) devices:\n\n'

$ for dev in "${!v_usb_storage_devices[@]}"; do
>   entry_options+=("$dev")
>   entry_options+=("${v_usb_storage_devices[$dev]}")
>   entry_options+=("OFF")
> done

$ v_sdcard_device=$(whiptail --radiolist --title "Device choice" "$message" 20 78 $entries_count -- "${entry_options[@]}" 3>&1 1>&2 2>&3)
$ echo "$v_sdcard_device" # let's say the first was chosen
/dev/sdb
```

We use `--` in case any of the `entry_options` started with `-`; if we don't do this, `whiptail` will think it's a commandline parameter.

Note that due to associative arrays not being ordered, the display order may not reflect the tuple insert ordering. In order to workaround this, one can manually order the keys (this is out of scope, unless readers will ask for it).

The general format of this widget parameters is:

```sh
whiptail --radiolist [--title mytitle] <body_message_header> <width> <height> <entries_count> -- <entry_1_key> <entry_1_description> <entry_1_state> [<other entry params>...]
```

In order to store the list definition parameters (key, description, state), we use an array:

- we cycle the definitions associative array (`for dev in "${!v_usb_storage_devices[@]}"`)
- for each cycle we append to the `$entry_options` array the key (device path), the description, and the default state (`OFF` for all, in this case)

The result is equivalent to:

```sh
whiptail --radiolist --title "Device choice" "Choose an external device. THE DEVICE WILL BE COMPLETELY ERASED.

Available (USB) devices:

" 20 78 2 -- /dev/sdb "My USB Key OFF" /dev/sdc "My external HDD OFF" 3>&1 1>&2 2>&3
```

I'm specifying equivalent because quoting is taken care of by using a quoted array for `entry_options` (`${entry_options[@]}`), so we don't have to worry about the content of the entries.

In one of the next posts of the series, I will show how to use udev to find external USB devices.

### Check list

The Check list is the same as the Radio list, except that it allows the user to select more values.

From a scripting perspective, the problem is to split the user selections, since we get a single string.

I'll use the same example as the Check list section, and I'll assume that both entries are selected:

```sh
$ declare -A usb_storage_devices=([/dev/sdb]="My USB Key" [/dev/sdc]="My external HDD")

$ entry_options=()
$ entries_count=${#usb_storage_devices[@]}
$ message=$'Choose an external device. THE DEVICE WILL BE COMPLETELY ERASED.\n\nAvailable (USB) devices:\n\n'
$ selected_device_names=()

$ for dev in "${!usb_storage_devices[@]}"; do
>   entry_options+=("$dev")
>   entry_options+=("${usb_storage_devices[$dev]}")
>   entry_options+=("OFF")
> done

$ selected_device_descriptions=$(whiptail --checklist --separate-output --title "Device choice" "$message" 20 78 $entries_count -- "${entry_options[@]}" 3>&1 1>&2 2>&3)

$ mapfile -t selected_device_names <<< "$selected_device_descriptions"

$ for device_name in "${selected_device_names[@]}"; do
>   echo "Device name: $device_name"
> done
Device name: My USB Key
Device name: My external HDD
```

By using the `--separate-output` options, Whiptail returns one line per selected entry, so that we easily parse the result.

For people not acquainted with Bash, the most notable concept is `mapfile` (sometimes used via the alias `readarray`):

- it reads a string (`$selected_device_descriptions`),
- splits it via separator (default: `\n`),
- removes the trailing separator from each entry (`-t`),
- and stores the result in the named array (`selected_device_names` - the `$` symbol is implied).

Note that `mapfile` requires the input to be in the same shell, therefore, `echo "$selected_device_descriptions" | mapfile ...` won't work, since the pipe operator (`|`) causes `mapfile` to run in a subshell.

A curiosity: `mapfile` is not an executable file - it's a built-in bash command, therefore, `man mapfile` won't work; instead, check out the Bash manual (`man bash-builtins`).

### Password box

A way to get a hidden password from the user is via an password box. This displays a dialog with two buttons labeled Ok and Cancel.

This widget is worth mentioning because in real world implementations, one wants the user to repeat the password.

This is a ready-made example:

```sh
while [[ "$passphrase" != "$passphrase_repeat" || ${#passphrase} -lt 8 ]]; do
  passphrase=$(whiptail --passwordbox "${passphrase_invalid_message}Please enter the passphrase (8 chars min.):" 20 78 3>&1 1>&2 2>&3)
  passphrase_repeat=$(whiptail --passwordbox "Please repeat the passphrase:" 20 78 3>&1 1>&2 2>&3)

  passphrase_invalid_message="Passphrase too short, or not matching! "
done
```

we use an initially empty variable (`passphrase_invalid_message`) for storing the error message, and we also count the password characters to enforce a minimum length of 8.

## Other widgets

This is a brief list of other widgets with their description; the examples can be found in the [Whiptail chapter of the Bash shell scripting Wikibook](https://en.wikibooks.org/wiki/Bash_Shell_Scripting/Whiptail).

### Input box

A way to get free-form input from the user is via an input box. This displays a dialog with two buttons labeled Ok and Cancel.

### Text box

A text box with contents of the given file inside. Add --scrolltext if the file is longer than the window.

### Menus

A menu should be used when you want the user to select one option from a list, such as for navigating a program.
