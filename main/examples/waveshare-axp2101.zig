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

fn espCheck(err: c.esp_err_t, comptime context: []const u8) void {
    idf.err.espCheckError(err) catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

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
            log.info(
                "temp={d}C batt={d}mV ({d}%) vbus={d}mV sys={d}mV charging={} battery_connected={}",
                .{
                    status.temperature_c,
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
