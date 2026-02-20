# LVGL + Zig Guide

This guide explains how to use LVGL from Zig in this project, including the integrated SH8601 AMOLED board path and a practical API walkthrough.

## 1. What you get

The Zig module `idf.lvgl` wraps the most common LVGL/`esp_lvgl_port` calls so examples do not need raw `extern` declarations.

Implemented in:

- `imports/lvgl.zig`
- `main/lvgl_integrated_display_helpers.c`
- `main/examples/lvgl-integrated-display.zig` (full Zig SH8601 + FT5x06 bring-up path)

You can use it in Zig with:

```zig
const idf = @import("esp_idf");
const lvgl = idf.lvgl;
```

## 2. Select an LVGL app

Use `menuconfig` to pick a Zig entry file:

```sh
idf.py menuconfig
```

Then open:

- `Zig Application Selection`
- choose `main/examples/lvgl-basic.zig` or `main/examples/lvgl-integrated-display.zig`

The integrated display option (`lvgl-integrated-display.zig`) is the board-ready path for the SH8601 AMOLED setup.
It now demonstrates a fully Zig-driven display/touch init flow (no C helper calls from the example itself).

## 3. Build and flash

```sh
idf.py build
idf.py -p PORT flash
idf.py -p PORT monitor
```

If you do not want `monitor` to reset the chip on connect, use:

```sh
idf.py -p PORT monitor --no-reset
```

This is useful when you want to observe logs without another USB-UART reset cycle.

## 4. Quick start (integrated display)

The simplest integrated flow is:

```zig
const std = @import("std");
const idf = @import("esp_idf");
const lvgl = idf.lvgl;

pub fn main() callconv(.c) void {
    _ = lvgl.initPortDefault() catch @panic("lvgl.initPortDefault");

    const integrated = lvgl.initIntegratedDisplay() catch @panic("lvgl.initIntegratedDisplay");
    _ = integrated;

    if (!lvgl.lock(0)) @panic("lvgl.lock");
    defer lvgl.unlock();

    _ = lvgl.createCenteredLabel("Zig + LVGL");

    while (true) {
        idf.rtos.Task.delayMs(1000);
    }
}
```

`initIntegratedDisplay()` initializes the SH8601 panel and tries to initialize FT5x06 touch. Touch is optional; display can continue even if touch init fails.

## 5. `idf.lvgl` API overview

Main calls from `imports/lvgl.zig`:

- `initPort(cfg)`
  - Initialize `esp_lvgl_port` with explicit config.
- `initPortDefault()`
  - Same as above, with sane defaults.
- `initIntegratedDisplay()`
  - Board helper for SH8601 + FT5x06 (touch optional).
- `lock(timeout_ms)` / `unlock()`
  - Guard LVGL object access.
- `activeScreen()`
  - Returns active screen object.
- `createLabel(parent)` / `setLabelText(label, text)` / `center(label)`
  - Basic widget helpers.
- `createCenteredLabel(text)`
  - Creates a centered full-screen label container using board helper C code.

## 6. Thread safety rules

LVGL is not thread-safe by default. Keep these rules:

- Always call `lvgl.lock(...)` before creating/updating LVGL objects.
- Always pair with `defer lvgl.unlock();` after lock success.
- If lock fails (timeout), skip the frame/update and retry later.

Example pattern:

```zig
if (!lvgl.lock(100)) return;
defer lvgl.unlock();
lvgl.setLabelText(label, "updated");
```

## 7. Bigger font + centered text (important)

For the integrated helper, centering uses a full-screen container plus centered text alignment. This avoids drift when text content changes.

To reduce color artifacts and improve readability, prefer real LVGL font sizes over transform zoom.

Recommended config in `sdkconfig.defaults`:

```ini
CONFIG_LV_FONT_MONTSERRAT_24=y
CONFIG_LV_FONT_MONTSERRAT_28=y
CONFIG_LV_FONT_MONTSERRAT_32=y
CONFIG_LV_FONT_DEFAULT_MONTSERRAT_24=y
```

The helper will automatically pick the largest enabled font among the configured Montserrat sizes.

## 8. Display orientation

The integrated helper currently applies horizontal mirroring (`mirror_x`) for the SH8601 path and mirrors touch coordinates to match.

If your specific hardware revision needs different orientation, adjust these in:

- `main/lvgl_integrated_display_helpers.c`
  - display rotation flags (`mirror_x`, `mirror_y`, `swap_xy`)
  - touch flags (`mirror_x`, `mirror_y`, `swap_xy`)

## 9. Troubleshooting

### Screen stays blank right after flash

- The helper now includes PMU/display power settle delay.
- If needed, press reset once after flashing and retest.
- Verify logs show panel init success (`LCD panel create success`).

### `monitor` causes reboot and touch errors

- `monitor` opens the USB serial session and may reset the MCU.
- Use `idf.py -p PORT monitor --no-reset` to avoid startup reset.
- Touch init has retries and display-only fallback, so app should continue even if touch controller is not ready on the first attempt.

### Text looks misaligned after resizing

- Use `lvgl.createCenteredLabel(...)` instead of manual one-time `center(...)` when text size/content changes over time.
- Ensure larger Montserrat fonts are enabled in config.

### Color bleeding around text

- Use real LVGL fonts (24/28/32+) instead of zoom-based scaling.
- Keep RGB565 byte-swap enabled in display port config (already configured in helper).

## 10. File map

- Zig wrapper module: `imports/lvgl.zig`
- Integrated display helper C: `main/lvgl_integrated_display_helpers.c`
- Integrated example app (Zig-only bring-up): `main/examples/lvgl-integrated-display.zig`
- Basic LVGL example app: `main/examples/lvgl-basic.zig`
