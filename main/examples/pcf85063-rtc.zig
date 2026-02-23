//! # PCF85063 RTC Polling Example (`pcf85063-rtc.zig`)
//!
//! **What:** Initialises the PCF85063 real-time clock over I²C and logs the
//! current date/time every second.
//!
//! **What it does:**
//!   1. Calls `pcf85063_init` with the I²C₀ bus parameters.
//!   2. Polls `pcf85063_get_datetime` once per second.
//!   3. Formats and logs year, month, day, hours, minutes, seconds, weekday.
//!
//! **How:** Build and flash with:
//! ```sh
//! zig build -Dapp_source=main/examples/pcf85063-rtc.zig
//! idf.py flash monitor
//! ```
//!
//! **When to use:** During RTC bring-up to confirm the clock crystal is
//! running, I²C reads succeed, and BCD→binary conversion is correct.
//!
//! **What it takes:**
//!   - PCF85063 on I²C₀ (SDA=GPIO 15, SCL=GPIO 14, 400 kHz).
//!   - The `pcf85063` managed component.

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.pcf85063);

const I2C_PORT: c.i2c_port_num_t = c.I2C_NUM_0;
const I2C_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const I2C_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const I2C_FREQ_HZ: u32 = 400_000;

comptime {
    @export(&main, .{ .name = "app_main" });
}

/// In bring-up examples we fail fast on any ESP-IDF error so hardware is not
/// left in a half-configured state that hides the root cause.
fn espCheck(err: c.esp_err_t, comptime context: []const u8) void {
    idf.err.espCheckError(err) catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

/// Polling once per second mirrors RTC granularity, making it easy to spot
/// decode errors or stalled register updates.
fn main() callconv(.c) void {
    log.info("Initializing PCF85063 RTC on I2C{d} (SDA={d}, SCL={d})", .{ I2C_PORT, I2C_SDA, I2C_SCL });
    espCheck(c.pcf85063_init(I2C_PORT, I2C_SDA, I2C_SCL, I2C_FREQ_HZ), "pcf85063_init");

    while (true) {
        var dt = std.mem.zeroes(c.pcf85063_datetime_t);
        const err = c.pcf85063_get_datetime(I2C_PORT, &dt);
        if (err != c.ESP_OK) {
            log.warn("pcf85063_get_datetime returned err={d}", .{err});
        } else {
            const year_full: u16 = 2000 + dt.year;
            log.info(
                "datetime: {d}-{d}-{d} {d}:{d}:{d} weekday={d}",
                .{ year_full, dt.month, dt.day, dt.hours, dt.minutes, dt.seconds, dt.weekday },
            );
        }
        idf.rtos.Task.delayMs(1000);
    }
}

pub const panic = idf.esp_panic.panic;
pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    .logFn = idf.log.espLogFn,
};
