# Arduino UNO Q: flashing, recovery, and running your own image

A practical guide to putting an operating system on an Arduino UNO Q and
getting the factory one back afterwards.

The UNO Q has two processors. The Qualcomm QRB2210 (the MPU) runs Linux from
eMMC. The STM32U585 (the MCU) runs its own firmware and is programmed
separately. This guide is about the Linux side.

There is no SD card slot for the MPU, so there is no "take the card out and fix
it on your laptop". The only way in is the SoC's Emergency Download mode (EDL),
which lives in the chip's mask ROM. That cuts both ways: it is the only way to
install anything, and it is also why the board is very hard to brick
permanently. A bad image means the board will not boot until you flash it
again, not that the board is gone.

## What you need

- A **USB-C cable that carries data**. See the troubleshooting section; this
  catches more people than anything else here.
- A **jumper shunt** (2.54 mm) or a female-to-female jumper wire.
- A Linux host. The tools exist for macOS and Windows too, but the commands
  below are Linux.
- About 2.5 GB of disk for the factory image.

Optional but worth having:

- A **1.8 V** USB-UART adapter, if you plan to build your own images. Explained
  under "Getting a shell".

## Get the tools

Both come from Arduino and are the same binaries their official flasher uses.

- **Arduino Flasher CLI**: https://github.com/arduino/arduino-flasher-cli/releases
  Downloads and flashes Arduino's Debian images.
- **qdl**: https://github.com/arduino/qdl-packing/releases
  The Qualcomm download tool. Needed only if you flash an image that is not
  Arduino's, for example one you built yourself. The Flasher CLI embeds its own
  copy, so you do not need this for recovery alone.

```sh
tar xzf arduino-flasher-cli-*-linux-amd64.tar.gz
tar xzf qdl_*_Linux_64bit.tar.gz
./arduino-flasher-cli version
./qdl --version
```

## Keep a copy of the factory image before you need it

This is the single most useful thing you can do before experimenting.

```sh
./arduino-flasher-cli list
./arduino-flasher-cli download unoq --dest-dir ~/arduino-uno-q-toolkit
```

`list` shows every published image, not only the newest, and `download
--version <v>` fetches any of them. The image is roughly 2.2 GB and arrives as
a `.tar.zst`.

Record its checksum so a truncated copy is obvious later:

```sh
sha256sum ~/arduino-uno-q-toolkit/arduino-unoq-debian-image-*.tar.zst > ~/arduino-uno-q-toolkit/SHA256
```

Keep it on real disk, not in `/tmp`. On most distributions `/tmp` is a RAM
filesystem, so a 2.2 GB download there costs you memory and disappears at the
next reboot, which is exactly when you are likely to want it.

The Flasher CLI can install from a local file:

```sh
./arduino-flasher-cli flash ~/arduino-uno-q-toolkit/arduino-unoq-debian-image-20260528-558.tar.zst
```

Prefer that over `flash unoq`, which downloads the image each time. A board
that will not boot is the worst moment to discover your internet is down.

## Host setup, once

`qdl` and `adb` both need raw USB access.

```sh
# EDL mode (flashing)
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", ATTR{idProduct}=="9008", MODE="0660", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/50-qdl.rules

# The board running Arduino's image (adb)
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="2341", ATTR{idProduct}=="0078", MODE="0660", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/51-arduino-unoq.rules

sudo udevadm control --reload-rules
sudo udevadm trigger
```

`MODE="0660"` with `TAG+="uaccess"` grants access to the user logged in at the
machine, rather than to everyone as `MODE="0666"` would.

Replug the board after adding a rule. Rules apply when a device appears, not
retroactively.

ModemManager will grab the board in EDL, because it looks like a modem:

```sh
sudo systemctl stop ModemManager
```

## Entering EDL

EDL is entered by holding the `USB_BOOT` strap low while the board powers on.
The strap is sampled once at power-on, so the board must be fully unpowered
first. Unplugging USB-C is enough.

The JCTL header is a 2x5 next to the USB-C connector:

| | left | right |
| --- | --- | --- |
| row 1 | `VBUS_DISABLE` | `+1V8 OUT` |
| row 2 | `PMIC_RESET` | `GND` |
| row 3 | `SOC_SE4_RX` | `VOL_UP` |
| row 4 | `SOC_SE4_TX` | `VOL_DOWN` |
| row 5 | `USB_BOOT` | `GND` |

`USB_BOOT` and a `GND` sit opposite each other in row 5, so a jumper shunt
placed **across that end row** is all that is needed.

### Identify the row electrically, do not count on a photograph

Published pictures disagree about whether the header is at the upper left or
the upper right, and the board can be the other way round from whatever diagram
you are looking at. With the board unpowered, use a multimeter in continuity
mode from a known ground (the USB-C shell, or a mounting hole) to the two pins
at **each** end of the header:

- the end row with **exactly one** ground pin is row 5: that is the one to
  jumper
