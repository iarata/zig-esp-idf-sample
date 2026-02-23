//! # UART Driver Wrapper (`uart`)
//!
//! **What:** Full-featured Zig wrapper for the ESP-IDF UART driver covering
//! installation, parameter configuration, interrupt control, flow control,
//! pattern detection, and blocking I/O.
//!
//! **What it does:**
//!   - `driverInstall` / `driverDelete` — install the FreeRTOS-based UART
//!     driver with configurable RX/TX ring buffers and event queue.
//!   - `paramConfig` — apply baud rate, word length, parity, and stop bits.
//!   - `setPin` — remap TX/RX/RTS/CTS to any GPIO.
//!   - `writeBytes` / `readBytes` — blocking data transfer with tick timeout.
//!   - `flush` / `flushInput` — drain TX or discard RX data.
//!   - `enablePatternDetBaudIntr` — hardware-assisted pattern detection (e.g.
//!     AT command `+++` detection).
//!   - Interrupt, flow-control, wake-up threshold, loopback, and RS485 mode
//!     helpers.
//!
//! **How:** Each function is a thin wrapper around `sys.uart_*` with
//! `esp_err_t` → Zig error conversion.
//!
//! **When to use:** Serial console, GPS/BLE UART bridges, RS485 modbus, or any
//! protocol that rides on UART.
//!
//! **What it takes:**
//!   - `uart_port_t` (0, 1, or 2 on ESP32-S3).
//!   - `uart_config_t` for baud/parity/stop.
//!   - Buffer sizes for driver install.
//!
//! **Example:**
//! ```zig
//! const uart = idf.uart;
//! try uart.paramConfig(0, &.{
//!     .baud_rate = 115200,
//!     .data_bits = sys.UART_DATA_8_BITS,
//!     .parity = sys.UART_PARITY_DISABLE,
//!     .stop_bits = sys.UART_STOP_BITS_1,
//!     .flow_ctrl = sys.UART_HW_FLOWCTRL_DISABLE,
//! });
//! try uart.driverInstall(0, 1024, 0, 0, null, 0);
//! _ = uart.writeBytes(0, "Hello UART\n", 11);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// Install the UART driver with RX/TX ring buffers and optional event queue.
pub fn driverInstall(uart_num: sys.uart_port_t, rx_buffer_size: c_int, tx_buffer_size: c_int, queue_size: c_int, uart_queue: [*c]sys.QueueHandle_t, intr_alloc_flags: c_int) !void {
    return try errors.espCheckError(sys.uart_driver_install(uart_num, rx_buffer_size, tx_buffer_size, queue_size, uart_queue, intr_alloc_flags));
}
/// Uninstall the UART driver and free ring buffers.
pub fn driverDelete(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_driver_delete(uart_num));
}
/// Check whether the UART driver is installed on this port.
pub fn isDriverInstalled(uart_num: sys.uart_port_t) bool {
    return sys.uart_is_driver_installed(uart_num);
}
/// Set UART word length (5–8 bits).
pub fn setWordLength(uart_num: sys.uart_port_t, data_bit: sys.uart_word_length_t) !void {
    return try errors.espCheckError(sys.uart_set_word_length(uart_num, data_bit));
}
/// Get the current word length setting.
pub fn getWordLength(uart_num: sys.uart_port_t, data_bit: [*c]sys.uart_word_length_t) !void {
    return try errors.espCheckError(sys.uart_get_word_length(uart_num, data_bit));
}
/// Set the number of stop bits.
pub fn setStopBits(uart_num: sys.uart_port_t, stop_bits: sys.uart_stop_bits_t) !void {
    return try errors.espCheckError(sys.uart_set_stop_bits(uart_num, stop_bits));
}
/// Get the current stop bits setting.
pub fn getStopBits(uart_num: sys.uart_port_t, stop_bits: [*c]sys.uart_stop_bits_t) !void {
    return try errors.espCheckError(sys.uart_get_stop_bits(uart_num, stop_bits));
}
/// Set the parity mode (none, even, odd).
pub fn setParity(uart_num: sys.uart_port_t, parity_mode: sys.uart_parity_t) !void {
    return try errors.espCheckError(sys.uart_set_parity(uart_num, parity_mode));
}
/// Get the current parity mode.
pub fn getParity(uart_num: sys.uart_port_t, parity_mode: [*c]sys.uart_parity_t) !void {
    return try errors.espCheckError(sys.uart_get_parity(uart_num, parity_mode));
}
/// Get the frequency of a UART source clock.
pub fn getSclkFreq(sclk: sys.uart_sclk_t, out_freq_hz: [*c]u32) !void {
    return try errors.espCheckError(sys.uart_get_sclk_freq(sclk, out_freq_hz));
}
/// Set the UART baud rate.
pub fn setBaudrate(uart_num: sys.uart_port_t, baudrate: u32) !void {
    return try errors.espCheckError(sys.uart_set_baudrate(uart_num, baudrate));
}
/// Get the current baud rate.
pub fn getBaudrate(uart_num: sys.uart_port_t, baudrate: [*c]u32) !void {
    return try errors.espCheckError(sys.uart_get_baudrate(uart_num, baudrate));
}
/// Invert specific UART signal lines (TX, RX, RTS, CTS).
pub fn setLineInverse(uart_num: sys.uart_port_t, inverse_mask: u32) !void {
    return try errors.espCheckError(sys.uart_set_line_inverse(uart_num, inverse_mask));
}
/// Configure hardware flow control (CTS/RTS) and RX FIFO threshold.
pub fn setHWFlowCtrl(uart_num: sys.uart_port_t, flow_ctrl: sys.uart_hw_flowcontrol_t, rx_thresh: u8) !void {
    return try errors.espCheckError(sys.uart_set_hw_flow_ctrl(uart_num, flow_ctrl, rx_thresh));
}
/// Configure software flow control (XON/XOFF).
pub fn setSWFlowCtrl(uart_num: sys.uart_port_t, enable: bool, rx_thresh_xon: u8, rx_thresh_xoff: u8) !void {
    return try errors.espCheckError(sys.uart_set_sw_flow_ctrl(uart_num, enable, rx_thresh_xon, rx_thresh_xoff));
}
/// Get the current hardware flow control configuration.
pub fn getHWFlowCtrl(uart_num: sys.uart_port_t, flow_ctrl: [*c]sys.uart_hw_flowcontrol_t) !void {
    return try errors.espCheckError(sys.uart_get_hw_flow_ctrl(uart_num, flow_ctrl));
}
/// Clear pending interrupt status bits.
pub fn clearIntrStatus(uart_num: sys.uart_port_t, clr_mask: u32) !void {
    return try errors.espCheckError(sys.uart_clear_intr_status(uart_num, clr_mask));
}
/// Enable specific UART interrupts.
pub fn enableIntrMask(uart_num: sys.uart_port_t, enable_mask: u32) !void {
    return try errors.espCheckError(sys.uart_enable_intr_mask(uart_num, enable_mask));
}
/// Disable specific UART interrupts.
pub fn disable_intr_mask(uart_num: sys.uart_port_t, disable_mask: u32) !void {
    return try errors.espCheckError(sys.uart_disable_intr_mask(uart_num, disable_mask));
}
/// Enable the RX interrupt.
pub fn enableRXIntr(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_enable_rx_intr(uart_num));
}
/// Disable the RX interrupt.
pub fn disableRXIntr(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_disable_rx_intr(uart_num));
}
/// Disable the TX interrupt.
pub fn disableTXIntr(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_disable_tx_intr(uart_num));
}
/// Enable the TX interrupt with an empty-FIFO threshold.
pub fn enableTXIntr(uart_num: sys.uart_port_t, enable: c_int, thresh: c_int) !void {
    return try errors.espCheckError(sys.uart_enable_tx_intr(uart_num, enable, thresh));
}
/// Remap UART TX/RX/RTS/CTS to arbitrary GPIO pins (use `-1` to keep unchanged).
pub fn setPin(uart_num: sys.uart_port_t, tx_io_num: c_int, rx_io_num: c_int, rts_io_num: c_int, cts_io_num: c_int) !void {
    return try errors.espCheckError(sys.uart_set_pin(uart_num, tx_io_num, rx_io_num, rts_io_num, cts_io_num));
}
/// Manually set the RTS signal level.
pub fn setRTS(uart_num: sys.uart_port_t, level: c_int) !void {
    return try errors.espCheckError(sys.uart_set_rts(uart_num, level));
}
/// Manually set the DTR signal level.
pub fn setDTR(uart_num: sys.uart_port_t, level: c_int) !void {
    return try errors.espCheckError(sys.uart_set_dtr(uart_num, level));
}
/// Set the number of idle UART clock cycles inserted between TX frames.
pub fn setTXIdleNum(uart_num: sys.uart_port_t, idle_num: u16) !void {
    return try errors.espCheckError(sys.uart_set_tx_idle_num(uart_num, idle_num));
}
/// Apply a full UART parameter configuration (baud, word length, parity, stop bits).
pub fn paramConfig(uart_num: sys.uart_port_t, uart_config: [*c]const sys.uart_config_t) !void {
    return try errors.espCheckError(sys.uart_param_config(uart_num, uart_config));
}
/// Configure UART interrupt thresholds and enables.
pub fn intrConfig(uart_num: sys.uart_port_t, intr_conf: [*c]const sys.uart_intr_config_t) !void {
    return try errors.espCheckError(sys.uart_intr_config(uart_num, intr_conf));
}
/// Wait until all TX data has been sent, with a tick timeout.
pub fn waitTXDone(uart_num: sys.uart_port_t, ticks_to_wait: sys.TickType_t) !void {
    return try errors.espCheckError(sys.uart_wait_tx_done(uart_num, ticks_to_wait));
}
/// Send characters from a buffer directly into the TX FIFO (non-blocking).
pub fn txChars(uart_num: sys.uart_port_t, buffer: [*:0]const u8, len: u32) c_int {
    return sys.uart_tx_chars(uart_num, buffer, len);
}
/// Write data to the TX ring buffer; blocks until all data is queued.
pub fn writeBytes(uart_num: sys.uart_port_t, src: ?*const anyopaque, size: usize) c_int {
    return sys.uart_write_bytes(uart_num, src, size);
}
/// Write data followed by a UART break signal.
pub fn writeBytesWithBreak(uart_num: sys.uart_port_t, src: ?*const anyopaque, size: usize, brk_len: c_int) c_int {
    return sys.uart_write_bytes_with_break(uart_num, src, size, brk_len);
}
/// Read data from the RX ring buffer with a tick timeout.
pub fn readBytes(uart_num: sys.uart_port_t, buf: ?*anyopaque, length: u32, ticks_to_wait: sys.TickType_t) c_int {
    return sys.uart_read_bytes(uart_num, buf, length, ticks_to_wait);
}
/// Wait for TX FIFO to drain and flush the TX ring buffer.
pub fn flush(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_flush(uart_num));
}
/// Discard all data in the RX ring buffer.
pub fn flushInput(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_flush_input(uart_num));
}
/// Get the number of bytes available in the RX ring buffer.
pub fn getBufferedDataLen(uart_num: sys.uart_port_t, size: [*c]usize) !void {
    return try errors.espCheckError(sys.uart_get_buffered_data_len(uart_num, size));
}
/// Get the number of free bytes in the TX ring buffer.
pub fn getTXBufferFreeSize(uart_num: sys.uart_port_t, size: [*c]usize) !void {
    return try errors.espCheckError(sys.uart_get_tx_buffer_free_size(uart_num, size));
}
/// Disable the baud-rate pattern detection interrupt.
pub fn disablePatternDetIntr(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_disable_pattern_det_intr(uart_num));
}
/// Enable baud-rate based pattern detection (e.g. AT command `+++`).
pub fn enablePatternDetBaudIntr(uart_num: sys.uart_port_t, pattern_chr: u8, chr_num: u8, chr_tout: c_int, post_idle: c_int, pre_idle: c_int) !void {
    return try errors.espCheckError(sys.uart_enable_pattern_det_baud_intr(uart_num, pattern_chr, chr_num, chr_tout, post_idle, pre_idle));
}
/// Pop the next detected pattern position from the pattern queue.
pub fn patternPopPos(uart_num: sys.uart_port_t) c_int {
    return sys.uart_pattern_pop_pos(uart_num);
}
/// Get the current pattern position without removing it from the queue.
pub fn patternGePos(uart_num: sys.uart_port_t) c_int {
    return sys.uart_pattern_get_pos(uart_num);
}
/// Reset the pattern detection queue with a new capacity.
pub fn patternQueueReset(uart_num: sys.uart_port_t, queue_length: c_int) !void {
    return try errors.espCheckError(sys.uart_pattern_queue_reset(uart_num, queue_length));
}
/// Set the UART operating mode (UART, RS485, IrDA, etc.).
pub fn setMode(uart_num: sys.uart_port_t, mode: sys.uart_mode_t) !void {
    return try errors.espCheckError(sys.uart_set_mode(uart_num, mode));
}
/// Set the RX FIFO full threshold that triggers the RX interrupt.
pub fn setRXFullThreshold(uart_num: sys.uart_port_t, threshold: c_int) !void {
    return try errors.espCheckError(sys.uart_set_rx_full_threshold(uart_num, threshold));
}
/// Set the TX FIFO empty threshold for the TX interrupt.
pub fn setTXEmptyThreshold(uart_num: sys.uart_port_t, threshold: c_int) !void {
    return try errors.espCheckError(sys.uart_set_tx_empty_threshold(uart_num, threshold));
}
/// Set the RX timeout (symbol periods) after which idle is detected.
pub fn setRXTimeout(uart_num: sys.uart_port_t, tout_thresh: u8) !void {
    return try errors.espCheckError(sys.uart_set_rx_timeout(uart_num, tout_thresh));
}
/// Check whether a collision was detected (RS485 half-duplex mode).
pub fn getCollisionFlag(uart_num: sys.uart_port_t, collision_flag: [*c]bool) !void {
    return try errors.espCheckError(sys.uart_get_collision_flag(uart_num, collision_flag));
}
/// Set the number of RX edges required to wake the chip from light sleep.
pub fn setWakeupThreshold(uart_num: sys.uart_port_t, wakeup_threshold: c_int) !void {
    return try errors.espCheckError(sys.uart_set_wakeup_threshold(uart_num, wakeup_threshold));
}
/// Get the current wakeup threshold.
pub fn getWakeupThreshold(uart_num: sys.uart_port_t, out_wakeup_threshold: [*c]c_int) !void {
    return try errors.espCheckError(sys.uart_get_wakeup_threshold(uart_num, out_wakeup_threshold));
}
/// Busy-wait until the TX FIFO is empty (polling, not interrupt-based).
pub fn waitTXIdlePolling(uart_num: sys.uart_port_t) !void {
    return try errors.espCheckError(sys.uart_wait_tx_idle_polling(uart_num));
}
/// Enable or disable internal loopback (TX connected to RX).
pub fn setLoopBack(uart_num: sys.uart_port_t, loop_back_en: bool) !void {
    return try errors.espCheckError(sys.uart_set_loop_back(uart_num, loop_back_en));
}
/// Enable RX timeout even after receiving only a partial FIFO.
pub fn setAlwaysRXTimeout(uart_num: sys.uart_port_t, always_rx_timeout_en: bool) void {
    sys.uart_set_always_rx_timeout(uart_num, always_rx_timeout_en);
}
