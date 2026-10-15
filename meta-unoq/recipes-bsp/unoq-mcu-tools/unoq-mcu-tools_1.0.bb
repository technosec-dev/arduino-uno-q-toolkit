SUMMARY = "Program the Arduino UNO Q's STM32U585 from the board's own Linux side"
DESCRIPTION = "An OpenOCD adapter configuration for the UNO Q's SWD-over-GPIO wiring, \
and a script that flashes MCUboot and a signed Zephyr application to the MCU. The \
microcontroller has no external SWD pins: its debug lines are GPIOs of the QRB2210, so \
the application processor is the only thing that can program it."
HOMEPAGE = "https://github.com/technosec-dev/arduino-uno-q-toolkit"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://openocd-unoq.cfg \
    file://unoq-flash-mcu \
"

# The script needs OpenOCD with the linuxgpiod adapter, which the bbappend in
# this layer enables. Without that the configuration here loads and then fails
# with "Unknown adapter driver", so the dependency is real rather than tidy.
RDEPENDS:${PN} = "openocd"

# Not architecture specific: a shell script and a text configuration.
inherit allarch

do_install() {
    install -d ${D}${datadir}/unoq-mcu-tools
    install -m 0644 ${UNPACKDIR}/openocd-unoq.cfg ${D}${datadir}/unoq-mcu-tools/

    install -d ${D}${bindir}
    install -m 0755 ${UNPACKDIR}/unoq-flash-mcu ${D}${bindir}/
}

FILES:${PN} = " \
    ${datadir}/unoq-mcu-tools \
    ${bindir}/unoq-flash-mcu \
"
