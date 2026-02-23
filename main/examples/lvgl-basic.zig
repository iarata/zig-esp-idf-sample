//! # Minimal LVGL Example (`lvgl-basic.zig`)
//!
//! **What:** The smallest possible LVGL program — initialises the LVGL port,
//! creates a label widget, and enters an idle loop.  No display or touch
//! hardware is configured, so the label exists only in LVGL’s internal state.
//!
//! **What it does:**
//!   1. Calls `lvgl.initPortDefault()` to start the LVGL timer task and
//!      allocate the display buffer.
//!   2. Acquires the LVGL mutex, gets the active screen, and creates a label
//!      with the text “Hello from Zig + LVGL”.
//!   3. Sleeps forever in a 1 s loop.
//!
//! **How:** Build and flash with:
//! ```sh
//! zig build -Dapp_source=main/examples/lvgl-basic.zig
//! idf.py flash monitor
//! ```
//!
//! **When to use:** To verify the LVGL port compiles and links before adding
//! a display driver, or as a minimal template for headless LVGL unit tests.
//!
//! **What it takes:** No external hardware.  Only `esp_lvgl_port` and LVGL
//! components.

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const lvgl = idf.lvgl;

const log = std.log.scoped(.lvgl);

comptime {
    @export(&main, .{ .name = "app_main" });
}

/// Keeps startup failures explicit because LVGL misuse after partial init can
/// fail later in less actionable ways.
fn check(result: anyerror!void, comptime context: []const u8) void {
    result catch |check_err| {
        log.err("{s} failed: {s}", .{ context, @errorName(check_err) });
        @panic(context);
    };
}

/// Demonstrates the minimum lock discipline required for LVGL object mutation
/// from application code.
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
