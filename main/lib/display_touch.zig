const std = @import("std");
const idf = @import("esp_idf");
const c = idf.sys;

pub const lvgl = idf.lvgl;

const log = std.log.scoped(.display_touch);

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

pub const PinConfig = struct {
    lcd_host: c.spi_host_device_t = c.SPI2_HOST,
    touch_i2c_port: c.i2c_port_num_t = c.I2C_NUM_0,
    touch_sda: c.gpio_num_t = c.GPIO_NUM_15,
    touch_scl: c.gpio_num_t = c.GPIO_NUM_14,
    touch_int: c.gpio_num_t = c.GPIO_NUM_21,
    lcd_sclk: c.gpio_num_t = c.GPIO_NUM_11,
    lcd_d0: c.gpio_num_t = c.GPIO_NUM_4,
    lcd_d1: c.gpio_num_t = c.GPIO_NUM_5,
    lcd_d2: c.gpio_num_t = c.GPIO_NUM_6,
    lcd_d3: c.gpio_num_t = c.GPIO_NUM_7,
    lcd_cs: c.gpio_num_t = c.GPIO_NUM_12,
    lcd_rst: c.gpio_num_t = c.GPIO_NUM_NC,
};

pub const RotationConfig = struct {
    swap_xy: bool = false,
    mirror_x: bool = false,
    mirror_y: bool = false,
};

pub const DisplayFlags = struct {
    buff_dma: bool = true,
    buff_spiram: bool = false,
    sw_rotate: bool = false,
    swap_bytes: bool = true,
    full_refresh: bool = false,
    direct_mode: bool = false,
};

pub const DisplayConfig = struct {
    hres: u32 = 368,
    vres: u32 = 448,
    buffer_lines: u32 = 48,
    double_buffer: bool = true,
    round_to_even: bool = true,
    rotation: RotationConfig = .{},
    flags: DisplayFlags = .{},
};

pub const TouchTransform = struct {
    swap_xy: bool = false,
    mirror_x: bool = false,
    mirror_y: bool = false,
    scale_x: f32 = 1.0,
    scale_y: f32 = 1.0,
};

pub const TouchConfig = struct {
    freq_hz: u32 = 400_000,
    init_retries: u32 = 5,
    retry_delay_ms: u32 = 80,
    required: bool = false,
    transform: TouchTransform = .{},
};

pub const PowerConfig = struct {
    settle_delay_ms: u32 = 350,
};

pub const InitOptions = struct {
    init_lvgl_port: bool = true,
    lvgl_port_cfg: lvgl.PortConfig = lvgl.default_port_config,
    pins: PinConfig = .{},
    display: DisplayConfig = .{},
    touch: TouchConfig = .{},
    power: PowerConfig = .{},
};

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

// SH8601 requires even start/end boundaries for clean partial updates.
fn rounderCb(area: [*c]LvArea) callconv(.c) void {
    if (area == null) return;

    const x1 = area.*.x1;
    const x2 = area.*.x2;
    const y1 = area.*.y1;
    const y2 = area.*.y2;

    area.*.x1 = (x1 >> 1) << 1;
    area.*.y1 = (y1 >> 1) << 1;
    area.*.x2 = ((x2 >> 1) << 1) + 1;
    area.*.y2 = ((y2 >> 1) << 1) + 1;
}

fn asBit(value: bool) u1 {
    return if (value) 1 else 0;
}

pub fn initDefault() !lvgl.IntegratedDisplay {
    return init(.{});
}

