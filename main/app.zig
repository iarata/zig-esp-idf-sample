const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const display_touch = @import("lib/display_touch.zig");
const ui = @import("lib/ui.zig");

const lvgl = display_touch.lvgl;
const log = std.log.scoped(.app);

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn main() callconv(.c) void {
    // One-call board bring-up (LVGL port + SH8601 display + optional FT5x06 touch).
    const integrated = display_touch.init(.{
        .touch = .{
            .required = false,
        },
    }) catch |err| {
        log.err("display_touch.init failed: {s}", .{@errorName(err)});
        @panic("display_touch.init");
    };

    if (!integrated.hasTouch()) {
        log.warn("Touch unavailable, running display-only", .{});
    }

    if (!lvgl.lock(0)) @panic("lvgl.lock");
    var root = blk: {
        defer lvgl.unlock();
        break :blk ui.mount(.{
            .text = "Zig + LVGL\nApp loaded",
        }) orelse @panic("ui.mount");
    };

    const touch_state = if (integrated.hasTouch()) "touch ready" else "display only";
    var uptime_sec: u32 = 0;
    while (true) : (uptime_sec += 1) {
        idf.rtos.Task.delayMs(1000);

        if (!lvgl.lock(100)) continue;
        defer lvgl.unlock();

        var msg_buf: [96]u8 = undefined;
        const msg = std.fmt.bufPrintZ(
            &msg_buf,
            "Zig + LVGL\n{s}\nUptime: {d}s",
            .{ touch_state, uptime_sec },
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
