//! # Integrated LVGL Display + Touch Example (`lvgl-integrated-display.zig`)
//!
//! **What:** A full-board GUI example that uses the `display_touch` library
//! for one-call hardware init and the `app_ui` helpers for UI composition.
//! Updates an on-screen label with the running uptime every second.
//!
//! **What it does:**
//!   1. Calls `display_touch.initDefault()` — PMU, QSPI display, touch.
//!   2. Mounts a centred label via `ui.mount(...)` inside an LVGL lock.
//!   3. In a 1 s loop: acquires the LVGL lock, formats an uptime string, and
//!      calls `root.setText(...)` to update the label.
//!
//! **How:** Build and flash with:
//! ```sh
//! zig build -Dapp_source=main/examples/lvgl-integrated-display.zig
//! idf.py flash monitor
//! ```
//!
//! **When to use:** As the recommended starting template for GUI applications
//! on the Waveshare AMOLED board.  It separates hardware init from UI logic
//! so either can be swapped independently.
//!
//! **What it takes:**
//!   - Waveshare ESP32-S3 1.8″ AMOLED board.
//!   - Components: `esp_lvgl_port`, LVGL, SH8601 driver, FT5x06 driver,
//!     AXP2101 PMU driver.

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const display_touch = @import("display_touch");
const ui = @import("app_ui");

const lvgl = display_touch.lvgl;
const log = std.log.scoped(.lvgl_integrated);

comptime {
    @export(&main, .{ .name = "app_main" });
}

/// Shows the "happy path" integration where board bring-up and UI composition
/// stay separate, making it easier to swap UI without touching hardware init.
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
