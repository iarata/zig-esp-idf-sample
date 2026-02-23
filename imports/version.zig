//! # ESP-IDF Version Helper (`ver`)
//!
//! **What:** Parses the IDF version string returned by `esp_get_idf_version()`
//! into structured `major`, `minor`, `patch` fields and can format it back.
//!
//! **What it does:**
//!   - `Version.get()` reads the C version string (e.g. `"v5.4.0-dirty"`),
//!     strips the leading `v` and any `-<suffix>`, then tokenizes on `.`
//!     to fill `major`, `minor`, `patch`.
//!   - `Version.toString(alloc)` formats the struct back into `"v5.4.0"`.
//!
//! **How:** Pure string parsing at runtime — no syscalls beyond the initial
//! `esp_get_idf_version()`.
//!
//! **When to use:** Feature-gating behaviour by IDF version at runtime, or
//! printing version information in boot logs.
//!
//! **What it takes:**
//!   - `get()`: no arguments.
//!   - `toString()`: a `std.mem.Allocator` for the formatted string.
//!
//! **Example:**
//! ```zig
//! const ver = idf.ver.Version.get();
//! std.log.info("ESP-IDF {s}", .{ver.toString(allocator)});
//! ```

const std = @import("std");

/// Parsed ESP-IDF version with structured `major`, `minor`, `patch` fields.
///
/// Use `get()` to read the version at runtime, or `toString()` to format
/// it as a human-readable `"vX.Y.Z"` string.
pub const Version = struct {
    /// Major version component (e.g. `5` for IDF v5.4.0).
    major: ?u32 = 0,
    /// Minor version component.
    minor: ?u32 = 0,
    /// Patch version component.
    patch: ?u32 = 0,

    /// Read the IDF version string from the firmware and parse it into fields.
    ///
    /// Handles strings like `"v5.4.0-dirty"` — strips the `v` prefix and
    /// any `-<suffix>` before splitting on `.`.
    pub fn get() Version {
        var final_version: Version = .{};
        const idf_version = std.mem.span(@import("sys").esp_get_idf_version());

        if (!std.mem.startsWith(u8, idf_version, "v"))
            return final_version;

        var strip = std.mem.splitScalar(u8, idf_version, '-');
        var it = std.mem.tokenizeScalar(u8, strip.first(), '.');

        while (it.next()) |token| {
            // skip [0] == 'v'
            const digit = if (std.mem.startsWith(u8, token, "v"))
                std.fmt.parseUnsigned(u32, token[1..], 10) catch |err|
                    @panic(@errorName(err))
            else
                std.fmt.parseUnsigned(u32, token, 10) catch |err|
                    @panic(@errorName(err));

            if (final_version.major == 0) {
                final_version.major = digit;
            } else if (final_version.minor == 0) {
                final_version.minor = digit;
            } else if (final_version.patch == 0) {
                final_version.patch = digit;
            }
        }

        return final_version;
    }

    /// Format the version as `"vMAJOR.MINOR.PATCH"` (e.g. `"v5.4.0"`).
    ///
    /// Falls back to the raw IDF version string when it does not start
    /// with `"v"`.
    pub fn toString(self: Version, allocator: std.mem.Allocator) []const u8 {
        const idf_version = std.mem.span(@import("sys").esp_get_idf_version());

        // e.g.: v4.0.0 or commit-hash: g5d5f5c3
        if (!std.mem.startsWith(u8, idf_version, "v"))
            return idf_version
        else
            return std.fmt.allocPrint(allocator, "v{d}.{d}.{d}", .{
                self.major.?,
                self.minor.?,
                self.patch.?,
            }) catch |err|
                @panic(@errorName(err));
    }
};
