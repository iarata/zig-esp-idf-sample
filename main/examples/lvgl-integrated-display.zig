const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const lvgl = idf.lvgl;
const c = idf.sys;

const log = std.log.scoped(.lvgl_integrated);

const LvArea = extern struct {
    x1: i32 = 0,
    y1: i32 = 0,
    x2: i32 = 0,
    y2: i32 = 0,
};

const LvglPortRotationCfg = extern struct {
    swap_xy: bool = false,
    mirror_x: bool = false,
    mirror_y: bool = false,
};

const LvglPortDisplayFlags = packed struct(u32) {
    buff_dma: u1 = 0,
    buff_spiram: u1 = 0,
    sw_rotate: u1 = 0,
    swap_bytes: u1 = 0,
    full_refresh: u1 = 0,
    direct_mode: u1 = 0,
    reserved: u26 = 0,
};

const LvglPortDisplayCfg = extern struct {
    io_handle: c.esp_lcd_panel_io_handle_t = null,
    panel_handle: c.esp_lcd_panel_handle_t = null,
    control_handle: c.esp_lcd_panel_handle_t = null,
    buffer_size: u32 = 0,
    double_buffer: bool = false,
    trans_size: u32 = 0,
    hres: u32 = 0,
    vres: u32 = 0,
    monochrome: bool = false,
    rotation: LvglPortRotationCfg = .{},
    rounder_cb: ?*const fn (area: [*c]LvArea) callconv(.c) void = null,
    color_format: c_int = 0,
    flags: LvglPortDisplayFlags = .{},
};

const LvglPortTouchScale = extern struct {
    x: f32 = 0,
    y: f32 = 0,
};

const LvglPortTouchCfg = extern struct {
    disp: ?*lvgl.Display = null,
    handle: c.esp_lcd_touch_handle_t = null,
    scale: LvglPortTouchScale = .{},
};

extern fn lvgl_port_add_disp(disp_cfg: [*c]const LvglPortDisplayCfg) ?*lvgl.Display;
extern fn lvgl_port_add_touch(touch_cfg: [*c]const LvglPortTouchCfg) ?*lvgl.InputDevice;

extern fn esp_lcd_panel_reset(panel: c.esp_lcd_panel_handle_t) c.esp_err_t;
extern fn esp_lcd_panel_init(panel: c.esp_lcd_panel_handle_t) c.esp_err_t;
extern fn esp_lcd_panel_disp_on_off(panel: c.esp_lcd_panel_handle_t, on_off: bool) c.esp_err_t;

const LCD_HOST: c.spi_host_device_t = c.SPI2_HOST;
const TOUCH_I2C_PORT: c.i2c_port_num_t = c.I2C_NUM_0;
const TOUCH_SDA: c.gpio_num_t = c.GPIO_NUM_15;
const TOUCH_SCL: c.gpio_num_t = c.GPIO_NUM_14;
const TOUCH_INT: c.gpio_num_t = c.GPIO_NUM_21;
const TOUCH_FREQ_HZ: u32 = 400_000;
const TOUCH_INIT_RETRIES: u32 = 5;
const TOUCH_RETRY_DELAY_MS: u32 = 80;
const POWER_SETTLE_DELAY_MS: u32 = 350;

const LCD_SCLK: c.gpio_num_t = c.GPIO_NUM_11;
const LCD_D0: c.gpio_num_t = c.GPIO_NUM_4;
const LCD_D1: c.gpio_num_t = c.GPIO_NUM_5;
const LCD_D2: c.gpio_num_t = c.GPIO_NUM_6;
const LCD_D3: c.gpio_num_t = c.GPIO_NUM_7;
const LCD_CS: c.gpio_num_t = c.GPIO_NUM_12;
const LCD_RST: c.gpio_num_t = c.GPIO_NUM_NC;

const LCD_H_RES: u32 = 368;
const LCD_V_RES: u32 = 448;
const LVGL_BUF_LINES: u32 = 48;

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

