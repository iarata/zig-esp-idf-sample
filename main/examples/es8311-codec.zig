const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.es8311);

const I2C_PORT: c.i2c_port_t = c.I2C_NUM_0;
const I2C_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const I2C_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const I2C_FREQ_HZ: u32 = 400_000;
const ES8311_ADDR: u16 = c.ES8311_ADDRRES_0;

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

    const codec = c.es8311_create(I2C_PORT, ES8311_ADDR) orelse {
        log.err("es8311_create returned null", .{});
        return;
    };
    defer c.es8311_delete(codec);

    var clk_cfg = c.es8311_clock_config_t{
        .mclk_inverted = false,
        .sclk_inverted = false,
        .mclk_from_mclk_pin = false,
        .mclk_frequency = 0,
        .sample_frequency = 16_000,
    };

    const res16 = @as(c.es8311_resolution_t, @intCast(c.ES8311_RESOLUTION_16));
    espCheck(c.es8311_init(codec, &clk_cfg, res16, res16), "es8311_init");

    var volume_set: c_int = 0;
    espCheck(c.es8311_voice_volume_set(codec, 60, &volume_set), "es8311_voice_volume_set");
    espCheck(c.es8311_microphone_gain_set(codec, @as(c.es8311_mic_gain_t, @intCast(c.ES8311_MIC_GAIN_12DB))), "es8311_microphone_gain_set");
    espCheck(c.es8311_microphone_config(codec, false), "es8311_microphone_config");

    log.info("ES8311 initialized at 0x{x}, volume={d}", .{ ES8311_ADDR, volume_set });

    var mute = false;
    while (true) {
        const mute_err = c.es8311_voice_mute(codec, mute);
        if (mute_err != c.ESP_OK) {
            log.warn("es8311_voice_mute returned err={d}", .{mute_err});
        }

        var volume_now: c_int = 0;
        if (c.es8311_voice_volume_get(codec, &volume_now) == c.ESP_OK) {
            log.info("mute={} volume={d}", .{ mute, volume_now });
        }

        mute = !mute;
        idf.rtos.Task.delayMs(2000);
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
