//! # I2C Master Bus & Device Wrapper (`i2c`)
//!
//! **What:** Zig-friendly wrapper for the ESP-IDF *new* I2C master driver
//! (v5.x+ `i2c_master_*` API).  Covers bus creation, device registration,
//! data transfer, probing, and event callbacks.
//!
//! **What it does:**
//!   - `BUS.add(cfg, &handle)` — creates a new I2C master bus.
//!   - `BUS.addDevice(bus, dev_cfg, &dev)` — registers a device on the bus.
//!   - `transmit`, `receive`, `transmitReceive` — blocking data transfer with
//!     timeout.
//!   - `probe(bus, addr, timeout)` — checks if a device ACKs at `addr`.
//!   - `registerEventCallbacks` — hooks for DMA done, NACK, etc.
//!   - `BUS.del / removeDevice` — cleanup helpers.
//!
//! **How:** Each function calls the matching `sys.i2c_master_*` C function and
//! converts `esp_err_t` to a Zig error via `espCheckError`.
//!
//! **When to use:** Any sensor, PMIC, touch controller, or EEPROM that speaks
//! I2C.  Prefer this wrapper over the legacy `i2c_driver_*` API.
//!
//! **What it takes:**
//!   - Bus config struct (`i2c_master_bus_config_t`) specifying SDA/SCL pins,
//!     clock speed, and glitch filtering.
//!   - Device config struct (`i2c_device_config_t`) specifying address and
//!     speed.
//!   - Transfer buffers and a timeout in milliseconds.
//!
//! **Example:**
//! ```zig
//! const i2c = idf.i2c;
//! var bus: sys.i2c_master_bus_handle_t = null;
//! try i2c.BUS.add(&.{
//!     .i2c_port = 0,
//!     .sda_io_num = 15,
//!     .scl_io_num = 14,
//!     .clk_source = sys.I2C_CLK_SRC_DEFAULT,
//!     .glitch_ignore_cnt = 7,
//! }, &bus);
//!
//! var dev: sys.i2c_master_dev_handle_t = null;
//! try i2c.BUS.addDevice(bus, &.{
//!     .dev_addr_length = sys.I2C_ADDR_BIT_LEN_7,
//!     .device_address = 0x38,
//!     .scl_speed_hz = 400_000,
//! }, &dev);
//!
//! try i2c.transmit(dev, &[_:0]u8{0x00}, 1, 100);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// I2C master bus lifecycle management.
pub const BUS = struct {
    /// Create a new I2C master bus from the given configuration.
    ///
    /// **Parameters**
    /// - `bus_config`: Pointer to the bus configuration (SDA/SCL pins, clock, glitch filter).
    /// - `ret_bus_handle`: Receives the newly created bus handle on success.
    pub fn add(bus_config: ?*const sys.i2c_master_bus_config_t, ret_bus_handle: [*c]sys.i2c_master_bus_handle_t) !void {
        return try errors.espCheckError(sys.i2c_new_master_bus(bus_config, ret_bus_handle));
    }
    /// Register an I2C device on an existing master bus.
    ///
    /// **Parameters**
    /// - `bus_handle`: The bus to attach the device to.
    /// - `dev_config`: Device configuration (address, speed).
    /// - `ret_handle`: Receives the device handle on success.
    pub fn addDevice(bus_handle: sys.i2c_master_bus_handle_t, dev_config: [*c]const sys.i2c_device_config_t, ret_handle: [*c]sys.i2c_master_dev_handle_t) !void {
        return try errors.espCheckError(sys.i2c_master_bus_add_device(bus_handle, dev_config, ret_handle));
    }
    /// Delete an I2C master bus and release its resources.
    pub fn del(bus_handle: sys.i2c_master_bus_handle_t) !void {
        return try errors.espCheckError(sys.i2c_del_master_bus(bus_handle));
    }
    /// Remove a registered device from the I2C bus.
    pub fn removeDevice(handle: sys.i2c_master_dev_handle_t) !void {
        return try errors.espCheckError(sys.i2c_master_bus_rm_device(handle));
    }
    /// Reset the I2C master bus (recover from bus errors).
    pub fn reset(handle: sys.i2c_master_bus_handle_t) !void {
        return try errors.espCheckError(sys.i2c_master_bus_reset(handle));
    }
};

/// Transmit data to an I2C device (blocking, master write).
///
/// **Parameters**
/// - `i2c_dev`: Device handle obtained from `BUS.addDevice`.
/// - `write_buffer`: Data bytes to send.
/// - `write_size`: Number of bytes to write.
/// - `xfer_timeout_ms`: Transfer timeout in milliseconds (`-1` for default).
pub fn transmit(i2c_dev: sys.i2c_master_dev_handle_t, write_buffer: [*:0]const u8, write_size: usize, xfer_timeout_ms: c_int) !void {
    return try errors.espCheckError(sys.i2c_master_transmit(i2c_dev, write_buffer, write_size, xfer_timeout_ms));
}

/// Transmit then receive data in a single I2C transaction (write-read).
///
/// Performs a repeated-start between the write and read phases.
pub fn transmitReceive(i2c_dev: sys.i2c_master_dev_handle_t, write_buffer: [*:0]const u8, write_size: usize, read_buffer: [*:0]u8, read_size: usize, xfer_timeout_ms: c_int) !void {
    return try errors.espCheckError(sys.i2c_master_transmit_receive(i2c_dev, write_buffer, write_size, read_buffer, read_size, xfer_timeout_ms));
}

/// Receive data from an I2C device (blocking, master read).
pub fn receive(i2c_dev: sys.i2c_master_dev_handle_t, read_buffer: [*:0]u8, read_size: usize, xfer_timeout_ms: c_int) !void {
    return try errors.espCheckError(sys.i2c_master_receive(i2c_dev, read_buffer, read_size, xfer_timeout_ms));
}

/// Probe the I2C bus for a device at the given 7-bit address.
///
/// Returns success if the device ACKs; returns an error otherwise.
pub fn probe(i2c_master: sys.i2c_master_bus_handle_t, address: u16, xfer_timeout_ms: c_int) !void {
    return try errors.espCheckError(sys.i2c_master_probe(i2c_master, address, xfer_timeout_ms));
}

/// Register event callbacks (e.g. DMA done, NACK) for an I2C device.
pub fn registerEventCallbacks(i2c_dev: sys.i2c_master_dev_handle_t, cbs: [*c]const sys.i2c_master_event_callbacks_t, user_data: ?*anyopaque) !void {
    return try errors.espCheckError(sys.i2c_master_register_event_callbacks(i2c_dev, cbs, user_data));
}

/// Wait for all queued I2C transactions to complete.
pub fn waitAllDone(i2c_master: sys.i2c_master_bus_handle_t, timeout_ms: c_int) !void {
    return try errors.espCheckError(sys.i2c_master_wait_all_done(i2c_master, timeout_ms));
}
