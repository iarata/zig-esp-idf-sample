//! # ESP-IDF Panic Handler (`esp_panic`)
//!
//! **What:** A Zig panic handler that prints the panic reason and available stack
//! trace frames through ESP-IDF logging, then halts the core with an infinite
//! loop.
//!
//! **What it does:**
//!   1. Writes the panic message string via `esp_log_write` with timestamp.
//!   2. If a stack trace is provided by the Zig runtime, iterates over
//!      instruction addresses and prints them as hexadecimal (useful for
//!      `addr2line` post-mortem).
//!   3. Enters an infinite loop with a memory barrier (`asm volatile`) to
//!      prevent the compiler from optimising the halt away.
//!
//! **How:** Matches the `std.builtin.PanicFn` signature so it can be assigned
//! to `pub const panic` in the root source file, overriding the default Zig
//! panic handler.
//!
//! **When to use:** Always wire this in your entry file to get readable panic
//! output on the serial console instead of a silent hang.
//!
//! **What it takes:**
//!   - `msg`: human-readable panic string.
//!   - `stack_trace`: optional `StackTrace` from the Zig runtime.
//!   - returns `noreturn`.
//!
//! **Example (in your root file):**
//! ```zig
//! const idf = @import("esp_idf");
//! pub const panic = idf.esp_panic.panic;
//! ```

const sys = @import("sys");
const log = @import("log");

/// panic handler for esp-idf
pub fn panic(msg: []const u8, stack_trace: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    sys.esp_log_write(log.default_level, "PANIC", "[%lu ms] PANIC: %.*s\n", sys.esp_log_timestamp(), msg.len, msg.ptr);

    // try print stack trace if available
    if (stack_trace) |st| {
        var i: usize = st.index;
        if (i > st.instruction_addresses.len) i = st.instruction_addresses.len;
        var idx: usize = 0;
        while (idx < i) : (idx += 1) {
            sys.esp_log_write(log.default_level, "PANIC", "  #%u: 0x%08lx\n", idx, st.instruction_addresses[idx]);
        }
    }

    while (true) {
        asm volatile ("" ::: "memory");
    }
}
