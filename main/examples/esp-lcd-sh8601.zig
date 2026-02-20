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

const LCD_SPI_HOST: c.spi_host_device_t = c.SPI2_HOST;
const LCD_SCLK: c.gpio_num_t = c.GPIO_NUM_11;
const LCD_MOSI: c.gpio_num_t = c.GPIO_NUM_4;
const LCD_CS: c.gpio_num_t = c.GPIO_NUM_12;
const LCD_DC: c.gpio_num_t = c.GPIO_NUM_10; // Adjust for your board if using SPI mode.
const LCD_RST: c.gpio_num_t = c.GPIO_NUM_NC;

const LCD_H_RES: usize = 368;
const LCD_V_RES: usize = 448;

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
    log.info("Initializing SH8601 panel (SPI host={d}, res={d}x{d})", .{
        LCD_SPI_HOST,
        LCD_H_RES,
        LCD_V_RES,
    });

    var bus_cfg = std.mem.zeroes(c.spi_bus_config_t);
    bus_cfg.unnamed_0.unnamed_0.unnamed_0.mosi_io_num = LCD_MOSI;
    bus_cfg.unnamed_0.unnamed_0.unnamed_1.miso_io_num = c.GPIO_NUM_NC;
    bus_cfg.unnamed_0.unnamed_0.sclk_io_num = LCD_SCLK;
    bus_cfg.unnamed_0.unnamed_0.unnamed_2.quadwp_io_num = c.GPIO_NUM_NC;
    bus_cfg.unnamed_0.unnamed_0.unnamed_3.quadhd_io_num = c.GPIO_NUM_NC;
    bus_cfg.max_transfer_sz = @as(c_int, @intCast(LCD_H_RES * 20 * @sizeOf(u16)));
    espCheck(
        c.spi_bus_initialize(
            LCD_SPI_HOST,
            &bus_cfg,
            @as(c.spi_dma_chan_t, @intCast(c.SPI_DMA_CH_AUTO)),
        ),
        "spi_bus_initialize",
    );

    var io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_spi_config_t);
    io_cfg.cs_gpio_num = LCD_CS;
    io_cfg.dc_gpio_num = LCD_DC;
    io_cfg.spi_mode = 0;
    io_cfg.pclk_hz = 40_000_000;
    io_cfg.trans_queue_depth = 10;
    io_cfg.lcd_cmd_bits = 8;
    io_cfg.lcd_param_bits = 8;

    var io_handle: c.esp_lcd_panel_io_handle_t = null;
    espCheck(
        c.esp_lcd_new_panel_io_spi(@as(c.esp_lcd_spi_bus_handle_t, @intCast(LCD_SPI_HOST)), &io_cfg, &io_handle),
        "esp_lcd_new_panel_io_spi",
    );

    var vendor_cfg = std.mem.zeroes(c.sh8601_vendor_config_t);
    var panel_cfg = std.mem.zeroes(c.esp_lcd_panel_dev_config_t);
    panel_cfg.reset_gpio_num = LCD_RST;
    panel_cfg.rgb_ele_order = @as(c.lcd_rgb_element_order_t, @intCast(c.LCD_RGB_ELEMENT_ORDER_RGB));
    panel_cfg.bits_per_pixel = 16;
    panel_cfg.vendor_config = @ptrCast(&vendor_cfg);

    var panel: c.esp_lcd_panel_handle_t = null;
    espCheck(c.esp_lcd_new_panel_sh8601(io_handle, &panel_cfg, &panel), "esp_lcd_new_panel_sh8601");
    espCheck(esp_lcd_panel_reset(panel), "esp_lcd_panel_reset");
    espCheck(esp_lcd_panel_init(panel), "esp_lcd_panel_init");
    espCheck(esp_lcd_panel_disp_on_off(panel, true), "esp_lcd_panel_disp_on_off");

    log.info("Panel initialized. Drawing animated color bands.", .{});

    var line: [LCD_H_RES]u16 = undefined;
    var color: u16 = 0xF800; // RGB565 red

    while (true) {
        for (&line) |*px| {
            px.* = color;
        }

        const draw_err = esp_lcd_panel_draw_bitmap(
            panel,
            0,
            0,
            @as(c_int, @intCast(LCD_H_RES)),
            2,
            @ptrCast(line.ptr),
        );
        if (draw_err != c.ESP_OK) {
            log.warn("esp_lcd_panel_draw_bitmap returned err={d}", .{draw_err});
        }

        color = (color >> 1) | ((color & 0x1) << 15);
        idf.rtos.Task.delayMs(250);
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
