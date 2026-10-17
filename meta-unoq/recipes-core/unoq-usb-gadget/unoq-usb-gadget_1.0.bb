SUMMARY = "Reach an Arduino UNO Q over its USB-C cable"
DESCRIPTION = "A CDC-ECM + CDC-ACM USB gadget, a login console on it, and a static \
address for the resulting usb0 link. The board has no ethernet port and no console \
connector, so without this an image offers nothing a host can connect to: the only \
other way in is a 1.8 V serial header."
HOMEPAGE = "https://github.com/technosec-dev/arduino-uno-q-toolkit"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://usb-gadget.sh \
    file://usb-gadget.service \
    file://unoq-usb-console.service \
    file://10-usb0.network \
"

# A shell script, two units and a network file.
inherit allarch systemd
# Everything here is a local file, so there is no unpacked source tree and
# ${UNPACKDIR}/${BP} never exists. Without this, do_unpack warns
#
#   the directory ${UNPACKDIR}/${BP} ... pointed to by the S variable doesn't
#   exist - please set S within the recipe
#
# on every build. The files land directly in ${UNPACKDIR}.
S = "${UNPACKDIR}"


# systemd.bbclass writes the enablement symlinks at image build. Worth saying
# explicitly because the EmbedForge template that this layer grew out of could
# not do it: a template writes regular files, and a regular file dropped into
# multi-user.target.wants/ is inert, since systemd reads that directory for unit
# NAMES and then looks each one up in its search path. Units sat there doing
# nothing for days. A recipe has no such problem and needs no drop-in.
SYSTEMD_SERVICE:${PN} = "usb-gadget.service unoq-usb-console.service"

# The gadget needs libcomposite and the two functions built in, which the
# kernel fragments in this layer arrange. It also needs agetty for the console,
# which comes from util-linux.
RDEPENDS:${PN} = "util-linux-agetty"

do_install() {
    install -d ${D}${sbindir}
    install -m 0755 ${UNPACKDIR}/usb-gadget.sh ${D}${sbindir}/

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/usb-gadget.service ${D}${systemd_system_unitdir}/
    install -m 0644 ${UNPACKDIR}/unoq-usb-console.service ${D}${systemd_system_unitdir}/

    install -d ${D}${systemd_unitdir}/network
    install -m 0644 ${UNPACKDIR}/10-usb0.network ${D}${systemd_unitdir}/network/
}

FILES:${PN} = " \
    ${sbindir}/usb-gadget.sh \
    ${systemd_system_unitdir} \
    ${systemd_unitdir}/network \
"