fn check(result: anyerror!void, comptime context: []const u8) void {
    result catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

// SH8601 requires even start/end boundaries for clean partial updates.
fn rounderCb(area: [*c]LvArea) callconv(.c) void {
    if (area == null) {
        return;
    }

    const x1 = area.*.x1;
    const x2 = area.*.x2;
    const y1 = area.*.y1;
    const y2 = area.*.y2;

    area.*.x1 = (x1 >> 1) << 1;
    area.*.y1 = (y1 >> 1) << 1;
    area.*.x2 = ((x2 >> 1) << 1) + 1;
    area.*.y2 = ((y2 >> 1) << 1) + 1;
}

fn initIntegratedDisplayZig() !lvgl.IntegratedDisplay {
    check(
        idf.err.espCheckError(c.waveshare_axp2101_init(TOUCH_I2C_PORT, TOUCH_SDA, TOUCH_SCL, TOUCH_FREQ_HZ)),
        "waveshare_axp2101_init",
    );
    check(
        idf.err.espCheckError(c.waveshare_axp2101_apply_touch_amoled_1_8_defaults()),
        "waveshare_axp2101_apply_touch_amoled_1_8_defaults",
    );
    idf.rtos.Task.delayMs(POWER_SETTLE_DELAY_MS);

    var bus_cfg = std.mem.zeroes(c.spi_bus_config_t);
    bus_cfg.unnamed_0.unnamed_0.unnamed_0.data0_io_num = LCD_D0;
    bus_cfg.unnamed_0.unnamed_0.unnamed_1.data1_io_num = LCD_D1;
    bus_cfg.unnamed_0.unnamed_0.sclk_io_num = LCD_SCLK;
    bus_cfg.unnamed_0.unnamed_0.unnamed_2.data2_io_num = LCD_D2;
    bus_cfg.unnamed_0.unnamed_0.unnamed_3.data3_io_num = LCD_D3;
    bus_cfg.max_transfer_sz = @as(c_int, @intCast(LCD_H_RES * LVGL_BUF_LINES * @sizeOf(u16)));

    check(
        idf.err.espCheckError(c.spi_bus_initialize(
            LCD_HOST,
            &bus_cfg,
            @as(c.spi_dma_chan_t, @intCast(c.SPI_DMA_CH_AUTO)),
        )),
        "spi_bus_initialize",
    );

    var io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_spi_config_t);
    io_cfg.cs_gpio_num = LCD_CS;
    io_cfg.dc_gpio_num = c.GPIO_NUM_NC;
    io_cfg.spi_mode = 0;
    io_cfg.pclk_hz = 40_000_000;
    io_cfg.trans_queue_depth = 10;
    io_cfg.lcd_cmd_bits = 32;
    io_cfg.lcd_param_bits = 8;
    io_cfg.flags.quad_mode = 1;

    var io_handle: c.esp_lcd_panel_io_handle_t = null;
    check(
        idf.err.espCheckError(c.esp_lcd_new_panel_io_spi(
            @as(c.esp_lcd_spi_bus_handle_t, @intCast(LCD_HOST)),
            &io_cfg,
            &io_handle,
        )),
        "esp_lcd_new_panel_io_spi",
    );

    var vendor_cfg = std.mem.zeroes(c.sh8601_vendor_config_t);
    vendor_cfg.init_cmds = &sh8601_init_cmds[0];
    vendor_cfg.init_cmds_size = @as(u16, @intCast(sh8601_init_cmds.len));
    vendor_cfg.flags.use_qspi_interface = 1;

    var panel_cfg = std.mem.zeroes(c.esp_lcd_panel_dev_config_t);
    panel_cfg.reset_gpio_num = LCD_RST;
    panel_cfg.rgb_ele_order = @as(c.lcd_rgb_element_order_t, @intCast(c.LCD_RGB_ELEMENT_ORDER_RGB));
    panel_cfg.bits_per_pixel = 16;
    panel_cfg.vendor_config = @ptrCast(&vendor_cfg);

    var panel: c.esp_lcd_panel_handle_t = null;
    check(idf.err.espCheckError(c.esp_lcd_new_panel_sh8601(io_handle, &panel_cfg, &panel)), "esp_lcd_new_panel_sh8601");
    check(idf.err.espCheckError(esp_lcd_panel_reset(panel)), "esp_lcd_panel_reset");
    check(idf.err.espCheckError(esp_lcd_panel_init(panel)), "esp_lcd_panel_init");
    check(idf.err.espCheckError(esp_lcd_panel_disp_on_off(panel, true)), "esp_lcd_panel_disp_on_off");

    var disp_cfg: LvglPortDisplayCfg = .{
        .io_handle = io_handle,
        .panel_handle = panel,
        .buffer_size = LCD_H_RES * LVGL_BUF_LINES,
        .double_buffer = true,
        .trans_size = 0,
        .hres = LCD_H_RES,
        .vres = LCD_V_RES,
        .monochrome = false,
        .rotation = .{
            .swap_xy = false,
            .mirror_x = false,
            .mirror_y = false,
        },
        .rounder_cb = rounderCb,
        .color_format = 0, // Default is LV_COLOR_FORMAT_RGB565.
        .flags = .{
            .buff_dma = 1,
            .buff_spiram = 0,
            .sw_rotate = 0,
            .swap_bytes = 1,
            .full_refresh = 0,
            .direct_mode = 0,
        },
    };

    const disp = lvgl_port_add_disp(&disp_cfg) orelse return error.lvgl_port_add_disp_failed;

    var i2c_bus: c.i2c_master_bus_handle_t = null;
    const bus_err = c.i2c_master_get_bus_handle(TOUCH_I2C_PORT, &i2c_bus);
    if (bus_err != c.ESP_OK) {
        log.warn("Touch disabled: failed to get I2C bus handle (err={d})", .{bus_err});
        return .{
            .display = disp,
            .touch = null,
        };
    }

    var touch_io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_i2c_config_t);
    touch_io_cfg.dev_addr = @as(u32, @intCast(c.ESP_LCD_TOUCH_IO_I2C_FT5x06_ADDRESS));
    touch_io_cfg.scl_speed_hz = TOUCH_FREQ_HZ;
    touch_io_cfg.control_phase_bytes = 1;
    touch_io_cfg.dc_bit_offset = 0;
    touch_io_cfg.lcd_cmd_bits = 8;
    touch_io_cfg.lcd_param_bits = 8;
    touch_io_cfg.flags.disable_control_phase = 1;

    var touch_cfg = std.mem.zeroes(c.esp_lcd_touch_config_t);
    touch_cfg.x_max = @as(u16, @intCast(LCD_H_RES));
    touch_cfg.y_max = @as(u16, @intCast(LCD_V_RES));
    touch_cfg.rst_gpio_num = c.GPIO_NUM_NC;
    touch_cfg.int_gpio_num = TOUCH_INT;
    touch_cfg.levels = .{
        .reset = 0,
        .interrupt = 0,
    };
    touch_cfg.flags = .{
        .swap_xy = 0,
        .mirror_x = 0,
        .mirror_y = 0,
    };

    var attempt: u32 = 1;
    while (attempt <= TOUCH_INIT_RETRIES) : (attempt += 1) {
        var touch_io: c.esp_lcd_panel_io_handle_t = null;
        const io_err = c.esp_lcd_new_panel_io_i2c(i2c_bus, &touch_io_cfg, &touch_io);
        if (io_err != c.ESP_OK) {
            log.warn("Touch IO init attempt {d}/{d} failed (err={d})", .{ attempt, TOUCH_INIT_RETRIES, io_err });
            idf.rtos.Task.delayMs(TOUCH_RETRY_DELAY_MS);
            continue;
        }

        var touch_handle: c.esp_lcd_touch_handle_t = null;
        const touch_err = c.esp_lcd_touch_new_i2c_ft5x06(touch_io, &touch_cfg, &touch_handle);
        if (touch_err != c.ESP_OK) {
            log.warn("Touch controller init attempt {d}/{d} failed (err={d})", .{ attempt, TOUCH_INIT_RETRIES, touch_err });
            _ = c.esp_lcd_panel_io_del(touch_io);
            idf.rtos.Task.delayMs(TOUCH_RETRY_DELAY_MS);
            continue;
        }

        const lvgl_touch_cfg: LvglPortTouchCfg = .{
            .disp = disp,
            .handle = touch_handle,
            .scale = .{
                .x = 1.0,
                .y = 1.0,
            },
        };
        const touch_indev = lvgl_port_add_touch(&lvgl_touch_cfg);
        if (touch_indev == null) {
            log.warn("Touch driver initialized but lvgl_port_add_touch failed", .{});
            _ = c.esp_lcd_touch_del(touch_handle);
            _ = c.esp_lcd_panel_io_del(touch_io);
            return .{
                .display = disp,
                .touch = null,
            };
        }

        log.info("Touch initialized on attempt {d}/{d}", .{ attempt, TOUCH_INIT_RETRIES });
        return .{
            .display = disp,
            .touch = touch_indev,
        };
    }

    log.warn("Touch disabled after {d} failed init attempts", .{TOUCH_INIT_RETRIES});
    return .{
        .display = disp,
        .touch = null,
    };
}

