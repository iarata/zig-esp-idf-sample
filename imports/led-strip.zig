//! # LED Strip Wrapper (`led`)
//!
//! **What:** Zig wrapper for the Espressif `led_strip` managed component,
//! supporting WS2812, SK6812, WS2811, and WS2816 addressable LED strips with
//! RMT or SPI backends.
//!
//! **Prerequisite:** `idf.py add-dependency espressif/led_strip`
//!
//! **What it does:**
//!   - **Config structs** — `LedStripConfig`, `LedStripRmtConfig`,
//!     `LedStripSpiConfig` with builder helpers for common defaults.
//!   - `newRmtDevice(strip_cfg, rmt_cfg, &handle)` — creates an RMT-backed
//!     strip (most common for WS2812 on ESP32-S3).
//!   - `newSpiDevice(strip_cfg, spi_cfg, &handle)` — SPI-backed alternative
//!     (useful when RMT channels are exhausted).
//!   - `setPixel(strip, index, r, g, b)` — set one RGB pixel.
//!   - `setPixelRgbw(strip, index, r, g, b, w)` — set one RGBW pixel.
//!   - `setPixelHsv(strip, index, hue, sat, val)` — HSV convenience.
//!   - `refresh(strip)` — push all buffered pixel data to the physical strip.
//!   - `clear(strip)` — turn all LEDs off.
//!   - `deinit(strip)` — release hardware resources.
//!
//! **How:** `LedStripConfig` and `LedStripRmtConfig` are Zig-side `extern
//! struct`s that mirror the C component layout.  They are `@ptrCast`ed to
//! the C types.  All C errors go through `espCheckError`.
//!
//! **When to use:** Status LEDs, RGB indicators, NeoPixel/SK6812 strips.
//!
//! **What it takes:**
//!   - GPIO number for the data pin.
//!   - Number of LEDs.
//!   - LED model (WS2812, SK6812, etc.).
//!
//! **Example:**
//! ```zig
//! const led = idf.led;
//! var strip_cfg = led.LedStripConfig.ws2812(48, 1);  // GPIO 48, 1 LED
//! var rmt_cfg = led.LedStripRmtConfig.default;        // 10 MHz RMT clock
//! var handle: led.LedStripHandle = null;
//! _ = try led.newRmtDevice(&strip_cfg, &rmt_cfg, &handle);
//! try led.setPixel(handle, 0, 255, 0, 0);             // red
//! try led.refresh(handle);
//! ```

// requires: idf.py add-dependency espressif/led_strip
const sys = @import("sys");
const errors = @import("error");

/// Supported addressable LED IC models.
pub const LedModel = enum(sys.led_model_t) {
    /// WS2812 (most common NeoPixel-compatible).
    ws2812 = sys.LED_MODEL_WS2812,
    /// SK6812 (common RGBW model).
    sk6812 = sys.LED_MODEL_SK6812,
    /// WS2811.
    ws2811 = sys.LED_MODEL_WS2811,
    /// WS2816 (16-bit colour depth).
    ws2816 = sys.LED_MODEL_WS2816,
    invalid = sys.LED_MODEL_INVALID,
};
/// Opaque handle to a configured LED strip.
pub const LedStripHandle = sys.led_strip_handle_t;