- the end row with **no** ground pin is row 1: leave it alone

There are only two grounds on this header, at rows 2 and 5, and only row 5 is
at an end, so this is unambiguous.

### Three ways to damage the board

- **The other end row.** A shunt there connects `VBUS_DISABLE` to `+1V8 OUT`.
- **Along a column instead of across a row.** `+1V8 OUT` (row 1) sits directly
  above `GND` (row 2), so a shunt down that column shorts the 1.8 V regulator
  to ground.
- **A 3.3 V or 5 V UART adapter** on `SOC_SE4_TX`/`RX`. The entire header is
  1.8 V. `+1V8 OUT` is a reference for a level shifter, never a supply.

### Sequence

1. Disconnect USB-C so the board is fully unpowered.
2. Fit the shunt across row 5 (`USB_BOOT` to `GND`).
3. Connect USB-C with the shunt still in place.
4. Confirm: `lsusb | grep 05c6` should show `05c6:9008`, Qualcomm HS-USB
   QDLoader. Running normally the board is `2341:0078` instead.
5. Flash.
6. **Remove the shunt** and power-cycle. Left in, the board re-enters EDL on
   every boot and never starts what you installed.

### Rehearse it first

Do steps 1 to 4, then 6, with no flashing in between. That proves the jumper
position, your udev rule and that the host can see the board, while the system
on it is still working. It is a much better moment to discover a problem.

## Flashing your own image

A build system that targets this board produces a `qcomflash` package: a
directory containing `prog_firehose_ddr.elf`, `rawprogram*.xml`, `patch*.xml`
and the partition images.

```sh
cd <the unpacked qcomflash directory>
qdl --allow-missing --storage emmc prog_firehose_ddr.elf rawprogram0.xml patch0.xml
```

`--storage emmc` matters: eMMC is the board's only boot storage. If several
boards are attached, `--serial=<serial>` picks one.

A successful run ends with `partition 0 is now bootable`.

## Getting a shell

### On Arduino's image

The factory image runs `adbd`, so use adb:

```sh
adb devices
adb shell
```

The CDC-ACM serial port the board also exposes is a channel for Arduino's
tooling, not a login console, so do not expect a prompt from `minicom` on it.

If `adb devices` is empty while `lsusb` shows `2341:0078`, it is the udev rule.
Add it, replug, then `adb kill-server` once and try again.

### On your own image

**This is where most custom images go wrong.** A minimal Linux image has no
reason to present anything over USB, and this board has no ethernet port, so a
freshly flashed custom image can boot perfectly and still look completely dead
from the host. Nothing in `lsusb`, no serial port, no network.

Plan one of these before you flash:

- **A USB gadget.** The board has one UDC, `4e00000.usb`, and Arduino drive it
  through configfs: their gadget is `g1`, bound to that controller. A composite
  gadget with CDC-ECM (an IP link) plus CDC-ACM (a login console on `ttyGS0`)
  gives you two ways in over the cable that already powers the board. The
  kernel ships `libcomposite`, `usb_f_ecm`, `usb_f_acm` and `usb_f_rndis`;
  there is no legacy `g_ether`, so `modprobe g_ether` will silently do nothing.
- **The serial console** on `SOC_SE4_TX` and `SOC_SE4_RX`, JCTL rows 3 and 4,
  115200 baud. This is the only way to watch a boot that fails before userspace,
  and the only one that works when the image is broken. It needs a **1.8 V**
  adapter.
- **WiFi**, if you configure credentials into the image.

If you build images for this board regularly, get the 1.8 V adapter. Without a
console, an image that halts in the bootloader and an image that boots fine but
presents no USB look exactly the same from the host, and you will spend flash
cycles guessing between them.

## Troubleshooting

**Nothing appears in `lsusb` at all, but the board's power LED is on.**
Almost always a charge-only USB-C cable. Such a cable carries power but not
data, so the board powers up and blinks happily while the host sees nothing.
Try another cable before suspecting anything else, and prefer a port directly
on the machine over one behind a hub.

**The board keeps disconnecting and reconnecting every few seconds.**
Check whether a tool on the host is probing it. Starting and stopping the adb
server, or other software that opens USB devices to interrogate them, causes
re-enumeration that looks like the board resetting. Confirm with `uptime` over
adb before concluding the board is unstable.

**`qdl` says it cannot open the USB device.**
The udev rule is missing or was added after the board enumerated. Add it,
reload rules, and replug.

**The board boots to EDL (`05c6:9008`) with no jumper fitted.**
The ROM found nothing bootable and fell back. Flash a known-good image.

**You flashed your own image and the board shows nothing.**
See "On your own image" above. Flash the factory image to confirm the board and
your procedure are fine; if the factory image comes up as `2341:0078`, the
hardware and your flashing are good and the problem is in your image.

## If all else fails

Enter EDL and flash the factory image. EDL is in ROM and does not depend on
anything stored on eMMC, so no image you write can take that path away.
