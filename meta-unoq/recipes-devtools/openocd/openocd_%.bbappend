# OpenOCD with the linuxgpiod adapter driver.
#
# meta-oe builds OpenOCD with PACKAGECONFIG "sysfsgpio remote-bitbang". Neither
# is enough to drive SWD on a board whose debug pins are ordinary GPIOs of the
# application processor: sysfsgpio is deprecated upstream and numbers pins
# globally, so the number changes when a gpiochip's base moves, while
# remote-bitbang needs a server on the other end.
#
# linuxgpiod addresses pins as (chip, offset), which is stable, and is what the
# Arduino UNO Q's own factory image uses to program its STM32U585. Enabling it
# is the only change needed: the driver is in OpenOCD already.
PACKAGECONFIG[linuxgpiod] = "--enable-linuxgpiod,--disable-linuxgpiod,libgpiod"
PACKAGECONFIG:append = " linuxgpiod"

# If the build fails in the linuxgpiod driver with unknown libgpiod symbols or
# struct members, OpenOCD and libgpiod disagree about the API version. meta-oe
# carries both lines, so pin whichever the OpenOCD revision wants, in local.conf
# or a distro conf:
#
#     PREFERRED_VERSION_libgpiod = "1.6.5"   # or "2.2.4"
#
# A given OpenOCD revision speaks exactly one of them.