/// Sub-pixel colour component ordering and byte width.
pub const ColorComponentFormat = extern union {
    format: packed struct {
        r_pos: u2, // Position of the red channel in the color order: 0~3
        g_pos: u2, // Position of the green channel in the color order: 0~3
        b_pos: u2, // Position of the blue channel in the color order: 0~3
        w_pos: u2, // Position of the white channel in the color order: 0~3
        reserved: u19, // Reserved
        bytes_per_color: u2, // Bytes per color component: 1 or 2. If set to 0, it will fallback to 1
        num_components: u3, // Number of color components per pixel: 3 or 4. If set to 0, it will fallback to 3
    },
    format_id: u32,
};
/// Common pre-defined pixel format identifiers.
pub const PixelFormat = enum(u32) {
    grb = 0x00, // default WS2812
    rgb = 0x01,
    grbw = 0x10,
    rgbw = 0x11,
};
/// LED strip configuration (GPIO, LED count, model, colour format).
pub const LedStripConfig = extern struct {
    strip_gpio_num: i32,
    max_leds: u32,
    led_model: LedModel,
    color_component_format: ColorComponentFormat,
    // flags:              sys.struct_led_strip_extra_flags_29, // opaque
    flags: u32 = 0, // most users leave = 0; see component for bits

    pub fn init(gpio: u32, count: u32, model: LedModel, format_id: u32) LedStripConfig {
        return .{
            .strip_gpio_num = @intCast(gpio),
            .max_leds = count,
            .led_model = model,
            .color_component_format = .{ .format_id = format_id },
            .flags = 0,
        };
    }
    pub fn ws2812(gpio: u32, count: u32) LedStripConfig {
        return init(gpio, count, .ws2812, @intFromEnum(PixelFormat.grb));
    }
};
/// RMT backend configuration (clock source, resolution).
pub const LedStripRmtConfig = struct {
    clk_src: sys.rmt_clock_source_t,
    resolution_hz: u32,
    mem_block_symbols: usize = 0, // 0 = default/auto
    // flags:              sys.struct_led_strip_rmt_extra_config_33, // opaque
    flags: u32 = 0,

    pub fn init_10mhz() LedStripRmtConfig {
        return .{
            .clk_src = sys.RMT_CLK_SRC_DEFAULT,
            .resolution_hz = 10_000_000,
            .mem_block_symbols = 0,
            .flags = 0,
        };
    }

    // Very common setting in examples
    pub const default = init_10mhz();
};
/// SPI backend configuration (clock source, SPI bus).
pub const LedStripSpiConfig = struct {
    clk_src: sys.spi_clock_source_t,
    spi_bus: sys.spi_host_device_t,
    // flags:       sys.struct_unnamed_34, // opaque
    flags: u32 = 0,
};

// ───────────────────────────────────────────────
// API functions

/// Creates RMT-backed LED strip
pub fn newRmtDevice(led_config: *const LedStripConfig, rmt_config: *const LedStripRmtConfig, handle: *LedStripHandle) !LedStripHandle {
    const result = sys.led_strip_new_rmt_device(@ptrCast(led_config), @ptrCast(rmt_config), @ptrCast(handle));
    try errors.espCheckError(result);
    return handle.*;
}

/// Creates SPI-backed LED strip
pub fn newSpiDevice(led_config: *const LedStripConfig, spi_config: *const LedStripSpiConfig, handle: *LedStripHandle) !LedStripHandle {
    const result = sys.led_strip_new_spi_device(@ptrCast(led_config), @ptrCast(spi_config), @ptrCast(handle));
    try errors.espCheckError(result);
    return handle.*;
}
/// Set one RGB pixel
pub fn setPixel(strip: LedStripHandle, index: u32, r: u8, g: u8, b: u8) !void {
    // The C API takes u32 — we clamp/convert for safety
    return try errors.espCheckError(sys.led_strip_set_pixel(strip, index, @as(u32, r), @as(u32, g), @as(u32, b)));
}
/// Variant that also sets white channel (SK6812 RGBW etc.)
pub fn setPixelRgbw(strip: LedStripHandle, index: u32, r: u8, g: u8, b: u8, w: u8) !void {
    return try errors.espCheckError(sys.led_strip_set_pixel_rgbw(strip, index, @as(u32, r), @as(u32, g), @as(u32, b), @as(u32, w)));
}
/// HSV variant (convenience — internally converts to RGB)
pub fn setPixelHsv(strip: LedStripHandle, index: u32, hue: u16, sat: u8, val: u8) !void {
    return try errors.espCheckError(sys.led_strip_set_pixel_hsv(strip, index, hue, sat, val));
}
/// Push all buffered pixel data to the strip
pub fn refresh(strip: LedStripHandle) !void {
    return try errors.espCheckError(sys.led_strip_refresh(strip));
}
/// Turn all LEDs off
pub fn clear(strip: LedStripHandle) !void {
    return try errors.espCheckError(sys.led_strip_clear(strip));
}
/// Free resources
pub fn deinit(strip: LedStripHandle) !void {
    return try errors.espCheckError(sys.led_strip_del(strip));
}
