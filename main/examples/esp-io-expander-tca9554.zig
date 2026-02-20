const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.io_expander);

const I2C_PORT: c.i2c_port_t = c.I2C_NUM_0;
const I2C_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const I2C_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const I2C_FREQ_HZ: u32 = 400_000;
const TCA9554_ADDR: u32 = c.ESP_IO_EXPANDER_I2C_TCA9554_ADDRESS_000;

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn espCheck(err: c.esp_err_t, comptime context: []const u8) void {
    idf.err.espCheckError(err) catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

fn initLegacyI2cMaster() void {
    var conf = std.mem.zeroes(c.i2c_config_t);
    conf.mode = @as(c.i2c_mode_t, @intCast(c.I2C_MODE_MASTER));
    conf.sda_io_num = I2C_SDA;
    conf.scl_io_num = I2C_SCL;
    conf.sda_pullup_en = true;
    conf.scl_pullup_en = true;
    conf.unnamed_0.master.clk_speed = I2C_FREQ_HZ;

    espCheck(c.i2c_param_config(I2C_PORT, &conf), "i2c_param_config");

    const install_err = c.i2c_driver_install(I2C_PORT, conf.mode, 0, 0, 0);
    if (install_err != c.ESP_OK and install_err != c.ESP_ERR_INVALID_STATE) {
        espCheck(install_err, "i2c_driver_install");
    }
}

fn main() callconv(.c) void {
    initLegacyI2cMaster();

    var io_expander: c.esp_io_expander_handle_t = null;
    espCheck(c.esp_io_expander_new_i2c_tca9554(I2C_PORT, TCA9554_ADDR, &io_expander), "esp_io_expander_new_i2c_tca9554");

    const pin0_mask: u32 = c.IO_EXPANDER_PIN_NUM_0;
    const output_mode: c.esp_io_expander_dir_t = @as(c.esp_io_expander_dir_t, @intCast(c.IO_EXPANDER_OUTPUT));
    espCheck(c.esp_io_expander_set_dir(io_expander, pin0_mask, output_mode), "esp_io_expander_set_dir");

    log.info("TCA9554 initialized at 0x{x}; toggling P0", .{TCA9554_ADDR});

    var on = false;
    while (true) {
        const level: u8 = if (on) 1 else 0;
        const err = c.esp_io_expander_set_level(io_expander, pin0_mask, level);
        if (err != c.ESP_OK) {
            log.warn("esp_io_expander_set_level returned err={d}", .{err});
        } else {
            log.info("P0 -> {d}", .{level});
        }
        on = !on;
        idf.rtos.Task.delayMs(500);
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
