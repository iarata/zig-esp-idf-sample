//! # LVGL + esp_lvgl_port Integration Layer (`lvgl`)
//!
//! **What:** Thin wrapper combining the LVGL graphics library with the
//! `esp_lvgl_port` helper component for ESP-IDF.  Provides port init, display
//! registration, touch input, thread-safe locking, and basic LVGL object
//! helpers.
//!
//! **What it does:**
//!   - `initPort(cfg)` / `initPortDefault()` — start the LVGL timer task with
//!     configurable priority, stack size, and sleep interval.
//!   - `initIntegratedDisplay()` — one-call helper that creates display +
//!     touch for the Waveshare AMOLED 1.8" board using C glue functions.
//!   - `lock(timeout)` / `unlock()` — acquire/release the LVGL mutex; **every
//!     LVGL API call must be protected by this lock**.
//!   - `activeScreen()` / `createLabel(parent)` / `setLabelText(label, text)`
//!     / `center(obj)` — basic widget creation helpers.
//!   - `applyTestLabelStyle` / `applyRunaStyle` — apply predefined visual
//!     styles (implemented in C glue).
//!
//! **How:** Calls extern C functions from `esp_lvgl_port`, LVGL core, and a
//! project-specific C glue file (`lvgl_integrated_display_helpers.c`).  The
//! opaque `Object`, `Display`, and `InputDevice` types prevent misuse with
//! incompatible LVGL object pointers.
//!
//! **When to use:** Any app that needs a graphical UI on an LCD/AMOLED.
//!
//! **What it takes:**
//!   - A `PortConfig` (or use the provided `default_port_config`).
//!   - Display and touch hardware initialised separately or via
//!     `initIntegratedDisplay`.
//!
//! **Example:**
//! ```zig
//! const lvgl = idf.lvgl;
//! try lvgl.initPortDefault();
//! const integrated = try lvgl.initIntegratedDisplay();
//! if (!lvgl.lock(0)) @panic("lock");
//! defer lvgl.unlock();
//! const label = lvgl.createLabel(lvgl.activeScreen()) orelse @panic("label");
//! lvgl.setLabelText(label, "Hello!");
//! lvgl.center(label);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// Opaque handle to an LVGL object (widget, screen, etc.).
pub const Object = opaque {};
/// Opaque handle to an LVGL display driver instance.
pub const Display = opaque {};
/// Opaque handle to an LVGL input device (touch, encoder, etc.).
pub const InputDevice = opaque {};

/// Configuration for the LVGL port task (timer period, stack size, affinity).
pub const PortConfig = extern struct {
    /// LVGL timer task priority.
    task_priority: c_int = 0,
    /// Stack size in bytes for the LVGL timer task.
    task_stack: c_int = 0,
    /// Core affinity (`-1` = any core).
    task_affinity: c_int = 0,
    /// Maximum sleep time between LVGL timer ticks (ms).
    task_max_sleep_ms: c_int = 0,
    /// `MALLOC_CAP_*` flags for the task stack allocation.
    task_stack_caps: c_uint = 0,
    /// LVGL timer tick period (ms).
    timer_period_ms: c_int = 0,
};

/// Sensible default port configuration (priority 4, 7 KiB stack, 5 ms tick).
pub const default_port_config: PortConfig = .{
    .task_priority = 4,
    .task_stack = 7168,
    .task_affinity = -1,
    .task_max_sleep_ms = 500,
    .task_stack_caps = @as(c_uint, @intCast(sys.MALLOC_CAP_INTERNAL | sys.MALLOC_CAP_DEFAULT)),
    .timer_period_ms = 5,
};

/// Result of `initIntegratedDisplay` containing display and optional touch handles.
pub const IntegratedDisplay = struct {
    /// The LVGL display driver handle.
    display: ?*Display,
    /// The LVGL touch input device handle (null if no touch panel).
    touch: ?*InputDevice,

    /// Returns `true` when a touch input device was successfully initialised.
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
extern fn zig_lvgl_apply_runa_style(screen: ?*Object, label: ?*Object) void;

extern fn lv_screen_active() ?*Object;
extern fn lv_label_create(parent: ?*Object) ?*Object;
extern fn lv_label_set_text(obj: ?*Object, text: [*:0]const u8) void;
extern fn lv_obj_center(obj: ?*Object) void;

/// Initialise the LVGL port timer task with the given configuration.
pub fn initPort(cfg: PortConfig) !void {
    var mutable_cfg = cfg;
    try errors.espCheckError(lvgl_port_init(&mutable_cfg));
}

/// Initialise the LVGL port with `default_port_config`.
pub fn initPortDefault() !void {
    try initPort(default_port_config);
}

/// Create display and touch drivers for the Waveshare AMOLED 1.8" board.
pub fn initIntegratedDisplay() !IntegratedDisplay {
    var display: ?*Display = null;
    var touch: ?*InputDevice = null;
    try errors.espCheckError(zig_lvgl_touch_amoled_1_8_init(&display, &touch));
    return .{
        .display = display,
        .touch = touch,
    };
}

/// Acquire the LVGL mutex. Returns `true` on success.
///
/// **Every LVGL API call must be wrapped in lock/unlock.**
pub fn lock(timeout_ms: u32) bool {
    return lvgl_port_lock(timeout_ms);
}

/// Release the LVGL mutex.
pub fn unlock() void {
    lvgl_port_unlock();
}

/// Get the currently active LVGL screen.
pub fn activeScreen() ?*Object {
    return lv_screen_active();
}

/// Create a label widget as a child of `parent`.
pub fn createLabel(parent: ?*Object) ?*Object {
    return lv_label_create(parent);
}

/// Set the text content of a label widget.
pub fn setLabelText(label: ?*Object, text: [*:0]const u8) void {
    lv_label_set_text(label, text);
}

/// Centre an object within its parent.
pub fn center(label: ?*Object) void {
    lv_obj_center(label);
}

/// Apply the built-in test label style (C glue).
pub fn applyTestLabelStyle(label: ?*Object) void {
    zig_lvgl_apply_test_label_style(label);
}

/// Create a centred label with test styling.
pub fn createCenteredTestLabel(text: [*:0]const u8) ?*Object {
    return zig_lvgl_create_centered_label(text);
}

/// Alias for `createCenteredTestLabel`.
pub fn createCenteredLabel(text: [*:0]const u8) ?*Object {
    return createCenteredTestLabel(text);
}

/// Apply the "runa" decorative style to screen and label (C glue).
pub fn applyRunaStyle(screen: ?*Object, label: ?*Object) void {
    zig_lvgl_apply_runa_style(screen, label);
}