fn createCenteredLabel(text: [*:0]const u8) ?*lvgl.Object {
    const screen = lvgl.activeScreen() orelse return null;
    const label = lvgl.createLabel(screen) orelse return null;
    lvgl.setLabelText(label, text);
    lvgl.center(label);
    return label;
}

fn main() callconv(.c) void {
    check(lvgl.initPortDefault(), "lvgl.initPortDefault");

    const integrated = blk: {
        break :blk initIntegratedDisplayZig() catch |err| {
            log.err("initIntegratedDisplayZig failed: {s}", .{@errorName(err)});
            @panic("initIntegratedDisplayZig");
        };
    };

    log.info("LVGL display initialized for SH8601 AMOLED (368x448)", .{});
    if (!integrated.hasTouch()) {
        log.warn("Touch init failed, running in display-only mode", .{});
    }

    var label: ?*lvgl.Object = null;
    if (!lvgl.lock(0)) @panic("lvgl.lock");
    label = blk: {
        defer lvgl.unlock();
        break :blk createCenteredLabel("Zig + LVGL\nSH8601 integrated display") orelse @panic("createCenteredLabel");
    };

    var uptime_sec: u32 = 0;
    while (true) : (uptime_sec += 1) {
        idf.rtos.Task.delayMs(1000);

        if (!lvgl.lock(100)) {
            continue;
        }
        defer lvgl.unlock();

        if (label != null) {
            var msg_buf: [80]u8 = undefined;
            const msg = std.fmt.bufPrintZ(
                &msg_buf,
                "Zig + LVGL\nSH8601 integrated display\nUptime: {d}s",
                .{uptime_sec},
            ) catch continue;
            if (label) |obj| {
                lvgl.setLabelText(obj, msg.ptr);
                lvgl.center(obj);
            }
        }
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
