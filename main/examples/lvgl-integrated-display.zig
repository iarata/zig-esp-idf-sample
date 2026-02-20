const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const display_touch = @import("../lib/display_touch.zig");
const ui = @import("../lib/ui.zig");

const lvgl = display_touch.lvgl;
const log = std.log.scoped(.lvgl_integrated);

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn main() callconv(.c) void {
    const integrated = display_touch.initDefault() catch |err| {
        log.err("display_touch.initDefault failed: {s}", .{@errorName(err)});
        @panic("display_touch.initDefault");
    };

    log.info("LVGL display initialized for SH8601 AMOLED (368x448)", .{});
    if (!integrated.hasTouch()) {
        log.warn("Touch init failed, running in display-only mode", .{});
    }

    if (!lvgl.lock(0)) @panic("lvgl.lock");
    var root = blk: {
        defer lvgl.unlock();
        break :blk ui.mount(.{
            .text = "Zig + LVGL\nSH8601 integrated display",
        }) orelse @panic("ui.mount");
    };

    var uptime_sec: u32 = 0;
    while (true) : (uptime_sec += 1) {
        idf.rtos.Task.delayMs(1000);

        if (!lvgl.lock(100)) continue;
        defer lvgl.unlock();

        var msg_buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrintZ(
            &msg_buf,
            "Zig + LVGL\nSH8601 integrated display\nUptime: {d}s",
            .{uptime_sec},
        ) catch continue;
        root.setText(msg.ptr);
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
