//! # FreeRTOS Tick Period Patch
//!
//! Provides the `portTICK_PERIOD_MS` constant that converts between ticks
//! and milliseconds. Patched because the original C macro cannot be
//! translated automatically by the Zig C-import machinery.

/// Number of milliseconds per FreeRTOS tick. Used to convert time durations
/// to tick counts: `ticks = ms / portTICK_PERIOD_MS`.
pub const portTICK_PERIOD_MS: TickType_t =
    @as(TickType_t, @divExact(@as(c_int, 1000), configTICK_RATE_HZ));
