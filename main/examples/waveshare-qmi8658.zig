//! # QMI8658 IMU Sample Reader (`waveshare-qmi8658.zig`)
//!
//! **What:** Initialises the QMI8658 6-axis IMU (accelerometer + gyroscope)
//! over I²C and logs raw motion samples at ~10 Hz.
//!
//! **What it does:**
//!   1. Calls `waveshare_qmi8658_init` with I²C₀ bus parameters and the
//!      default device address (0x6B).
//!   2. Applies default sensor configuration via
//!      `waveshare_qmi8658_config_default`.
//!   3. Polls `waveshare_qmi8658_data_ready` at 20 ms intervals and, when
//!      data is available, reads and logs accelerometer (x/y/z), gyroscope
//!      (x/y/z), die temperature, and timestamp.
//!
//! **How:** Build and flash with:
//! ```sh
//! zig build -Dapp_source=main/examples/waveshare-qmi8658.zig
//! idf.py flash monitor
//! ```
//!
//! **When to use:** For IMU bring-up, register sanity checks, and confirming
//! that the sensor axes match the board orientation.
//!
//! **What it takes:**
//!   - QMI8658 on I²C₀ (SDA=GPIO 15, SCL=GPIO 14, addr 0x6B, 400 kHz).
//!   - The `waveshare_qmi8658` managed component.

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.qmi8658);

const I2C_PORT: c.i2c_port_num_t = c.I2C_NUM_0;
const I2C_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const I2C_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const I2C_FREQ_HZ: u32 = 400_000;
const QMI8658_ADDR: u8 = 0x6B;

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

/// Uses a data-ready gate to avoid logging stale reads, which makes timing and
/// sensor-configuration issues visible during bring-up.
fn main() callconv(.c) void {
    log.info("Initializing QMI8658 on I2C{d} (SDA={d}, SCL={d}, addr=0x{x})", .{ I2C_PORT, I2C_SDA, I2C_SCL, QMI8658_ADDR });

    espCheck(c.waveshare_qmi8658_init(I2C_PORT, I2C_SDA, I2C_SCL, QMI8658_ADDR, I2C_FREQ_HZ), "waveshare_qmi8658_init");
    espCheck(c.waveshare_qmi8658_config_default(), "waveshare_qmi8658_config_default");

    while (true) {
        if (!c.waveshare_qmi8658_data_ready()) {
            idf.rtos.Task.delayMs(20);
            continue;
        }

        var sample = std.mem.zeroes(c.waveshare_qmi8658_sample_t);
        const err = c.waveshare_qmi8658_read_sample(&sample);
        if (err != c.ESP_OK) {
            log.warn("waveshare_qmi8658_read_sample returned err={d}", .{err});
        } else {
            log.info(
                "acc=({d}, {d}, {d}) gyr=({d}, {d}, {d}) temp={d}C ts={d}",
                .{
                    sample.acc_x,
                    sample.acc_y,
                    sample.acc_z,
                    sample.gyr_x,
                    sample.gyr_y,
                    sample.gyr_z,
                    sample.temperature_c,
                    sample.timestamp,
                },
            );
        }
        idf.rtos.Task.delayMs(100);
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
