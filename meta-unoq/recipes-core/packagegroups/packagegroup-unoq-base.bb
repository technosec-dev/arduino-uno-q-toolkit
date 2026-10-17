SUMMARY = "Board support for the Arduino UNO Q"
DESCRIPTION = "What an image needs to be reachable and to program the board's MCU: the \
USB gadget and its console, and OpenOCD with the UNO Q SWD pin map plus unoq-flash-mcu. \
No Exein stack: see packagegroup-unoq-exein for that."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

RDEPENDS:${PN} = " \
    unoq-usb-gadget \
    unoq-mcu-tools \
"
