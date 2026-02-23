//! # ESP-IDF Logging Backend (`log`)
//!
//! **What:** A drop-in backend for `std.log` that routes Zig log messages through
//! the ESP-IDF `esp_log_write()` infrastructure with ANSI colour output.
//!
//! **What it does:**
//!   - `espLogFn` is a `std.log.LogFn` compatible function.  It converts the Zig
//!     log level (`err`, `warn`, `info`, `debug`) to the corresponding
//!     `ESP_LOG_*` constant, formats the message through `std.fmt`, and calls
//!     `esp_log_write()` so it appears on the UART/JTAG console alongside native
//!     ESP-IDF logs.
//!   - Adds ANSI colour prefixes (red for error, brown/yellow for warn, green
//!     for info, blue for debug) and a reset suffix.
//!
//! **How:** Uses an `ArenaAllocator` over `std.heap.c_allocator` to format each
//! message into a heap buffer, which is freed immediately after `esp_log_write`.
//! Compile-time `levelToEsp` and `levelColor` conversions are zero-cost.
//!
//! **When to use:** Set this as your `logFn` in the root source file:
//! ```zig
//! pub const std_options: std.Options = .{
//!     .logFn = idf.log.espLogFn,
//! };
//! ```
//!
//! **What it takes:** No explicit arguments — `std.log.info("hello", .{})` just
//! works once `logFn` is wired.
//!
//! **Example:**
//! ```zig
//! const std = @import("std");
//! const idf = @import("esp_idf");
//!
//! pub const std_options: std.Options = .{ .logFn = idf.log.espLogFn };
//!
//! pub fn app_main() void {
//!     std.log.info("System booted, IDF version {s}", .{idf.ver.Version.get().toString(alloc)});
//!     // Output: [32m[info] (root): System booted, IDF version v5.4.0[0m
//! }
//! ```

const std = @import("std");
const sys = @import("sys");

/// Default log scope tag used when none is specified.
pub const default_log_scope = .espressif;

/// `std.log`-compatible log function that routes messages through ESP-IDF
/// `esp_log_write()` with ANSI colour output.
///
/// Assign this to `std_options.logFn` in your root source file to use it.
pub fn espLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const esp_level = comptime levelToEsp(level);
    const color = comptime levelColor(level);
    const prefix = color ++ "[" ++ comptime level.asText() ++ "] (" ++ @tagName(scope) ++ "): ";

    var heap = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer heap.deinit();

    ESP_LOG(heap.allocator(), esp_level, "logging", prefix ++ format ++ LOG_RESET_COLOR ++ "\n", args);
}

// ---------------------------------------------------------------------------
// Level mapping
// ---------------------------------------------------------------------------

/// Default log verbosity level, chosen by Zig build mode:
///   - `Debug` → `ESP_LOG_DEBUG`
///   - `ReleaseSafe` → `ESP_LOG_INFO`
///   - `ReleaseFast`/`ReleaseSmall` → `ESP_LOG_ERROR`
pub const default_level: sys.esp_log_level_t = switch (@import("builtin").mode) {
    .Debug => sys.ESP_LOG_DEBUG,
    .ReleaseSafe => sys.ESP_LOG_INFO,
    .ReleaseFast, .ReleaseSmall => sys.ESP_LOG_ERROR,
};

/// Converts a Zig log level to its ESP-IDF equivalent.
pub fn levelToEsp(comptime level: std.log.Level) sys.esp_log_level_t {
    return switch (level) {
        .err => sys.ESP_LOG_ERROR,
        .warn => sys.ESP_LOG_WARN,
        .info => sys.ESP_LOG_INFO,
        .debug => sys.ESP_LOG_DEBUG,
    };
}

/// Returns the ANSI color escape for a given Zig log level.
pub fn levelColor(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .err => LOG_COLOR_E,
        .warn => LOG_COLOR_W,
        .info => LOG_COLOR_I,
        .debug => LOG_COLOR(LOG_COLOR_BLUE),
    };
}

// ---------------------------------------------------------------------------
// Core log primitive
// ---------------------------------------------------------------------------

/// Low-level formatted log output through `esp_log_write()`.
///
/// Combines `std.fmt.allocPrint` formatting with ESP-IDF's logging
/// infrastructure. Prefers `comptimePrint` when args are comptime-known.
pub fn ESP_LOG(
    allocator: std.mem.Allocator,
    level: sys.esp_log_level_t,
    comptime tag: [*:0]const u8,
    comptime fmt: []const u8,
    args: anytype,
) void {
    const buffer: []const u8 = if (isComptime(args))
        std.fmt.comptimePrint(fmt, args)
    else
        std.fmt.allocPrint(allocator, fmt, args) catch return;

    sys.esp_log_write(level, tag, "%.*s", @as(c_int, @intCast(buffer.len)), buffer.ptr);
}

// ---------------------------------------------------------------------------
// ANSI color helpers
// ---------------------------------------------------------------------------

/// ANSI colour code constants for terminal output.
pub const LOG_COLOR_BLACK = "30";
pub const LOG_COLOR_RED = "31";
pub const LOG_COLOR_GREEN = "32";
pub const LOG_COLOR_BROWN = "33";
pub const LOG_COLOR_BLUE = "34";
pub const LOG_COLOR_PURPLE = "35";
pub const LOG_COLOR_CYAN = "36";

/// Wrap an ANSI colour code in a normal-weight escape sequence.
pub inline fn LOG_COLOR(comptime COLOR: []const u8) []const u8 {
    return "\x1b[0;" ++ COLOR ++ "m";
}
/// Wrap an ANSI colour code in a bold escape sequence.
pub inline fn LOG_BOLD(comptime COLOR: []const u8) []const u8 {
    return "\x1b[1;" ++ COLOR ++ "m";
}

/// ANSI reset sequence to clear colour/weight.
pub const LOG_RESET_COLOR = "\x1b[0m";
/// Shorthand: error-level colour (red).
pub const LOG_COLOR_E = LOG_COLOR(LOG_COLOR_RED);
/// Shorthand: warning-level colour (brown/yellow).
pub const LOG_COLOR_W = LOG_COLOR(LOG_COLOR_BROWN);
/// Shorthand: info-level colour (green).
pub const LOG_COLOR_I = LOG_COLOR(LOG_COLOR_GREEN);

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

inline fn isComptime(val: anytype) bool {
    return @typeInfo(@TypeOf(.{val})).@"struct".fields[0].is_comptime;
}
