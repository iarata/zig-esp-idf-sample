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

fn espCheck(err: c.esp_err_t, comptime context: []const u8) void {
    idf.err.espCheckError(err) catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

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
