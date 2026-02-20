const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.lcd_touch_core);

const TOUCH_I2C_PORT: c.i2c_port_num_t = c.I2C_NUM_0;
const TOUCH_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const TOUCH_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const TOUCH_INT: c.gpio_num_t = c.GPIO_NUM_21;
const TOUCH_FREQ_HZ: u32 = 400_000;

const TOUCH_HRES: u16 = 368;
const TOUCH_VRES: u16 = 448;

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
    log.info("Enabling touch rails via AXP2101 (I2C{d})", .{TOUCH_I2C_PORT});
    espCheck(c.waveshare_axp2101_init(TOUCH_I2C_PORT, TOUCH_SDA, TOUCH_SCL, TOUCH_FREQ_HZ), "waveshare_axp2101_init");
    espCheck(c.waveshare_axp2101_apply_touch_amoled_1_8_defaults(), "waveshare_axp2101_apply_touch_amoled_1_8_defaults");
    idf.rtos.Task.delayMs(20);

    var i2c_bus: c.i2c_master_bus_handle_t = null;
    espCheck(c.i2c_master_get_bus_handle(TOUCH_I2C_PORT, &i2c_bus), "i2c_master_get_bus_handle");

    var tp_io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_i2c_config_t);
    tp_io_cfg.dev_addr = c.ESP_LCD_TOUCH_IO_I2C_FT5x06_ADDRESS;
    tp_io_cfg.scl_speed_hz = TOUCH_FREQ_HZ;
    tp_io_cfg.control_phase_bytes = 1;
    tp_io_cfg.dc_bit_offset = 0;
    tp_io_cfg.lcd_cmd_bits = 8;
    tp_io_cfg.lcd_param_bits = 8;
    tp_io_cfg.flags.disable_control_phase = 1;

    var tp_io: c.esp_lcd_panel_io_handle_t = null;
    espCheck(c.esp_lcd_new_panel_io_i2c(i2c_bus, &tp_io_cfg, &tp_io), "esp_lcd_new_panel_io_i2c");

    var touch_cfg = std.mem.zeroes(c.esp_lcd_touch_config_t);
    touch_cfg.x_max = TOUCH_HRES;
    touch_cfg.y_max = TOUCH_VRES;
    touch_cfg.rst_gpio_num = c.GPIO_NUM_NC;
    touch_cfg.int_gpio_num = TOUCH_INT;

    var touch: c.esp_lcd_touch_handle_t = null;
    espCheck(c.esp_lcd_touch_new_i2c_ft5x06(tp_io, &touch_cfg, &touch), "esp_lcd_touch_new_i2c_ft5x06");

    // Demonstrate generic core APIs after controller initialization.
    _ = c.esp_lcd_touch_set_swap_xy(touch, false);
    _ = c.esp_lcd_touch_set_mirror_x(touch, false);
    _ = c.esp_lcd_touch_set_mirror_y(touch, false);

    log.info("Touch core APIs ready. Polling esp_lcd_touch_get_data...", .{});

    while (true) {
        if (c.esp_lcd_touch_read_data(touch) != c.ESP_OK) {
            idf.rtos.Task.delayMs(50);
            continue;
        }

        var point_count: u8 = 0;
        var points = [_]c.esp_lcd_touch_point_data_t{std.mem.zeroes(c.esp_lcd_touch_point_data_t)};
        if (c.esp_lcd_touch_get_data(touch, &points[0], &point_count, 1) == c.ESP_OK and point_count > 0) {
            log.info(
                "point: x={d} y={d} strength={d} track_id={d}",
                .{ points[0].x, points[0].y, points[0].strength, points[0].track_id },
            );
        }

        idf.rtos.Task.delayMs(30);
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
