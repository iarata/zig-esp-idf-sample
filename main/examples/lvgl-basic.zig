const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const c = idf.sys;

const log = std.log.scoped(.lvgl);

const lv_obj_t = opaque {};

const lvgl_port_cfg_t = extern struct {
    task_priority: c_int = 0,
    task_stack: c_int = 0,
    task_affinity: c_int = 0,
    task_max_sleep_ms: c_int = 0,
    task_stack_caps: c_uint = 0,
    timer_period_ms: c_int = 0,
};

extern fn lvgl_port_init(cfg: [*c]const lvgl_port_cfg_t) c.esp_err_t;
extern fn lvgl_port_lock(timeout_ms: u32) bool;
extern fn lvgl_port_unlock() void;

extern fn lv_screen_active() ?*lv_obj_t;
extern fn lv_label_create(parent: ?*lv_obj_t) ?*lv_obj_t;
extern fn lv_label_set_text(obj: ?*lv_obj_t, text: [*:0]const u8) void;

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
    var cfg = lvgl_port_cfg_t{
        .task_priority = 4,
        .task_stack = 7168,
        .task_affinity = -1,
        .task_max_sleep_ms = 500,
        .task_stack_caps = @as(c_uint, @intCast(c.MALLOC_CAP_INTERNAL | c.MALLOC_CAP_DEFAULT)),
        .timer_period_ms = 5,
    };
    espCheck(lvgl_port_init(&cfg), "lvgl_port_init");

    log.info("LVGL v{d}.{d}.{d} initialized via esp_lvgl_port", .{
        c.CONFIG_LVGL_VERSION_MAJOR,
        c.CONFIG_LVGL_VERSION_MINOR,
        c.CONFIG_LVGL_VERSION_PATCH,
    });

    if (!lvgl_port_lock(0)) {
        log.warn("Failed to lock LVGL mutex", .{});
    } else {
        defer lvgl_port_unlock();

        const screen = lv_screen_active();
        if (screen == null) {
            log.warn("No active LVGL display yet. Add display with lvgl_port_add_disp before creating widgets.", .{});
        } else {
            const label = lv_label_create(screen);
            if (label != null) {
                lv_label_set_text(label, "Hello from Zig + LVGL");
                log.info("Created label on active screen", .{});
            }
        }
    }

    while (true) {
        idf.rtos.Task.delayMs(1000);
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
