//! # SPI Master & SDSPI Wrapper (`spi`)
//!
//! **What:** Zig wrapper around ESP-IDF SPI master driver and the SD-over-SPI
//! host helper.  Covers bus init/deinit, device add/remove, queued and
//! polling transfers, bus acquisition, and timing helpers.
//!
//! **What it does:**
//!   - `busInitialize` / `busFree` — set up or tear down an SPI host with DMA.
//!   - `busAddDevice` / `busRemoveDevice` — attach or detach a device with CS,
//!     clock polarity, and queue depth.
//!   - `deviceTransmit` — blocking full-duplex SPI transaction.
//!   - `deviceQueueTrans` / `deviceGetTransResult` — async queued transfers.
//!   - `devicePollingTransmit` — low-latency polling transfer.
//!   - `deviceAcquireBus` / `deviceReleaseBus` — exclusive bus ownership for
//!     back-to-back transactions without re-arbitration.
//!   - `SDSPI.Host.*` — SD card host over SPI (init, transaction, clock set).
//!   - Timing helpers (`getActualClock`, `getTiming`, `getFreqLimit`).
//!
//! **How:** Thin wrappers that forward to `sys.spi_*` / `sys.sdspi_*` and
//! convert `esp_err_t` → Zig error.
//!
//! **When to use:** LCD displays (SH8601, ILI9341), external flash, SD cards,
//! sensor ICs, or any SPI peripheral.
//!
//! **What it takes:**
//!   - `spi_bus_config_t` with MOSI/MISO/SCLK pin numbers and DMA channel.
//!   - `spi_device_interface_config_t` per attached device.
//!   - `spi_transaction_t` per transfer.
//!
//! **Example:**
//! ```zig
//! const spi = idf.spi;
//! try spi.busInitialize(sys.SPI2_HOST, &bus_cfg, sys.SPI_DMA_CH_AUTO);
//! var dev: sys.spi_device_handle_t = null;
//! try spi.busAddDevice(sys.SPI2_HOST, &dev_cfg, &dev);
//! try spi.deviceTransmit(dev, &txn);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// Initialise an SPI bus with the given DMA channel.
pub fn busInitialize(host_id: sys.spi_host_device_t, bus_config: [*c]const sys.spi_bus_config_t, dma_chan: sys.spi_dma_chan_t) !void {
    return try errors.espCheckError(sys.spi_bus_initialize(host_id, bus_config, dma_chan));
}
/// Free an SPI bus and its DMA resources.
pub fn busFree(host_id: sys.spi_host_device_t) !void {
    return try errors.espCheckError(sys.spi_bus_free(host_id));
}
/// Attach a device to an SPI bus with the given interface configuration.
pub fn busAddDevice(host_id: sys.spi_host_device_t, dev_config: [*c]const sys.spi_device_interface_config_t, handle: [*c]sys.spi_device_handle_t) !void {
    return try errors.espCheckError(sys.spi_bus_add_device(host_id, dev_config, handle));
}
/// Remove a device from the SPI bus.
pub fn busRemoveDevice(handle: sys.spi_device_handle_t) !void {
    return try errors.espCheckError(sys.spi_bus_remove_device(handle));
}
/// Queue an asynchronous SPI transaction.
pub fn deviceQueueTrans(handle: sys.spi_device_handle_t, trans_desc: [*c]sys.spi_transaction_t, ticks_to_wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.spi_device_queue_trans(handle, trans_desc, ticks_to_wait));
}
/// Retrieve the result of a previously queued transaction.
pub fn deviceGetTransResult(handle: sys.spi_device_handle_t, trans_desc: [*c][*c]sys.spi_transaction_t, ticks_to_wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.spi_device_get_trans_result(handle, trans_desc, ticks_to_wait));
}
/// Execute a blocking full-duplex SPI transaction.
pub fn deviceTransmit(handle: sys.spi_device_handle_t, trans_desc: [*c]sys.spi_transaction_t) !void {
    return try errors.espCheckError(sys.spi_device_transmit(handle, trans_desc));
}
/// Begin a polling-mode SPI transaction (non-blocking start).
pub fn devicePollingStart(handle: sys.spi_device_handle_t, trans_desc: [*c]sys.spi_transaction_t, ticks_to_wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.spi_device_polling_start(handle, trans_desc, ticks_to_wait));
}
/// Wait for a polling-mode SPI transaction to complete.
pub fn devicePollingEnd(handle: sys.spi_device_handle_t, ticks_to_wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.spi_device_polling_end(handle, ticks_to_wait));
}
/// Execute a low-latency polling SPI transaction (blocking).
pub fn devicePollingTransmit(handle: sys.spi_device_handle_t, trans_desc: [*c]sys.spi_transaction_t) !void {
    return try errors.espCheckError(sys.spi_device_polling_transmit(handle, trans_desc));
}
/// Acquire exclusive bus ownership for back-to-back transactions.
pub fn deviceAcquireBus(device: sys.spi_device_handle_t, wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.spi_device_acquire_bus(device, wait));
}
/// Release exclusive bus ownership.
pub fn deviceReleaseBus(dev: sys.spi_device_handle_t) void {
    sys.spi_device_release_bus(dev);
}
/// Query the actual negotiated clock frequency of a device (kHz).
pub fn deviceGetActualFreq(handle: sys.spi_device_handle_t, freq_khz: [*c]c_int) !void {
    return try errors.espCheckError(sys.spi_device_get_actual_freq(handle, freq_khz));
}
/// Calculate the actual SPI clock given APB frequency, desired Hz, and duty cycle.
pub fn getActualClock(fapb: c_int, hz: c_int, duty_cycle: c_int) c_int {
    return sys.spi_get_actual_clock(fapb, hz, duty_cycle);
}
/// Get the timing parameters (dummy bits, remaining cycles) for a clock/delay.
pub fn getTiming(gpio_is_used: bool, input_delay_ns: c_int, eff_clk: c_int, dummy_o: [*c]c_int, cycles_remain_o: [*c]c_int) void {
    sys.spi_get_timing(gpio_is_used, input_delay_ns, eff_clk, dummy_o, cycles_remain_o);
}
/// Get the maximum SPI clock frequency for the given GPIO/delay conditions.
pub fn getFreqLimit(gpio_is_used: bool, input_delay_ns: c_int) c_int {
    return sys.spi_get_freq_limit(gpio_is_used, input_delay_ns);
}
/// Query the maximum transaction length (bytes) for a bus.
pub fn busGetMaxTransactionLen(host_id: sys.spi_host_device_t, max_bytes: [*c]usize) !void {
    return try errors.espCheckError(sys.spi_bus_get_max_transaction_len(host_id, max_bytes));
}

