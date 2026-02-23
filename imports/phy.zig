//! # PHY & RF Test Wrappers (`phy`)
//!
//! **What:** Low-level helpers for the ESP-IDF PHY (physical-layer) radio
//! test mode.  Provides direct TX/RX control of Wi-Fi, BLE, and Classic BT
//! radios for manufacturing tests and RF certification.
//!
//! **What it does:**
//!   - `RF.config(conf)` / `RF.init()` — configure and initialise the RF test
//!     subsystem.
//!   - `txContinEn(en)` — enable/disable continuous TX (carrier wave).
//!   - `cbw40mEn(en)` — enable 40 MHz channel bandwidth.
//!   - `testStartStop(value)` — start or stop a test sequence.
//!   - `WIFI.tx(chan, rate, backoff, ...)` / `WIFI.rx(chan, rate)` — Wi-Fi
//!     TX/RX in test mode.
//!   - `WIFI.txTone(start, chan, backoff)` — single-tone TX.
//!   - `BLE.tx(...)` / `BLE.rx(...)` — BLE test TX/RX with configurable
//!     packet parameters.
//!   - `BT.txTone(start, chan, power)` — Classic BT tone TX.
//!   - `getRXResult(result)` — retrieve received-packet statistics.
//!
//! **How:** Direct calls to `sys.esp_phy_*` functions.  No error conversion —
//! these are fire-and-forget hardware register writes.
//!
//! **When to use:** Factory test firmware, RF compliance testing, antenna
//! characterisation.  **Not for normal application traffic.**
//!
//! **What it takes:** Channel number, PHY rate enum, power backoff, etc.
//!
//! **Example:**
//! ```zig
//! const phy = idf.phy;
//! phy.RF.init();
//! phy.WIFI.tx(6, sys.PHY_RATE_11M, -2, 1000, 100, 100);
//! var result: sys.esp_phy_rx_result_t = undefined;
//! phy.getRXResult(&result);
//! ```

const sys = @import("sys");

/// RF test subsystem configuration and initialisation.
pub const RF = struct {
    /// Apply RF test configuration register value.
    pub fn config(conf: u8) void {
        sys.esp_phy_rftest_config(conf);
    }
    /// Initialise the RF test subsystem.
    pub fn init() void {
        sys.esp_phy_rftest_init();
    }
};
/// Enable or disable continuous TX (carrier wave) mode.
pub fn txContinEn(contin_en: bool) void {
    sys.esp_phy_tx_contin_en(contin_en);
}
/// Enable or disable 40 MHz channel bandwidth for testing.
pub fn cbw40mEn(en: bool) void {
    sys.esp_phy_cbw40m_en(en);
}
/// Start (`value` = 1) or stop (`value` = 0) an RF test sequence.
pub fn testStartStop(value: u8) void {
    sys.esp_phy_test_start_stop(value);
}
/// Wi-Fi PHY test-mode TX/RX helpers.
pub const WIFI = struct {
    /// Transmit test packets on the given Wi-Fi channel.
    pub fn tx(chan: u32, rate: sys.esp_phy_wifi_rate_t, backoff: i8, length_byte: u32, packet_delay: u32, packet_num: u32) void {
        sys.esp_phy_wifi_tx(chan, rate, backoff, length_byte, packet_delay, packet_num);
    }
    /// Enter Wi-Fi RX test mode on a channel and rate.
    pub fn rx(chan: u32, rate: sys.esp_phy_wifi_rate_t) void {
        sys.esp_phy_wifi_rx(chan, rate);
    }
    /// Transmit a single-tone carrier on a Wi-Fi channel.
    pub fn txTone(start: u32, chan: u32, backoff: u32) void {
        sys.esp_phy_wifi_tx_tone(start, chan, backoff);
    }
};
/// BLE PHY test-mode TX/RX helpers.
pub const BLE = struct {
    /// Transmit BLE test packets.
    pub fn tx(txpwr: u32, chan: u32, len: u32, data_type: sys.esp_phy_ble_type_t, syncw: u32, rate: sys.esp_phy_ble_rate_t, tx_num_in: u32) void {
        sys.esp_phy_ble_tx(txpwr, chan, len, data_type, syncw, rate, tx_num_in);
    }
    /// Enter BLE RX test mode on a channel.
    pub fn rx(chan: u32, syncw: u32, rate: sys.esp_phy_ble_rate_t) void {
        sys.esp_phy_ble_rx(chan, syncw, rate);
    }
};
/// Classic Bluetooth PHY test helper.
pub const BT = struct {
    /// Transmit a BT tone on a channel with the given power.
    pub fn txTone(start: u32, chan: u32, power: u32) void {
        sys.esp_phy_bt_tx_tone(start, chan, power);
    }
};
/// Retrieve accumulated RX test results (packet count, error rate, etc.).
pub fn getRXResult(rx_result: [*c]sys.esp_phy_rx_result_t) void {
    sys.esp_phy_get_rx_result(rx_result);
}
