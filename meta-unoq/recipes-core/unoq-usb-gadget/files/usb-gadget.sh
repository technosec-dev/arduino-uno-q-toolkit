#!/bin/sh
# Present the board to a host over the USB-C cable it is already powered by:
# CDC-ECM for an address, CDC-ACM for a login shell. Without this the image
# offers nothing at all, since there is no ethernet port, no network
# configuration, and the only console is a 1.8 V header.
#
# EVERY command here has to be a BusyBox applet with BusyBox semantics. The
# first version of this used "head -1", a GNU coreutils extension BusyBox
# refuses:
#
#     usb-gadget.sh: head: invalid option -- '1'
#
# so it exited non-zero on every boot, the gadget never bound, and the board
# looked dead on USB while in fact reaching multi-user.target every time.
set -e
G=/sys/kernel/config/usb_gadget/unoq

grep -q ' /sys/kernel/config ' /proc/mounts 2>/dev/null \
    || mount -t configfs none /sys/kernel/config

# /sys/kernel/config/usb_gadget is created by libcomposite, so its absence means
# the module is not loaded. Report that rather than hiding it: an earlier version
# opened with "modprobe libcomposite 2>/dev/null || true", which survived a
# denied modprobe and then died on the first mkdir under set -e, from a hook
# whose exit status systemd had been told to ignore. Nothing about the cause
# reached the journal. With the kernel fragment in this layer libcomposite is
# built in and this has nothing left to do.
if [ ! -d /sys/kernel/config/usb_gadget ]; then
    modprobe libcomposite || true
fi
if [ ! -d /sys/kernel/config/usb_gadget ]; then
    echo "usb-gadget: libcomposite is not loaded and modprobe did not load it," >&2
    echo "usb-gadget: so /sys/kernel/config/usb_gadget does not exist and there" >&2
    echo "usb-gadget: is no gadget to build. Check CONFIG_USB_CONFIGFS=y." >&2
    exit 1
fi

if [ -d $G ]; then
    echo "usb-gadget: $G already exists, leaving it as it is"
    exit 0
fi

# There is exactly one controller on this board. Found with a glob so the shell
# does the work and no external tool can reject an option.
udc=""
for d in /sys/class/udc/*; do
    [ -e "$d" ] || continue
    udc=${d##*/}
    break
done
if [ -z "$udc" ]; then
    echo "usb-gadget: no UDC under /sys/class/udc, cannot bind a gadget" >&2
    exit 1
fi

mkdir -p $G
echo 0x1d6b > $G/idVendor
echo 0x0104 > $G/idProduct
mkdir -p $G/strings/0x409
echo "Arduino" > $G/strings/0x409/manufacturer
echo "UNO Q" > $G/strings/0x409/product
echo 0123456789 > $G/strings/0x409/serialnumber
mkdir -p $G/configs/c.1/strings/0x409
echo ecm-acm > $G/configs/c.1/strings/0x409/configuration
echo 250 > $G/configs/c.1/MaxPower
mkdir -p $G/functions/ecm.usb0
# Fixed addresses so the host interface name does not change between boots.
echo 02:00:00:00:00:01 > $G/functions/ecm.usb0/host_addr
echo 02:00:00:00:00:02 > $G/functions/ecm.usb0/dev_addr
mkdir -p $G/functions/acm.GS0
ln -sf $G/functions/ecm.usb0 $G/configs/c.1/
ln -sf $G/functions/acm.GS0 $G/configs/c.1/
echo "$udc" > $G/UDC
echo "usb-gadget: bound to $udc"
