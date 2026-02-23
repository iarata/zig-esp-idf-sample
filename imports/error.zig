//! # ESP-IDF Error Conversion Helpers (`error`)
//!
//! **What:** A bidirectional bridge between C `esp_err_t` integer codes and Zig's
//! compile-time error union system.
//!
//! **What it does:**
//!   - `espError(err)` converts a raw `esp_err_t` into a Zig `esp_error` if the
//!     code is known, or returns the original integer for unmapped codes.
//!   - `espCheckError(err)` is the primary call-site helper: returns `void` on
//!     `ESP_OK`, or propagates the mapped Zig error with `try`.
//!
//! **How:** A `switch` statement maps every standard ESP-IDF error constant
//! (`ESP_ERR_NO_MEM`, `ESP_ERR_TIMEOUT`, etc.) into a corresponding Zig error
//! tag.  Unknown non-OK values fall through to `esp_error.Fail`.
//!
//! **When to use:** Wrap every raw `sys.*` function that returns `esp_err_t`.
//! Most wrapper modules in this project already do this internally.
//!
//! **What it takes:**
//!   - **Input:** an `esp_err_t` value (i32).
//!   - **Returns:** `void` on success, or a Zig error (`esp_error!void`).
//!
//! **Example:**
//! ```zig
//! const errors = @import("error");
//! // Wrap a raw C call:
//! try errors.espCheckError(sys.gpio_set_level(pin, 1));
//! // Or inspect the error:
//! errors.espError(sys.some_call()) catch |e| {
//!     log.err("call failed: {s}", .{@errorName(e)});
//! };
//! ```

const sys = @import("sys");
const std = @import("std");

/// Zig error set mirroring all standard ESP-IDF `esp_err_t` error codes.
///
/// Each variant maps 1:1 to an `ESP_ERR_*` constant from `esp_err.h`.
/// `Fail` is the catch-all for `ESP_FAIL` and any unmapped non-OK values.
const esp_error = error{
    Fail,
    ErrorNoMem,
    ErrorInvalidArg,
    ErrorInvalidState,
    ErrorInvalidSize,
    ErrorNotFound,
    ErrorNotSupported,
    ErrorTimeout,
    ErrorInvalidResponse,
    ErrorInvalidCRC,
    ErrorInvalidVersion,
    ErrorInvalidMAC,
    ErrorNotFinished,
    ErrorNotAllowed,
    ErrorWiFiBase,
    ErrorMeshBase,
    ErrorFlashBase,
    ErrorHWCryptoBase,
    ErrorMemProtectBase,
};

/// Convert a raw `esp_err_t` into a Zig error or pass through the original code.
///
/// Returns a Zig error from the `esp_error` set if the code is a known
/// non-OK value.  Returns the original `esp_err_t` integer for unknown
/// codes (including `ESP_OK`).
///
/// **Parameters**
/// - `err`: The raw `esp_err_t` value returned by an ESP-IDF C function.
///
/// **Returns:** An error from `esp_error` on failure, or the raw code on success.
pub fn espError(err: sys.esp_err_t) esp_error!sys.esp_err_t {
    return switch (@as(sys.esp_err_t, err)) {
        @as(sys.esp_err_t, sys.ESP_FAIL) => esp_error.Fail,
        @as(sys.esp_err_t, sys.ESP_ERR_NO_MEM) => esp_error.ErrorNoMem,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_ARG) => esp_error.ErrorInvalidArg,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_STATE) => esp_error.ErrorInvalidState,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_SIZE) => esp_error.ErrorInvalidSize,
        @as(sys.esp_err_t, sys.ESP_ERR_NOT_FOUND) => esp_error.ErrorNotFound,
        @as(sys.esp_err_t, sys.ESP_ERR_NOT_SUPPORTED) => esp_error.ErrorNotSupported,
        @as(sys.esp_err_t, sys.ESP_ERR_TIMEOUT) => esp_error.ErrorTimeout,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_RESPONSE) => esp_error.ErrorInvalidResponse,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_CRC) => esp_error.ErrorInvalidCRC,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_VERSION) => esp_error.ErrorInvalidVersion,
        @as(sys.esp_err_t, sys.ESP_ERR_INVALID_MAC) => esp_error.ErrorInvalidMAC,
        @as(sys.esp_err_t, sys.ESP_ERR_NOT_FINISHED) => esp_error.ErrorNotFinished,
        @as(sys.esp_err_t, sys.ESP_ERR_NOT_ALLOWED) => esp_error.ErrorNotAllowed,
        @as(sys.esp_err_t, sys.ESP_ERR_WIFI_BASE) => esp_error.ErrorWiFiBase,
        @as(sys.esp_err_t, sys.ESP_ERR_MESH_BASE) => esp_error.ErrorMeshBase,
        @as(sys.esp_err_t, sys.ESP_ERR_FLASH_BASE) => esp_error.ErrorFlashBase,
        @as(sys.esp_err_t, sys.ESP_ERR_HW_CRYPTO_BASE) => esp_error.ErrorHWCryptoBase,
        @as(sys.esp_err_t, sys.ESP_ERR_MEMPROT_BASE) => esp_error.ErrorMemProtectBase,
        else => err, // Return the original `sys.esp_err_t` if it's not mapped
    };
}

/// Check an `esp_err_t` and propagate as a Zig error on failure.
///
/// Returns `void` when `errc == ESP_OK`.  For any other value, maps the
/// code to a Zig error via `espError` and returns it using `try`.
/// This is the primary helper used by all wrapper modules to bridge
/// C error codes into Zig's error-union system.
///
/// **Parameters**
/// - `errc`: The raw `esp_err_t` value to check.
///
/// **Returns:** `void` on success, or an `esp_error` on failure.
pub fn espCheckError(errc: sys.esp_err_t) esp_error!void {
    if (errc == @as(sys.esp_err_t, sys.ESP_OK))
        return;

    // Preserve detailed mapped errors, but also fail on unmapped non-OK values.
    _ = try espError(errc);
    return esp_error.Fail;
}
