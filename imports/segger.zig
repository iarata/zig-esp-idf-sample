//! # SEGGER RTT Wrapper (`segger`)
//!
//! **What:** Zig bindings for SEGGER Real-Time Transfer (RTT) — a
//! high-performance debug logging channel that works over JTAG/SWD without
//! UART, using shared-memory ring buffers between the target and the debugger.
//!
//! **What it does:**
//!   - `RTT.init()` — initialise the RTT control block.
//!   - `RTT.write(bufIdx, ptr, len)` — write raw bytes to an up-buffer.
//!   - `RTT.read(bufIdx, ptr, len)` — read bytes from a down-buffer.
//!   - `RTT.allocUpBuffer/allocDownBuffer` — allocate additional named
//!     channels.
//!   - `RTT.configUpBuffer/configDownBuffer` — set flags (blocking, trim,
//!     skip) per channel.
//!   - `RTT.hasKey/getKey/waitKey` — keyboard input from the debugger
//!     terminal.
//!   - `RTT.setTerminal/terminalOut` — SEGGER virtual terminal multiplexing.
//!   - `RTT.printf / vprintf` — C-style formatted output.
//!
//! **How:** Thin wrappers around `sys.SEGGER_RTT_*` functions.
//!
//! **When to use:**
//!   - When UART is unavailable or too slow for debug output.
//!   - Profiling/tracing with SystemView.
//!   - Real-time logging in interrupt-heavy or timing-sensitive code.
//!
//! **What it takes:**
//!   - A JTAG/SWD debugger connected to the target.
//!   - A host tool like "SEGGER RTT Viewer" or `JLinkRTTClient`.
//!
//! **Example:**
//! ```zig
//! const rtt = idf.segger.RTT;
//! rtt.init();
//! _ = rtt.write(0, "Hello from RTT\n", 15);
//! _ = rtt.terminalOut(1, "Terminal 1 output");
//! ```

const sys = @import("sys");

