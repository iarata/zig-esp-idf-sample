const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.sh8601);

extern fn esp_lcd_panel_reset(panel: c.esp_lcd_panel_handle_t) c.esp_err_t;
extern fn esp_lcd_panel_init(panel: c.esp_lcd_panel_handle_t) c.esp_err_t;
extern fn esp_lcd_panel_disp_on_off(panel: c.esp_lcd_panel_handle_t, on_off: bool) c.esp_err_t;
extern fn esp_lcd_panel_draw_bitmap(
    panel: c.esp_lcd_panel_handle_t,
    x_start: c_int,
    y_start: c_int,
    x_end: c_int,
    y_end: c_int,
    color_data: ?*const anyopaque,
) c.esp_err_t;

const esp_lcd_spi_flags_t = packed struct(u32) {
    dc_high_on_cmd: u1 = 0,
    dc_low_on_data: u1 = 0,
    dc_low_on_param: u1 = 0,
    octal_mode: u1 = 0,
    quad_mode: u1 = 0,
    sio_mode: u1 = 0,
    lsb_first: u1 = 0,
    cs_high_active: u1 = 0,
    reserved: u24 = 0,
};

const esp_lcd_panel_io_spi_config_t = extern struct {
    cs_gpio_num: c.gpio_num_t = @import("std").mem.zeroes(c.gpio_num_t),
    dc_gpio_num: c.gpio_num_t = @import("std").mem.zeroes(c.gpio_num_t),
    spi_mode: c_int = 0,
    pclk_hz: c_uint = 0,
    trans_queue_depth: usize = 0,
    on_color_trans_done: c.esp_lcd_panel_io_color_trans_done_cb_t = null,
    user_ctx: ?*anyopaque = null,
    lcd_cmd_bits: c_int = 0,
    lcd_param_bits: c_int = 0,
    cs_ena_pretrans: u8 = 0,
    cs_ena_posttrans: u8 = 0,
    flags: esp_lcd_spi_flags_t = .{},
};

const sh8601_vendor_flags_t = packed struct(u32) {
    use_qspi_interface: u1 = 0,
    reserved: u31 = 0,
};

const sh8601_vendor_config_t = extern struct {
    init_cmds: [*c]const c.sh8601_lcd_init_cmd_t = null,
    init_cmds_size: u16 = 0,
    flags: sh8601_vendor_flags_t = .{},
};

const esp_lcd_panel_dev_flags_t = packed struct(u32) {
    reset_active_high: u1 = 0,
    reserved: u31 = 0,
};

const esp_lcd_panel_dev_config_t = extern struct {
    rgb_ele_order: c.lcd_rgb_element_order_t = @import("std").mem.zeroes(c.lcd_rgb_element_order_t),
    data_endian: c.lcd_rgb_data_endian_t = @import("std").mem.zeroes(c.lcd_rgb_data_endian_t),
    bits_per_pixel: u32 = 0,
    reset_gpio_num: c.gpio_num_t = @import("std").mem.zeroes(c.gpio_num_t),
    vendor_config: ?*anyopaque = null,
    flags: esp_lcd_panel_dev_flags_t = .{},
};

extern fn esp_lcd_new_panel_io_spi(
    bus: c.esp_lcd_spi_bus_handle_t,
    io_config: [*c]const esp_lcd_panel_io_spi_config_t,
    ret_io: [*c]c.esp_lcd_panel_io_handle_t,
) c.esp_err_t;

extern fn esp_lcd_new_panel_sh8601(
    io: c.esp_lcd_panel_io_handle_t,
    panel_dev_config: [*c]const esp_lcd_panel_dev_config_t,
    ret_panel: [*c]c.esp_lcd_panel_handle_t,
) c.esp_err_t;

const LCD_SPI_HOST: c.spi_host_device_t = c.SPI2_HOST;
const LCD_SCLK: c.gpio_num_t = c.GPIO_NUM_11; // QSPI PCLK
const LCD_D0: c.gpio_num_t = c.GPIO_NUM_4;
const LCD_D1: c.gpio_num_t = c.GPIO_NUM_5;
const LCD_D2: c.gpio_num_t = c.GPIO_NUM_6;
const LCD_D3: c.gpio_num_t = c.GPIO_NUM_7;
const LCD_CS: c.gpio_num_t = c.GPIO_NUM_12;
const LCD_RST: c.gpio_num_t = c.GPIO_NUM_NC;

