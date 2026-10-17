SUMMARY = "Exein Pulsar runtime security on an Arduino UNO Q"
DESCRIPTION = "Pulsar and a systemd unit to run it. Needs meta-exein in your bblayers, \
and the kernel fragment this layer ships, without which Pulsar loses its eBPF LSM path \
and falls back to kprobes without saying so."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

RDEPENDS:${PN} = " \
    pulsar \
    unoq-pulsar-service \
"
