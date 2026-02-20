// BEGIN_PATCH:esp_lcd_panel_configs
pub const esp_lcd_panel_dev_flags_t = packed struct(u32) {
    reset_active_high: u1 = 0,
    reserved: u31 = 0,
};

pub const esp_lcd_panel_dev_config_t = extern struct {
    rgb_ele_order: lcd_rgb_element_order_t = @import("std").mem.zeroes(lcd_rgb_element_order_t),
    data_endian: lcd_rgb_data_endian_t = @import("std").mem.zeroes(lcd_rgb_data_endian_t),
    bits_per_pixel: u32 = 0,
    reset_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    vendor_config: ?*anyopaque = null,
    flags: esp_lcd_panel_dev_flags_t = .{},
};

pub const sh8601_vendor_flags_t = packed struct(u32) {
    use_qspi_interface: u1 = 0,
    reserved: u31 = 0,
};

pub const sh8601_vendor_config_t = extern struct {
    init_cmds: [*c]const sh8601_lcd_init_cmd_t = null,
    init_cmds_size: u16 = 0,
    flags: sh8601_vendor_flags_t = .{},
};

pub const esp_lcd_panel_io_i80_dc_levels_t = packed struct(u32) {
    dc_idle_level: u1 = 0,
    dc_cmd_level: u1 = 0,
    dc_dummy_level: u1 = 0,
    dc_data_level: u1 = 0,
    reserved: u28 = 0,
};

pub const esp_lcd_panel_io_i80_flags_t = packed struct(u32) {
    cs_active_high: u1 = 0,
    reverse_color_bits: u1 = 0,
    swap_color_bytes: u1 = 0,
    pclk_active_neg: u1 = 0,
    pclk_idle_low: u1 = 0,
    reserved: u27 = 0,
};

pub const esp_lcd_panel_io_i80_config_t = extern struct {
    cs_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    pclk_hz: u32 = 0,
    trans_queue_depth: usize = 0,
    on_color_trans_done: esp_lcd_panel_io_color_trans_done_cb_t = null,
    user_ctx: ?*anyopaque = null,
    lcd_cmd_bits: c_int = 0,
    lcd_param_bits: c_int = 0,
    dc_levels: esp_lcd_panel_io_i80_dc_levels_t = .{},
    flags: esp_lcd_panel_io_i80_flags_t = .{},
};

pub const esp_lcd_panel_io_i2c_flags_t = packed struct(u32) {
    dc_low_on_data: u1 = 0,
    disable_control_phase: u1 = 0,
    reserved: u30 = 0,
};

pub const esp_lcd_panel_io_i2c_config_t = extern struct {
    dev_addr: u32 = 0,
    scl_speed_hz: u32 = 0,
    control_phase_bytes: usize = 0,
    dc_bit_offset: u8 = 0,
    lcd_cmd_bits: c_int = 0,
    lcd_param_bits: c_int = 0,
    on_color_trans_done: esp_lcd_panel_io_color_trans_done_cb_t = null,
    user_ctx: ?*anyopaque = null,
    flags: esp_lcd_panel_io_i2c_flags_t = .{},
};

pub const esp_lcd_panel_io_spi_flags_t = packed struct(u32) {
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

pub const esp_lcd_panel_io_spi_config_t = extern struct {
    cs_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    dc_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    spi_mode: c_int = 0,
    pclk_hz: c_uint = 0,
    trans_queue_depth: usize = 0,
    on_color_trans_done: esp_lcd_panel_io_color_trans_done_cb_t = null,
    user_ctx: ?*anyopaque = null,
    lcd_cmd_bits: c_int = 0,
    lcd_param_bits: c_int = 0,
    cs_ena_pretrans: u8 = 0,
    cs_ena_posttrans: u8 = 0,
    flags: esp_lcd_panel_io_spi_flags_t = .{},
};
// END_PATCH:esp_lcd_panel_configs
