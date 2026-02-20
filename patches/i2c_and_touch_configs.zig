// BEGIN_PATCH:i2c_and_touch_configs
pub const i2c_master_bus_config_flags_t = packed struct(u32) {
    enable_internal_pullup: u1 = 0,
    allow_pd: u1 = 0,
    reserved: u30 = 0,
};

pub const i2c_master_bus_config_t = extern struct {
    i2c_port: i2c_port_num_t = 0,
    sda_io_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    scl_io_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    unnamed_0: union_unnamed_23 = @import("std").mem.zeroes(union_unnamed_23),
    glitch_ignore_cnt: u8 = 0,
    intr_priority: c_int = 0,
    trans_queue_depth: usize = 0,
    flags: i2c_master_bus_config_flags_t = .{},
    pub const i2c_new_master_bus = __root.i2c_new_master_bus;
    pub const bus = __root.i2c_new_master_bus;
};

pub const i2c_device_config_flags_t = packed struct(u32) {
    disable_ack_check: u1 = 0,
    reserved: u31 = 0,
};

pub const i2c_device_config_t = extern struct {
    dev_addr_length: i2c_addr_bit_len_t = @import("std").mem.zeroes(i2c_addr_bit_len_t),
    device_address: u16 = 0,
    scl_speed_hz: u32 = 0,
    scl_wait_us: u32 = 0,
    flags: i2c_device_config_flags_t = .{},
};

pub const esp_lcd_touch_levels_t = packed struct(u32) {
    reset: u1 = 0,
    interrupt: u1 = 0,
    reserved: u30 = 0,
};

pub const esp_lcd_touch_flags_t = packed struct(u32) {
    swap_xy: u1 = 0,
    mirror_x: u1 = 0,
    mirror_y: u1 = 0,
    reserved: u29 = 0,
};

pub const esp_lcd_touch_config_t = extern struct {
    x_max: u16 = 0,
    y_max: u16 = 0,
    rst_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    int_gpio_num: gpio_num_t = @import("std").mem.zeroes(gpio_num_t),
    levels: esp_lcd_touch_levels_t = .{},
    flags: esp_lcd_touch_flags_t = .{},
    process_coordinates: ?*const fn (tp: esp_lcd_touch_handle_t, x: [*c]u16, y: [*c]u16, strength: [*c]u16, point_num: [*c]u8, max_point_num: u8) callconv(.c) void = null,
    interrupt_callback: esp_lcd_touch_interrupt_callback_t = null,
    user_data: ?*anyopaque = null,
};
// END_PATCH:i2c_and_touch_configs
