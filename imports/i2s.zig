//! # I2S Channel Driver Wrapper (`i2s`)
//!
//! **What:** Zig wrapper for the ESP-IDF I2S *channel-based* driver.  Manages
//! TX/RX channel lifecycle, PDM mode configuration, and streaming I/O.
//!
//! **What it does:**
//!   - `newChannel` / `delChannel` — allocate or release a stereo I2S port
//!     with separate TX and RX handles.
//!   - `channelEnable` / `channelDisable` — start or stop DMA-based streaming.
//!   - `channelWrite` / `channelRead` — blocking data transfer with timeout.
//!   - `channelPreloadData` — pre-fill the DMA buffer before enabling.
//!   - `channelInit*` / `channelReconfig*` — set or change PDM RX/TX mode
//!     parameters (clock, slot layout, GPIO mapping) while the channel is
//!     disabled.
//!   - `channelRegisterEventCallback` — hook into DMA transfer events.
//!
//! **How:** Thin 1:1 wrappers that forward to `sys.i2s_*` and convert
//! `esp_err_t` into Zig errors.
//!
//! **When to use:** Audio playback/recording pipelines, digital microphone
//! ingestion, or any inter-IC sound streaming scenario.
//!
//! **What it takes:**
//!   - `i2s_chan_config_t` for channel creation (port number, role, DMA
//!     configuration).
//!   - Mode-specific configs (`i2s_pdm_rx_config_t`, etc.) for init.
//!   - Buffers and timeout for read/write.
//!
//! **Example:**
//! ```zig
//! const i2s = idf.i2s;
//! var tx: sys.i2s_chan_handle_t = null;
//! var rx: sys.i2s_chan_handle_t = null;
//! try i2s.newChannel(&chan_cfg, &tx, &rx);
//! try i2s.channelEnable(tx);
//! var written: usize = 0;
//! try i2s.channelWrite(tx, samples.ptr, samples.len, &written, 1000);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// Create a new I2S channel pair (TX and/or RX) for the given port.
///
/// Pass `null` for a handle you don't need (e.g. TX-only or RX-only).
pub fn newChannel(chan_cfg: [*c]const sys.i2s_chan_config_t, ret_tx_handle: [*c]sys.i2s_chan_handle_t, ret_rx_handle: [*c]sys.i2s_chan_handle_t) !void {
    return try errors.espCheckError(sys.i2s_new_channel(chan_cfg, ret_tx_handle, ret_rx_handle));
}

/// Delete an I2S channel and release its DMA resources.
pub fn delChannel(handle: sys.i2s_chan_handle_t) !void {
    return try errors.espCheckError(sys.i2s_del_channel(handle));
}

/// Retrieve information about an I2S channel (port, role, direction).
pub fn channelGetInfo(handle: sys.i2s_chan_handle_t, chan_info: [*c]sys.i2s_chan_info_t) !void {
    return try errors.espCheckError(sys.i2s_channel_get_info(handle, chan_info));
}

/// Enable an I2S channel and start DMA-based streaming.
pub fn channelEnable(handle: sys.i2s_chan_handle_t) !void {
    return try errors.espCheckError(sys.i2s_channel_enable(handle));
}

/// Disable an I2S channel and stop DMA streaming.
pub fn channelDisable(handle: sys.i2s_chan_handle_t) !void {
    return try errors.espCheckError(sys.i2s_channel_disable(handle));
}

/// Pre-fill the TX DMA buffer before enabling the channel.
///
/// Useful to avoid an initial silence gap when playback starts.
pub fn channelPreloadData(tx_handle: sys.i2s_chan_handle_t, src: ?*const anyopaque, size: usize, bytes_loaded: [*c]usize) !void {
    return try errors.espCheckError(sys.i2s_channel_preload_data(tx_handle, src, size, bytes_loaded));
}

/// Write audio data to a TX channel (blocking with timeout).
pub fn channelWrite(handle: sys.i2s_chan_handle_t, src: ?*const anyopaque, size: usize, bytes_written: [*c]usize, timeout_ms: u32) !void {
    return try errors.espCheckError(sys.i2s_channel_write(handle, src, size, bytes_written, timeout_ms));
}

/// Read audio data from an RX channel (blocking with timeout).
pub fn channelRead(handle: sys.i2s_chan_handle_t, dest: ?*anyopaque, size: usize, bytes_read: [*c]usize, timeout_ms: u32) !void {
    return try errors.espCheckError(sys.i2s_channel_read(handle, dest, size, bytes_read, timeout_ms));
}

/// Register DMA event callbacks for an I2S channel.
pub fn channelRegisterEventCallback(handle: sys.i2s_chan_handle_t, callbacks: [*c]const sys.i2s_event_callbacks_t, user_data: ?*anyopaque) !void {
    return try errors.espCheckError(sys.i2s_channel_register_event_callback(handle, callbacks, user_data));
}

/// Initialise an I2S channel in PDM RX mode.
pub fn channelInitPdmRXMode(handle: sys.i2s_chan_handle_t, pdm_rx_cfg: ?*const sys.i2s_pdm_rx_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_init_pdm_rx_mode(handle, pdm_rx_cfg));
}

/// Reconfigure PDM RX clock while the channel is disabled.
pub fn channelReconfigPdmRXClock(handle: sys.i2s_chan_handle_t, clk_cfg: [*c]const sys.i2s_pdm_rx_clk_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_rx_clock(handle, clk_cfg));
}

/// Reconfigure PDM RX slot layout while the channel is disabled.
pub fn channelReconfigPdmRXSlot(handle: sys.i2s_chan_handle_t, slot_cfg: [*c]const sys.i2s_pdm_rx_slot_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_rx_slot(handle, slot_cfg));
}

/// Reconfigure PDM RX GPIO mapping while the channel is disabled.
pub fn channelReconfigPdmRXGPIO(handle: sys.i2s_chan_handle_t, gpio_cfg: ?*const sys.i2s_pdm_rx_gpio_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_rx_gpio(handle, gpio_cfg));
}

/// Initialise an I2S channel in PDM TX mode.
pub fn channelInitPdmTXMode(handle: sys.i2s_chan_handle_t, pdm_tx_cfg: ?*const sys.i2s_pdm_tx_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_init_pdm_tx_mode(handle, pdm_tx_cfg));
}

/// Reconfigure PDM TX clock while the channel is disabled.
pub fn channelReconfigPdmTXClock(handle: sys.i2s_chan_handle_t, clk_cfg: [*c]const sys.i2s_pdm_tx_clk_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_tx_clock(handle, clk_cfg));
}

/// Reconfigure PDM TX slot layout while the channel is disabled.
pub fn channelReconfigPdmTXSlot(handle: sys.i2s_chan_handle_t, slot_cfg: [*c]const sys.i2s_pdm_tx_slot_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_tx_slot(handle, slot_cfg));
}

/// Reconfigure PDM TX GPIO mapping while the channel is disabled.
pub fn channelReconfigPdmTXGPIO(handle: sys.i2s_chan_handle_t, gpio_cfg: ?*const sys.i2s_pdm_tx_gpio_config_t) !void {
    return try errors.espCheckError(sys.i2s_channel_reconfig_pdm_tx_gpio(handle, gpio_cfg));
}
