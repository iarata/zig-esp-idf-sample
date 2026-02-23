//! # FreeRTOS xPortCanYield Patch
//!
//! Provides the `xPortCanYield()` function that checks whether the
//! current execution context can yield to the scheduler. This is a
//! hardware-specific register read that cannot be auto-translated from C.

/// Check if the current execution context is outside a critical section
/// and can safely yield to the FreeRTOS scheduler.
pub fn xPortCanYield() callconv(.c) bool {
    // Reads FreeRTOS critical-section threshold register and returns yield eligibility.
    var threshold: u32 = blk: {
        break :blk @as([*c]volatile u32, @ptrFromInt(@as(c_int, 545259520) + @as(c_int, 8))).*;
    };
    _ = &threshold;
    threshold = threshold >> @intCast(@as(c_int, 24) + (@as(c_int, 8) - @as(c_int, 3)));
    return threshold == @as(u32, @bitCast(@as(c_int, 0)));
}