/// SD card host over SPI (SDSPI).
pub const SDSPI = struct {
    /// SDSPI host driver operations.
    pub const Host = struct {
        /// Initialise the SDSPI host driver.
        pub fn init() !void {
            return try errors.espCheckError(sys.sdspi_host_init());
        }
        /// Initialise and attach an SD device over SPI.
        pub fn initDevice(dev_config: [*c]const sys.sdspi_device_config_t, out_handle: [*c]sys.sdspi_dev_handle_t) !void {
            return try errors.espCheckError(sys.sdspi_host_init_device(dev_config, out_handle));
        }
        /// Remove an SDSPI device.
        pub fn removeDevice(handle: sys.sdspi_dev_handle_t) !void {
            return try errors.espCheckError(sys.sdspi_host_remove_device(handle));
        }
        /// Execute an SD/MMC command transaction over SPI.
        pub fn doTransaction(handle: sys.sdspi_dev_handle_t, cmdinfo: [*c]sys.sdmmc_command_t) !void {
            return try errors.espCheckError(sys.sdspi_host_do_transaction(handle, cmdinfo));
        }
        /// Set the SD card clock frequency (kHz).
        pub fn setCardClk(host: sys.sdspi_dev_handle_t, freq_khz: u32) !void {
            return try errors.espCheckError(sys.sdspi_host_set_card_clk(host, freq_khz));
        }
        /// Get the actual negotiated SD clock frequency (kHz).
        pub fn getRealFreq(handle: sys.sdspi_dev_handle_t, real_freq_khz: [*c]c_int) !void {
            return try errors.espCheckError(sys.sdspi_host_get_real_freq(handle, real_freq_khz));
        }
        /// Deinitialise the SDSPI host driver.
        pub fn deinit() !void {
            return try errors.espCheckError(sys.sdspi_host_deinit());
        }
        /// SDIO interrupt helpers.
        pub const IO = struct {
            /// Enable SDIO interrupts for an SDSPI device.
            pub fn intEnable(handle: sys.sdspi_dev_handle_t) !void {
                return try errors.espCheckError(sys.sdspi_host_io_int_enable(handle));
            }
            /// Wait for an SDIO interrupt with a tick timeout.
            pub fn intWait(handle: sys.sdspi_dev_handle_t, timeout_ticks: sys.TickType_t) !void {
                return try errors.espCheckError(sys.sdspi_host_io_int_wait(handle, timeout_ticks));
            }
        };
    };
};
