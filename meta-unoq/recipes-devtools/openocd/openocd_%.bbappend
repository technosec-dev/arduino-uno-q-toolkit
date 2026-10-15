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

# This needs libgpiod v1, and meta-oe defaults to v2.
#
# OpenOCD's configure asks pkg-config for "libgpiod < 2.0". meta-oe carries both
# libgpiod 1.6.5 and 2.2.4 under the same recipe name, so whichever the
# PREFERRED_VERSION resolves to is what configure sees. With the v2 line it
# answers no, and then fails outright because the adapter was requested:
#
#     configure: error: Linux libgpiod is required for adapter
#                       "Linux GPIO bitbang through libgpiod"
#
# So the build configuration has to pin the v1 line. This cannot be done from a
# bbappend without forcing a global preference on every other recipe too, so it
# belongs in local.conf or a distro conf:
#
#     PREFERRED_VERSION_libgpiod = "1.6.5"
#
# Verified against OpenOCD 0.12+git at the revision meta-oe builds
# (66ea461846a3a4a96687c9287c3f61ae8ce0b775). A later revision that gained
# libgpiod v2 support would want the opposite pin, so check configure.ac rather
# than trusting this note if you bump OpenOCD.