/// SEGGER Real-Time Transfer interface.
pub const RTT = struct {
    /// Allocate a new down-buffer (host → target) channel.
    pub fn allocDownBuffer(sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_AllocDownBuffer(sName, pBuffer, BufferSize, Flags);
    }
    /// Allocate a new up-buffer (target → host) channel.
    pub fn allocUpBuffer(sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_AllocUpBuffer(sName, pBuffer, BufferSize, Flags);
    }
    /// Configure an up-buffer (name, memory, flags).
    pub fn configUpBuffer(BufferIndex: c_uint, sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_ConfigUpBuffer(BufferIndex, sName, pBuffer, BufferSize, Flags);
    }
    /// Configure a down-buffer (name, memory, flags).
    pub fn configDownBuffer(BufferIndex: c_uint, sName: [*:0]const u8, pBuffer: ?*anyopaque, BufferSize: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_ConfigDownBuffer(BufferIndex, sName, pBuffer, BufferSize, Flags);
    }
    /// Read a single key from the default down-buffer (non-blocking).
    pub fn getKey() c_int {
        return sys.SEGGER_RTT_GetKey();
    }
    /// Return number of bytes available in a given down-buffer.
    pub fn hasData(BufferIndex: c_uint) c_uint {
        return sys.SEGGER_RTT_HasData(BufferIndex);
    }
    /// Check whether at least one key is available.
    pub fn hasKey() c_int {
        return sys.SEGGER_RTT_HasKey();
    }
    /// Return number of bytes in a given up-buffer.
    pub fn hasDataUp(BufferIndex: c_uint) c_uint {
        return sys.SEGGER_RTT_HasDataUp(BufferIndex);
    }
    /// Initialise the RTT control block. Must be called before any I/O.
    pub fn init() void {
        sys.SEGGER_RTT_Init();
    }
    /// Read up to `BufferSize` bytes from a down-buffer.
    pub fn read(BufferIndex: c_uint, pBuffer: ?*anyopaque, BufferSize: c_uint) c_uint {
        return sys.SEGGER_RTT_Read(BufferIndex, pBuffer, BufferSize);
    }
    /// Read from a down-buffer without acquiring the lock.
    pub fn readNoLock(BufferIndex: c_uint, pData: ?*anyopaque, BufferSize: c_uint) c_uint {
        return sys.SEGGER_RTT_ReadNoLock(BufferIndex, pData, BufferSize);
    }
    /// Rename a down-buffer channel.
    pub fn setNameDownBuffer(BufferIndex: c_uint, sName: [*:0]const u8) c_int {
        return sys.SEGGER_RTT_SetNameDownBuffer(BufferIndex, sName);
    }
    /// Rename an up-buffer channel.
    pub fn setNameUpBuffer(BufferIndex: c_uint, sName: [*:0]const u8) c_int {
        return sys.SEGGER_RTT_SetNameUpBuffer(BufferIndex, sName);
    }
    /// Set flags (blocking/trim/skip) on a down-buffer.
    pub fn setFlagsDownBuffer(BufferIndex: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_SetFlagsDownBuffer(BufferIndex, Flags);
    }
    /// Set flags (blocking/trim/skip) on an up-buffer.
    pub fn setFlagsUpBuffer(BufferIndex: c_uint, Flags: c_uint) c_int {
        return sys.SEGGER_RTT_SetFlagsUpBuffer(BufferIndex, Flags);
    }
    /// Block until a key is available, then return it.
    pub fn waitKey() c_int {
        return sys.SEGGER_RTT_WaitKey();
    }
    /// Write raw bytes to an up-buffer. Returns number of bytes written.
    pub fn write(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint {
        return sys.SEGGER_RTT_Write(BufferIndex, pBuffer, NumBytes);
    }
    // pub fn WriteNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
    // pub fn WriteSkipNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
    // pub fn ASM_WriteSkipNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
    // pub fn WriteString(BufferIndex: c_uint, s: [*:0]const u8) c_uint;
    // pub fn WriteWithOverwriteNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) void;
    // pub fn PutChar(BufferIndex: c_uint, c: u8) c_uint;
    // pub fn PutCharSkip(BufferIndex: c_uint, c: u8) c_uint;
    // pub fn PutCharSkipNoLock(BufferIndex: c_uint, c: u8) c_uint;
    // pub fn GetAvailWriteSpace(BufferIndex: c_uint) c_uint;
    // pub fn GetBytesInBuffer(BufferIndex: c_uint) c_uint;
    // pub fn ESP_FlushNoLock(min_sz: c_ulong, tmo: c_ulong) void;
    // pub fn ESP_Flush(min_sz: c_ulong, tmo: c_ulong) void;
    // pub fn ReadUpBuffer(BufferIndex: c_uint, pBuffer: ?*anyopaque, BufferSize: c_uint) c_uint;
    // pub fn ReadUpBufferNoLock(BufferIndex: c_uint, pData: ?*anyopaque, BufferSize: c_uint) c_uint;
    // pub fn WriteDownBuffer(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
    // pub fn WriteDownBufferNoLock(BufferIndex: c_uint, pBuffer: ?*const anyopaque, NumBytes: c_uint) c_uint;
    /// Set the active virtual terminal ID for subsequent output.
    pub fn setTerminal(TerminalId: u8) c_int {
        return sys.SEGGER_RTT_SetTerminal(TerminalId);
    }
    /// Write a string to a specific virtual terminal.
    pub fn terminalOut(TerminalId: u8, s: [*:0]const u8) c_int {
        return sys.SEGGER_RTT_TerminalOut(TerminalId, s);
    }
    /// C-style printf to an RTT buffer.
    pub const printf = sys.SEGGER_RTT_printf;
    /// C-style vprintf to an RTT buffer.
    pub fn vprintf(BufferIndex: c_uint, sFormat: [*:0]const u8, pParamList: [*c]sys.va_list) c_int {
        return sys.SEGGER_RTT_vprintf(BufferIndex, sFormat, pParamList);
    }
};
