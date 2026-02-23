//! # LED Strip RMT Configuration Patch
//!
//! Provides a concrete `led_strip_rmt_config_t` layout for configuring
//! the RMT peripheral as an LED strip driver backend. Replaces the
//! opaque type produced by C-to-Zig translation.

/// RMT-backend configuration for LED strip drivers (clock source, resolution, memory blocks).
pub const led_strip_rmt_config_t = extern struct {
    // Restores explicit RMT config fields that are used by Zig wrappers.
    clk_src: rmt_clock_source_t = @import("std").mem.zeroes(rmt_clock_source_t),
    resolution_hz: u32 = 0,
    mem_block_symbols: usize = 0,
    flags: led_strip_flags = @import("std").mem.zeroes(led_strip_flags),
};

/// Flag bits for LED strip RMT configuration.
const led_strip_flags = extern struct {
    // Bit layout includes invert_out and optional extension bits from newer IDF.
    invert_out: u32,
};
