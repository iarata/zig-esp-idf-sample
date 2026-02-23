//! # AXP2101 PMU Status Example (`waveshare-axp2101.zig`)
//!
//! **What:** Initialises the AXP2101 power-management unit on the Waveshare
//! board and continuously reads temperature, battery voltage, charge state,
//! and VBUS/system rail voltages.
//!
//! **What it does:**
//!   1. Calls `waveshare_axp2101_init` + `apply_touch_amoled_1_8_defaults`
//!      to power up the board rails.
//!   2. Polls `waveshare_axp2101_read_status` every second.
//!   3. Logs: die temperature (°C, one decimal), battery mV/%, VBUS mV,
//!      system mV, charging flag, battery-connected flag.
//!
//! **How:** Build and flash with:
//! ```sh
//! zig build -Dapp_source=main/examples/waveshare-axp2101.zig
//! idf.py flash monitor
//! ```
//!
//! **When to use:** To confirm power-rail configuration and get a health
//! baseline before enabling display, touch, or radio subsystems.
//!
//! **What it takes:**
//!   - AXP2101 on I²C₀ (SDA=GPIO 15, SCL=GPIO 14, 400 kHz).
//!   - The `waveshare_axp2101` managed component.

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.axp2101);

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

/// The steady status loop gives a quick health baseline for rails/charging
/// before adding higher-level subsystems.
fn main() callconv(.c) void {
    log.info("Initializing AXP2101 on I2C{d} (SDA={d}, SCL={d})", .{ I2C_PORT, I2C_SDA, I2C_SCL });

    espCheck(c.waveshare_axp2101_init(I2C_PORT, I2C_SDA, I2C_SCL, I2C_FREQ_HZ), "waveshare_axp2101_init");
    espCheck(c.waveshare_axp2101_apply_touch_amoled_1_8_defaults(), "waveshare_axp2101_apply_touch_amoled_1_8_defaults");

    while (true) {
        var status = std.mem.zeroes(c.waveshare_axp2101_status_t);
        const err = c.waveshare_axp2101_read_status(&status);
        if (err != c.ESP_OK) {
            log.warn("waveshare_axp2101_read_status returned err={d}", .{err});
        } else {
            const temp_c_x10: i32 = @as(i32, @intFromFloat(status.temperature_c * 10.0));
            const temp_c_x10_abs: i32 = if (temp_c_x10 < 0) -temp_c_x10 else temp_c_x10;
            const temp_c_whole: i32 = @divTrunc(temp_c_x10, 10);
            const temp_c_frac: i32 = @rem(temp_c_x10_abs, 10);
            log.info(
                "temp={d}.{d}C batt={d}mV ({d}%) vbus={d}mV sys={d}mV charging={} battery_connected={}",
                .{
                    temp_c_whole,
                    temp_c_frac,
                    status.battery_mv,
                    status.battery_percent,
                    status.vbus_mv,
                    status.system_mv,
                    status.charging,
                    status.battery_connected,
                },
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
