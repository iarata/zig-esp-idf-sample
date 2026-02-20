const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const lvgl = idf.lvgl;

const log = std.log.scoped(.lvgl);

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn check(result: anyerror!void, comptime context: []const u8) void {
    result catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

fn main() callconv(.c) void {
    check(lvgl.initPortDefault(), "lvgl.initPortDefault");

    log.info("LVGL v{d}.{d}.{d} initialized via esp_lvgl_port", .{
        idf.sys.CONFIG_LVGL_VERSION_MAJOR,
        idf.sys.CONFIG_LVGL_VERSION_MINOR,
        idf.sys.CONFIG_LVGL_VERSION_PATCH,
    });

    if (!lvgl.lock(0)) {
        log.warn("Failed to lock LVGL mutex", .{});
    } else {
        defer lvgl.unlock();

        const screen = lvgl.activeScreen();
        if (screen == null) {
            log.warn("No active LVGL display yet. Add display with lvgl_port_add_disp before creating widgets.", .{});
        } else {
            const label = lvgl.createLabel(screen);
            if (label != null) {
                lvgl.setLabelText(label, "Hello from Zig + LVGL");
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
