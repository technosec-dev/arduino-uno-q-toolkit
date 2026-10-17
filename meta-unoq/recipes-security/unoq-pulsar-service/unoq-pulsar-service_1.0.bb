SUMMARY = "Run the Exein Pulsar agent as a systemd service"
DESCRIPTION = "A systemd unit for pulsard. meta-exein installs the Pulsar binaries and \
no unit, so on a systemd image the agent is present and never runs, which is easy to \
miss because nothing fails. Separate from the rest of this layer so an image can take \
the board support without the Exein stack."
HOMEPAGE = "https://github.com/technosec-dev/arduino-uno-q-toolkit"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://pulsar.service"

inherit allarch systemd
# Everything here is a local file, so there is no unpacked source tree and
# ${UNPACKDIR}/${BP} never exists. Without this, do_unpack warns
#
#   the directory ${UNPACKDIR}/${BP} ... pointed to by the S variable doesn't
#   exist - please set S within the recipe
#
# on every build. The files land directly in ${UNPACKDIR}.
S = "${UNPACKDIR}"


SYSTEMD_SERVICE:${PN} = "pulsar.service"

# pulsar comes from meta-exein. If that layer is not in your bblayers this
# recipe is the wrong thing to install, which is why it is not in
# packagegroup-unoq-base.
RDEPENDS:${PN} = "pulsar"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/pulsar.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} = "${systemd_system_unitdir}"
