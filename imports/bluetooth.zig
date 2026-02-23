//! # Bluetooth Power-Domain Wrapper (`bt`)
//!
//! **What:** Minimal helper for controlling the shared Wi-Fi/Bluetooth radio
//! power domain on ESP32 SoCs that have a combined radio.
//!
//! **What it does:**
//!   - `PowerDomain.On()` — enables the shared power domain so the BT
//!     controller can operate.
//!   - `PowerDomain.Off()` — shuts down the shared power domain (both BT
//!     and Wi-Fi must be stopped first).
//!
//! **How:** Calls `sys.esp_wifi_bt_power_domain_on/off()` directly.
//!
//! **When to use:** When you need to explicitly sequence BT and Wi-Fi
//! shared-radio power, e.g. before initialising the BT controller or after
//! tearing down all wireless connections to save power.
//!
//! **What it takes:** No arguments.
//!
//! **Example:**
//! ```zig
//! const bt = idf.bt;
//! bt.PowerDomain.On();
//! // ... init BT controller, start BLE advertising ...
//! bt.PowerDomain.Off();  // after BT is fully stopped
//! ```
//!
//! > **Note:** This module is a stub — full BLE/Classic BT stack wrappers are
//! > planned but not yet implemented.

const sys = @import("sys");

/// Shared Wi-Fi / Bluetooth radio power-domain control.
///
/// On dual-radio SoCs the BT and Wi-Fi controllers share a single power
/// domain.  Use `On()` before initialising the BT controller and `Off()`
/// after all wireless activity has stopped.
pub const PowerDomain = struct {
    /// Enable the shared BT / Wi-Fi power domain.
    ///
    /// Must be called before starting the Bluetooth controller.
    pub fn On() void {
        sys.esp_wifi_bt_power_domain_on();
    }

    /// Disable the shared BT / Wi-Fi power domain.
    ///
    /// Both BT and Wi-Fi must be fully stopped before calling this.
    pub fn Off() void {
        sys.esp_wifi_bt_power_domain_off();
    }
};

// TODO: implement
