/*
 * SPDX-License-Identifier: MIT
 *
 * Draw on the Arduino UNO Q's 13x8 charlieplexed LED matrix.
 *
 * The matrix is a display, not 104 addressable LEDs. The board's devicetree
 * sets zephyr,display = &led_matrix, the charlieplex-led-matrix driver scans
 * the panel from TIM17 fast enough for persistence of vision, and an
 * application just writes a framebuffer through the display API.
 *
 * Two properties of that framebuffer are easy to get wrong and silent when you
 * do, so they are written down here rather than discovered twice.
 *
 * The driver advertises PIXEL_FORMAT_MONO01 and nothing else: one bit per
 * pixel, set meaning lit. The grayscale-bits = <3> in the devicetree is the
 * driver's internal duty resolution, which display_set_brightness() reaches and
 * a write does not, so there are no intermediate levels available here.
 *
 * And its write path reads each row at src + row * (pitch / 8), taking a column
 * as (byte >> (col % 8)) & 1. So pitch is counted in PIXELS, it has to be a
 * whole number of bytes, and the bits run least-significant-first across each
 * byte rather than MSB-first as display code often assumes. For 13 columns that
 * means a pitch of 16 and a stride of two bytes per row, with the top three
 * bits of the second byte unused.
 */
#include <string.h>

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/display.h>
#include <zephyr/sys/printk.h>
#include <zephyr/sys/util.h>

#define MATRIX DT_CHOSEN(zephyr_display)

/* Geometry from the devicetree, not from constants of our own, so a board whose
 * matrix differs cannot quietly make this write past the end of the buffer. */
#define WIDTH  DT_PROP(MATRIX, width)
#define HEIGHT DT_PROP(MATRIX, height)

/* Pitch in pixels, rounded up to a whole byte, per the write path above. */
#define PITCH  ROUND_UP(WIDTH, 8)
#define STRIDE (PITCH / 8)

static uint8_t framebuf[HEIGHT * STRIDE];

static void fb_clear(void)
{
	memset(framebuf, 0, sizeof(framebuf));
}

static void fb_set(int x, int y)
{
	if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) {
		return;
	}
	framebuf[(y * STRIDE) + (x / 8)] |= BIT(x % 8);
}

static int fb_flush(const struct device *dev)
{
	const struct display_buffer_descriptor desc = {
		.buf_size = sizeof(framebuf),
		.width = WIDTH,
		.height = HEIGHT,
		.pitch = PITCH,
	};

	return display_write(dev, 0, 0, &desc, framebuf);
}

/* A glyph is HEIGHT rows of exactly WIDTH characters, '#' lit. Written out as
 * text because a reader can check it against the panel at a glance, which a
 * table of hex bitmaps does not allow. */
static const char *const heart[HEIGHT] = {
	"  ###   ###  ",
	" ##### ##### ",
	"#############",
	"#############",
	" ########### ",
	"  #########  ",
	"   #######   ",
	"     ###     ",
};

static void fb_glyph(const char *const rows[])
{
	fb_clear();

	for (int y = 0; y < HEIGHT; y++) {
		for (int x = 0; x < WIDTH; x++) {
			if (rows[y][x] == '#') {
				fb_set(x, y);
			}
		}
	}
}

int main(void)
{
	const struct device *dev = DEVICE_DT_GET(MATRIX);

	if (!device_is_ready(dev)) {
		printk("LED matrix not ready\n");
		return -ENODEV;
	}

	/* MONO01 is the only format this driver takes. Asking for it explicitly
	 * means a future driver that offers more cannot silently change what the
	 * bytes below mean. */
	if (display_set_pixel_format(dev, PIXEL_FORMAT_MONO01) < 0) {
		printk("LED matrix refused PIXEL_FORMAT_MONO01\n");
		return -ENOTSUP;
	}

	display_blanking_off(dev);
	printk("UNO Q LED matrix: %ux%u, pitch %u px, %u bytes\n",
	       (unsigned int)WIDTH, (unsigned int)HEIGHT,
	       (unsigned int)PITCH, (unsigned int)sizeof(framebuf));

	while (1) {
		/* A column sweep first, because it is the cheap check that the
		 * geometry and the bit order are right: wrong stride walks the
		 * column diagonally, and MSB-first order sweeps each group of
		 * eight backwards. Either is obvious on the panel and neither
		 * produces an error. */
		for (int x = 0; x < WIDTH; x++) {
			fb_clear();
			for (int y = 0; y < HEIGHT; y++) {
				fb_set(x, y);
			}
			if (fb_flush(dev) < 0) {
				printk("display_write failed\n");
				return -EIO;
			}
			k_msleep(60);
		}

		/* Then an arbitrary bitmap, which the sweep does not exercise. */
		fb_glyph(heart);
		if (fb_flush(dev) < 0) {
			printk("display_write failed\n");
			return -EIO;
		}
		k_msleep(1200);
	}

	return 0;
}
