# Kernel configuration for the Arduino UNO Q: the USB gadget the board is
# reached through, and the symbols Pulsar needs that meta-exein cannot deliver
# here. See the comments in each .cfg for why.
#
# linux-% rather than linux-qcom% so this works whichever kernel recipe you
# build (meta-qcom's linux-qcom, meta-qcom-arduino's linux-arduino, a -next).
# The pattern also matches linux-libc-headers and linux-firmware, which are not
# kernels and configure nothing, so the SRC_URI addition is guarded.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Drop a name from this list to leave that fragment out, for example if you do
# not want the Exein stack.
UNOQ_KERNEL_FRAGMENTS ?= "unoq-usb-gadget unoq-exein"

SRC_URI:append = "${@' ' + ' '.join('file://%s.cfg' % f for f in (d.getVar('UNOQ_KERNEL_FRAGMENTS') or '').split()) if bb.data.inherits_class('kernel', d) else ''}"

# What the fragments asked for, checked against the configuration Kconfig
# actually produced.
#
# This check is the most useful thing in this layer. A fragment is a request,
# not a setting: a symbol that another option selects follows that option
# instead, and is dropped in silence. CONFIG_USB_LIBCOMPOSITE=y was requested
# for two builds, answered =m both times, and the only symptom was a board that
# presented nothing on USB. The warning below says so in one line at
# do_configure, long before anything is flashed.
UNOQ_EXPECTED_CONFIG ?= " \
    CONFIG_USB_CONFIGFS=y CONFIG_USB_LIBCOMPOSITE=y CONFIG_USB_F_ECM=y \
    CONFIG_USB_F_ACM=y CONFIG_U_SERIAL_CONSOLE=y CONFIG_BPF_LSM=y \
    CONFIG_SECURITY_NETWORK=y CONFIG_SECURITY_PATH=y CONFIG_FTRACE_SYSCALLS=y \
"

python unoq_check_kernel_config() {
    import os

    expected = (d.getVar('UNOQ_EXPECTED_CONFIG') or '').split()
    if not expected:
        return

    config = os.path.join(d.getVar('B') or '', '.config')
    if not os.path.exists(config):
        # linux-% also matches recipes that are not kernels and configure
        # nothing. Nothing to check, and nothing wrong.
        return

    actual = {}
    with open(config, 'r') as handle:
        for line in handle:
            line = line.strip()
            if line.startswith('CONFIG_') and '=' in line:
                key, _, value = line.partition('=')
                actual[key] = value
            elif line.startswith('# CONFIG_') and line.endswith(' is not set'):
                actual[line[2:-len(' is not set')]] = 'n'

    for item in expected:
        key, _, want = item.partition('=')
        got = actual.get(key, 'n')
        if got == want:
            continue
        bb.warn(
            "meta-unoq kernel configuration: asked for %s=%s, but the kernel was "
            "configured with %s=%s. A symbol that another option selects cannot be "
            "set from a fragment; set the option that selects it instead."
            % (key, want, key, got))
}
do_configure[postfuncs] += "unoq_check_kernel_config"
