const sys = @import("sys");
const errors = @import("error");

pub const Object = opaque {};
pub const Display = opaque {};
pub const InputDevice = opaque {};

pub const PortConfig = extern struct {
    task_priority: c_int = 0,
    task_stack: c_int = 0,
    task_affinity: c_int = 0,
    task_max_sleep_ms: c_int = 0,
    task_stack_caps: c_uint = 0,
    timer_period_ms: c_int = 0,
};

pub const default_port_config: PortConfig = .{
    .task_priority = 4,
    .task_stack = 7168,
    .task_affinity = -1,
    .task_max_sleep_ms = 500,
    .task_stack_caps = @as(c_uint, @intCast(sys.MALLOC_CAP_INTERNAL | sys.MALLOC_CAP_DEFAULT)),
    .timer_period_ms = 5,
};

pub const IntegratedDisplay = struct {
    display: ?*Display,
    touch: ?*InputDevice,

    pub fn hasTouch(self: IntegratedDisplay) bool {
        return self.touch != null;
    }
};

extern fn lvgl_port_init(cfg: [*c]const PortConfig) sys.esp_err_t;
extern fn lvgl_port_lock(timeout_ms: u32) bool;
extern fn lvgl_port_unlock() void;

extern fn zig_lvgl_touch_amoled_1_8_init(
    out_disp: [*c]?*Display,
    out_touch: [*c]?*InputDevice,
) sys.esp_err_t;
extern fn zig_lvgl_apply_test_label_style(label: ?*Object) void;
extern fn zig_lvgl_create_centered_label(text: [*:0]const u8) ?*Object;

extern fn lv_screen_active() ?*Object;
extern fn lv_label_create(parent: ?*Object) ?*Object;
extern fn lv_label_set_text(obj: ?*Object, text: [*:0]const u8) void;
extern fn lv_obj_center(obj: ?*Object) void;

pub fn initPort(cfg: PortConfig) !void {
    var mutable_cfg = cfg;
    try errors.espCheckError(lvgl_port_init(&mutable_cfg));
}

pub fn initPortDefault() !void {
    try initPort(default_port_config);
}

pub fn initIntegratedDisplay() !IntegratedDisplay {
    var display: ?*Display = null;
    var touch: ?*InputDevice = null;
    try errors.espCheckError(zig_lvgl_touch_amoled_1_8_init(&display, &touch));
    return .{
        .display = display,
        .touch = touch,
    };
}

pub fn lock(timeout_ms: u32) bool {
    return lvgl_port_lock(timeout_ms);
}

pub fn unlock() void {
    lvgl_port_unlock();
}

pub fn activeScreen() ?*Object {
    return lv_screen_active();
}

pub fn createLabel(parent: ?*Object) ?*Object {
    return lv_label_create(parent);
}

pub fn setLabelText(label: ?*Object, text: [*:0]const u8) void {
    lv_label_set_text(label, text);
}

pub fn center(label: ?*Object) void {
    lv_obj_center(label);
}

pub fn applyTestLabelStyle(label: ?*Object) void {
    zig_lvgl_apply_test_label_style(label);
}

pub fn createCenteredTestLabel(text: [*:0]const u8) ?*Object {
    return zig_lvgl_create_centered_label(text);
}

pub fn createCenteredLabel(text: [*:0]const u8) ?*Object {
    return createCenteredTestLabel(text);
}