const PMU_I2C_PORT: c.i2c_port_num_t = c.I2C_NUM_0;
const PMU_I2C_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const PMU_I2C_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const PMU_I2C_FREQ_HZ: u32 = 400_000;

const LCD_H_RES: usize = 368;
const LCD_V_RES: usize = 448;
const CHUNK_LINES: usize = 2;

const sh8601_cmd_11 = [_]u8{0x00};
const sh8601_cmd_44 = [_]u8{ 0x01, 0xD1 };
const sh8601_cmd_35 = [_]u8{0x00};
const sh8601_cmd_53 = [_]u8{0x20};
const sh8601_cmd_2a = [_]u8{ 0x00, 0x00, 0x01, 0x6F };
const sh8601_cmd_2b = [_]u8{ 0x00, 0x00, 0x01, 0xBF };
const sh8601_cmd_51_00 = [_]u8{0x00};
const sh8601_cmd_51_ff = [_]u8{0xFF};

const sh8601_init_cmds = [_]c.sh8601_lcd_init_cmd_t{
    .{ .cmd = 0x11, .data = @ptrCast(&sh8601_cmd_11[0]), .data_bytes = sh8601_cmd_11.len, .delay_ms = 120 },
    .{ .cmd = 0x44, .data = @ptrCast(&sh8601_cmd_44[0]), .data_bytes = sh8601_cmd_44.len, .delay_ms = 0 },
    .{ .cmd = 0x35, .data = @ptrCast(&sh8601_cmd_35[0]), .data_bytes = sh8601_cmd_35.len, .delay_ms = 0 },
    .{ .cmd = 0x53, .data = @ptrCast(&sh8601_cmd_53[0]), .data_bytes = sh8601_cmd_53.len, .delay_ms = 10 },
    .{ .cmd = 0x2A, .data = @ptrCast(&sh8601_cmd_2a[0]), .data_bytes = sh8601_cmd_2a.len, .delay_ms = 0 },
    .{ .cmd = 0x2B, .data = @ptrCast(&sh8601_cmd_2b[0]), .data_bytes = sh8601_cmd_2b.len, .delay_ms = 0 },
    .{ .cmd = 0x51, .data = @ptrCast(&sh8601_cmd_51_00[0]), .data_bytes = sh8601_cmd_51_00.len, .delay_ms = 10 },
    .{ .cmd = 0x29, .data = null, .data_bytes = 0, .delay_ms = 10 },
    .{ .cmd = 0x51, .data = @ptrCast(&sh8601_cmd_51_ff[0]), .data_bytes = sh8601_cmd_51_ff.len, .delay_ms = 0 },
};

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn espCheck(err: c.esp_err_t, comptime context: []const u8) void {
    idf.err.espCheckError(err) catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

fn colorForBand(frame: usize, y_start: usize) u16 {
    const band = ((y_start / 56) + frame) % 6;
    return switch (band) {
        0 => 0xF800, // red
        1 => 0x07E0, // green
        2 => 0x001F, // blue
        3 => 0xFFE0, // yellow
        4 => 0x07FF, // cyan
        else => 0xF81F, // magenta
    };
}

fn main() callconv(.c) void {
    log.info("Enabling AMOLED power rails via AXP2101 (I2C{d})", .{PMU_I2C_PORT});
    espCheck(c.waveshare_axp2101_init(PMU_I2C_PORT, PMU_I2C_SDA, PMU_I2C_SCL, PMU_I2C_FREQ_HZ), "waveshare_axp2101_init");
    espCheck(c.waveshare_axp2101_apply_touch_amoled_1_8_defaults(), "waveshare_axp2101_apply_touch_amoled_1_8_defaults");

    log.info("Initializing SH8601 panel (QSPI host={d}, res={d}x{d})", .{
        LCD_SPI_HOST,
        LCD_H_RES,
        LCD_V_RES,
    });

    var bus_cfg = std.mem.zeroes(c.spi_bus_config_t);
    bus_cfg.unnamed_0.unnamed_0.unnamed_0.data0_io_num = LCD_D0;
    bus_cfg.unnamed_0.unnamed_0.unnamed_1.data1_io_num = LCD_D1;
    bus_cfg.unnamed_0.unnamed_0.sclk_io_num = LCD_SCLK;
    bus_cfg.unnamed_0.unnamed_0.unnamed_2.data2_io_num = LCD_D2;
    bus_cfg.unnamed_0.unnamed_0.unnamed_3.data3_io_num = LCD_D3;
    bus_cfg.max_transfer_sz = @as(c_int, @intCast(LCD_H_RES * CHUNK_LINES * @sizeOf(u16)));
    espCheck(
        c.spi_bus_initialize(
            LCD_SPI_HOST,
            &bus_cfg,
            @as(c.spi_dma_chan_t, @intCast(c.SPI_DMA_CH_AUTO)),
        ),
        "spi_bus_initialize",
    );

    var io_cfg = std.mem.zeroes(esp_lcd_panel_io_spi_config_t);
    io_cfg.cs_gpio_num = LCD_CS;
    io_cfg.dc_gpio_num = c.GPIO_NUM_NC;
    io_cfg.spi_mode = 0;
    io_cfg.pclk_hz = 40_000_000;
    io_cfg.trans_queue_depth = 10;
    io_cfg.lcd_cmd_bits = 32;
    io_cfg.lcd_param_bits = 8;
    io_cfg.flags.quad_mode = 1;

    var io_handle: c.esp_lcd_panel_io_handle_t = null;
    espCheck(
        esp_lcd_new_panel_io_spi(@as(c.esp_lcd_spi_bus_handle_t, @intCast(LCD_SPI_HOST)), &io_cfg, &io_handle),
        "esp_lcd_new_panel_io_spi",
    );

    var vendor_cfg = std.mem.zeroes(sh8601_vendor_config_t);
    vendor_cfg.init_cmds = &sh8601_init_cmds[0];
    vendor_cfg.init_cmds_size = @as(u16, @intCast(sh8601_init_cmds.len));
    vendor_cfg.flags.use_qspi_interface = 1;

    var panel_cfg = std.mem.zeroes(esp_lcd_panel_dev_config_t);
    panel_cfg.reset_gpio_num = LCD_RST;
    panel_cfg.rgb_ele_order = @as(c.lcd_rgb_element_order_t, @intCast(c.LCD_RGB_ELEMENT_ORDER_RGB));
    panel_cfg.bits_per_pixel = 16;
    panel_cfg.vendor_config = @ptrCast(&vendor_cfg);

    var panel: c.esp_lcd_panel_handle_t = null;
    espCheck(esp_lcd_new_panel_sh8601(io_handle, &panel_cfg, &panel), "esp_lcd_new_panel_sh8601");
    espCheck(esp_lcd_panel_reset(panel), "esp_lcd_panel_reset");
    espCheck(esp_lcd_panel_init(panel), "esp_lcd_panel_init");
    espCheck(esp_lcd_panel_disp_on_off(panel, true), "esp_lcd_panel_disp_on_off");

    log.info("Panel initialized. Drawing full-screen animated color bands.", .{});

    var chunk: [LCD_H_RES * CHUNK_LINES]u16 = undefined;
    var frame: usize = 0;

    while (true) {
        var y: usize = 0;
        while (y < LCD_V_RES) : (y += CHUNK_LINES) {
            const color = colorForBand(frame, y);
            for (&chunk) |*px| {
                px.* = color;
            }

            const draw_err = esp_lcd_panel_draw_bitmap(
                panel,
                0,
                @as(c_int, @intCast(y)),
                @as(c_int, @intCast(LCD_H_RES)),
                @as(c_int, @intCast(y + CHUNK_LINES)),
                @ptrCast(&chunk[0]),
            );
            if (draw_err != c.ESP_OK) {
                log.warn("esp_lcd_panel_draw_bitmap returned err={d}", .{draw_err});
            }
        }

        frame += 1;
        idf.rtos.Task.delayMs(120);
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
