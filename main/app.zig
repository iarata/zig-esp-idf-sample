//! # Application Entry Point (`main/app.zig`)
//!
//! **What:** The default Zig application entry file for this ESP32-S3 project.
//! Exports the `app_main` symbol that ESP-IDF's startup code calls after
//! FreeRTOS and peripheral initialisation are complete.
//!
//! **What it does:**
//!   1. Initialises the integrated AMOLED display (and optionally touch) via
//!      the `display_touch` library.
//!   2. Acquires the LVGL lock and mounts a simple UI (a centred label with
//!      the text "Runa") using the `app_ui` library.
//!   3. Enters an infinite loop that sleeps 1 s per iteration (placeholder
//!      for periodic update logic).
//!
//! **How:**
//!   - `comptime { @export(&main, .{ .name = "app_main" }); }` makes the
//!     function visible to the C linker as `app_main`.
//!   - `display_touch.init(.{})` handles the full bring-up sequence: PMU
//!     rails → SPI bus → SH8601 display → FT5x06 touch (with retry/fallback).
//!   - The LVGL lock/unlock bracket ensures thread safety with the LVGL
//!     timer task.
//!   - `pub const panic` and `pub const std_options` wire the ESP-IDF panic
//!     handler and logger so that `@panic`, `std.log.info`, etc. output to
//!     the UART console.
//!
//! **When to modify:** Replace the UI mount and loop body with your own
//! application logic.  Or use a different example file via
//! `zig build -Dapp_source=main/examples/wifi-station.zig`.
//!
//! **Example — minimal app_main:**
//! ```zig
//! const idf = @import("esp_idf");
//! comptime { @export(&main, .{ .name = "app_main" }); }
//! fn main() callconv(.c) void {
//!     idf.rtos.Task.delayMs(1000);
//!     std.log.info("Hello from Zig on ESP32-S3!", .{});
//! }
//! pub const panic = idf.esp_panic.panic;
//! pub const std_options: std.Options = .{ .logFn = idf.log.espLogFn };
//! ```

const std = @import("std");
const builtin = @import("builtin");
const idf = @import("esp_idf");
const display_touch = @import("display_touch");
const ui = @import("app_ui");

const lvgl = display_touch.lvgl;
const log = std.log.scoped(.app);

comptime {
    @export(&main, .{ .name = "app_main" });
}

/// Keeps app-level logic focused on UI state by delegating all board bring-up
/// to `display_touch`, then running a simple locked LVGL update loop.
fn main() callconv(.c) void {
    // Centralizing bring-up avoids duplicated pin/timing assumptions in apps.
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
    const root = blk: {
        defer lvgl.unlock();
        break :blk ui.mount(.{
            .text = "Runa",
            .runa_style = true,
        }) orelse @panic("ui.mount");
    };

    _ = root;
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
