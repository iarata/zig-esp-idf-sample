//! # Application Entry Point (`main/app.zig`)
//!
//! Minimal, expandable template for ESP32-S3 Zig applications.
//! Exports the `app_main` symbol that ESP-IDF calls after FreeRTOS init.
//!
//! ## Structure
//!
//!   - **`app_init`** — one-time setup (peripherals, drivers, state).
//!   - **`app_run`**  — main loop / event-driven logic.
//!
//! Each section is clearly separated so new functionality can be added
//! without touching boilerplate.  For a display/touch/LVGL starting
//! point, see `main/examples/lvgl-integrated-display.zig`.
//!
//! ## Selecting a different entry file
//!
//! ```sh
//! zig build -Dapp_source=main/examples/wifi-station.zig
//! ```

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");

const log = std.log.scoped(.app);

// ── Entry Point ─────────────────────────────────────────────────────────────

comptime {
    @export(&main, .{ .name = "app_main" });
}

fn main() callconv(.c) void {
    app_init() catch |err| {
        log.err("init failed: {s}", .{@errorName(err)});
        @panic("app_init");
    };
    app_run();
}

// ── Initialization ──────────────────────────────────────────────────────────
// Add hardware / peripheral / driver setup here.
// This function is called once before the main loop starts.

fn app_init() !void {
    log.info("app started", .{});

    // Example: bring up display + touch (uncomment and add imports above):
    //
    //   const display_touch = @import("display_touch");
    //   _ = try display_touch.init(.{});
}

// ── Main Loop ───────────────────────────────────────────────────────────────
// Add periodic or event-driven application logic here.

fn app_run() noreturn {
    var loop_count: u32 = 0;

    while (true) : (loop_count += 1) {
        // Replace with your application logic.
        if (loop_count % 10 == 0) {
            log.info("heartbeat — loop {d}", .{loop_count});
        }

        idf.rtos.Task.delayMs(1000);
    }
}

// ── Runtime Configuration ───────────────────────────────────────────────────

pub const panic = idf.esp_panic.panic;
pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
    .logFn = idf.log.espLogFn,
};