pub fn init(options: InitOptions) !lvgl.IntegratedDisplay {
    if (options.init_lvgl_port) {
        try lvgl.initPort(options.lvgl_port_cfg);
    }

    try idf.err.espCheckError(c.waveshare_axp2101_init(
        options.pins.touch_i2c_port,
        options.pins.touch_sda,
        options.pins.touch_scl,
        options.touch.freq_hz,
    ));
    try idf.err.espCheckError(c.waveshare_axp2101_apply_touch_amoled_1_8_defaults());
    idf.rtos.Task.delayMs(options.power.settle_delay_ms);

    var bus_cfg = std.mem.zeroes(c.spi_bus_config_t);
    bus_cfg.unnamed_0.unnamed_0.unnamed_0.data0_io_num = options.pins.lcd_d0;
    bus_cfg.unnamed_0.unnamed_0.unnamed_1.data1_io_num = options.pins.lcd_d1;
    bus_cfg.unnamed_0.unnamed_0.sclk_io_num = options.pins.lcd_sclk;
    bus_cfg.unnamed_0.unnamed_0.unnamed_2.data2_io_num = options.pins.lcd_d2;
    bus_cfg.unnamed_0.unnamed_0.unnamed_3.data3_io_num = options.pins.lcd_d3;
    bus_cfg.max_transfer_sz = @as(c_int, @intCast(
        options.display.hres * options.display.buffer_lines * @sizeOf(u16),
    ));

    try idf.err.espCheckError(c.spi_bus_initialize(
        options.pins.lcd_host,
        &bus_cfg,
        @as(c.spi_dma_chan_t, @intCast(c.SPI_DMA_CH_AUTO)),
    ));

    var io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_spi_config_t);
    io_cfg.cs_gpio_num = options.pins.lcd_cs;
    io_cfg.dc_gpio_num = c.GPIO_NUM_NC;
    io_cfg.spi_mode = 0;
    io_cfg.pclk_hz = 40_000_000;
    io_cfg.trans_queue_depth = 10;
    io_cfg.lcd_cmd_bits = 32;
    io_cfg.lcd_param_bits = 8;
    io_cfg.flags.quad_mode = 1;

    var io_handle: c.esp_lcd_panel_io_handle_t = null;
    try idf.err.espCheckError(c.esp_lcd_new_panel_io_spi(
        @as(c.esp_lcd_spi_bus_handle_t, @intCast(options.pins.lcd_host)),
        &io_cfg,
        &io_handle,
    ));

    var vendor_cfg = std.mem.zeroes(c.sh8601_vendor_config_t);
    vendor_cfg.init_cmds = &sh8601_init_cmds[0];
    vendor_cfg.init_cmds_size = @as(u16, @intCast(sh8601_init_cmds.len));
    vendor_cfg.flags.use_qspi_interface = 1;

    var panel_cfg = std.mem.zeroes(c.esp_lcd_panel_dev_config_t);
    panel_cfg.reset_gpio_num = options.pins.lcd_rst;
    panel_cfg.rgb_ele_order = @as(c.lcd_rgb_element_order_t, @intCast(c.LCD_RGB_ELEMENT_ORDER_RGB));
    panel_cfg.bits_per_pixel = 16;
    panel_cfg.vendor_config = @ptrCast(&vendor_cfg);

    var panel: c.esp_lcd_panel_handle_t = null;
    try idf.err.espCheckError(c.esp_lcd_new_panel_sh8601(io_handle, &panel_cfg, &panel));
    try idf.err.espCheckError(esp_lcd_panel_reset(panel));
    try idf.err.espCheckError(esp_lcd_panel_init(panel));
    try idf.err.espCheckError(esp_lcd_panel_disp_on_off(panel, true));

    const disp_cfg: LvglPortDisplayCfg = .{
        .io_handle = io_handle,
        .panel_handle = panel,
        .buffer_size = options.display.hres * options.display.buffer_lines,
        .double_buffer = options.display.double_buffer,
        .trans_size = 0,
        .hres = options.display.hres,
        .vres = options.display.vres,
        .monochrome = false,
        .rotation = .{
            .swap_xy = options.display.rotation.swap_xy,
            .mirror_x = options.display.rotation.mirror_x,
            .mirror_y = options.display.rotation.mirror_y,
        },
        .rounder_cb = if (options.display.round_to_even) rounderCb else null,
        .color_format = 0, // LV_COLOR_FORMAT_RGB565 default
        .flags = .{
            .buff_dma = asBit(options.display.flags.buff_dma),
            .buff_spiram = asBit(options.display.flags.buff_spiram),
            .sw_rotate = asBit(options.display.flags.sw_rotate),
            .swap_bytes = asBit(options.display.flags.swap_bytes),
            .full_refresh = asBit(options.display.flags.full_refresh),
            .direct_mode = asBit(options.display.flags.direct_mode),
        },
    };

    const disp = lvgl_port_add_disp(&disp_cfg) orelse return error.DisplayInitFailed;

    var i2c_bus: c.i2c_master_bus_handle_t = null;
    const bus_err = c.i2c_master_get_bus_handle(options.pins.touch_i2c_port, &i2c_bus);
    if (bus_err != c.ESP_OK) {
        log.warn("Touch disabled: i2c_master_get_bus_handle failed (err={d})", .{bus_err});
        if (options.touch.required) return error.TouchInitFailed;
        return .{
            .display = disp,
            .touch = null,
        };
    }

    var touch_io_cfg = std.mem.zeroes(c.esp_lcd_panel_io_i2c_config_t);
    touch_io_cfg.dev_addr = @as(u32, @intCast(c.ESP_LCD_TOUCH_IO_I2C_FT5x06_ADDRESS));
    touch_io_cfg.scl_speed_hz = options.touch.freq_hz;
    touch_io_cfg.control_phase_bytes = 1;
    touch_io_cfg.dc_bit_offset = 0;
    touch_io_cfg.lcd_cmd_bits = 8;
    touch_io_cfg.lcd_param_bits = 8;
    touch_io_cfg.flags.disable_control_phase = 1;

    var touch_cfg = std.mem.zeroes(c.esp_lcd_touch_config_t);
    touch_cfg.x_max = @as(u16, @intCast(options.display.hres));
    touch_cfg.y_max = @as(u16, @intCast(options.display.vres));
    touch_cfg.rst_gpio_num = c.GPIO_NUM_NC;
    touch_cfg.int_gpio_num = options.pins.touch_int;
    touch_cfg.levels = .{
        .reset = 0,
        .interrupt = 0,
    };
    touch_cfg.flags = .{
        .swap_xy = asBit(options.touch.transform.swap_xy),
        .mirror_x = asBit(options.touch.transform.mirror_x),
        .mirror_y = asBit(options.touch.transform.mirror_y),
    };

    var attempt: u32 = 1;
    while (attempt <= options.touch.init_retries) : (attempt += 1) {
        var touch_io: c.esp_lcd_panel_io_handle_t = null;
        const io_err = c.esp_lcd_new_panel_io_i2c(i2c_bus, &touch_io_cfg, &touch_io);
        if (io_err != c.ESP_OK) {
            log.warn("Touch IO init attempt {d}/{d} failed (err={d})", .{ attempt, options.touch.init_retries, io_err });
            idf.rtos.Task.delayMs(options.touch.retry_delay_ms);
            continue;
        }

        var touch_handle: c.esp_lcd_touch_handle_t = null;
        const touch_err = c.esp_lcd_touch_new_i2c_ft5x06(touch_io, &touch_cfg, &touch_handle);
        if (touch_err != c.ESP_OK) {
            log.warn("Touch controller init attempt {d}/{d} failed (err={d})", .{ attempt, options.touch.init_retries, touch_err });
            _ = c.esp_lcd_panel_io_del(touch_io);
            idf.rtos.Task.delayMs(options.touch.retry_delay_ms);
            continue;
        }

        const lvgl_touch_cfg: LvglPortTouchCfg = .{
            .disp = disp,
            .handle = touch_handle,
            .scale = .{
                .x = options.touch.transform.scale_x,
                .y = options.touch.transform.scale_y,
            },
        };
        const touch_indev = lvgl_port_add_touch(&lvgl_touch_cfg);
        if (touch_indev == null) {
            log.warn("Touch driver initialized but lvgl_port_add_touch failed", .{});
            _ = c.esp_lcd_touch_del(touch_handle);
            _ = c.esp_lcd_panel_io_del(touch_io);
            if (options.touch.required) return error.TouchInitFailed;
            return .{
                .display = disp,
                .touch = null,
            };
        }

        log.info("Touch initialized on attempt {d}/{d}", .{ attempt, options.touch.init_retries });
        return .{
            .display = disp,
            .touch = touch_indev,
        };
    }

    log.warn("Touch disabled after {d} failed init attempts", .{options.touch.init_retries});
    if (options.touch.required) return error.TouchInitFailed;

    return .{
        .display = disp,
        .touch = null,
    };
}
