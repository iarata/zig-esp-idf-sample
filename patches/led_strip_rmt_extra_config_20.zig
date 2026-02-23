//! # LED Strip RMT Extra Configuration Patch
//!
//! Provides the `struct_led_strip_rmt_extra_config_20` that adds DMA
//! support flags for RMT-based LED strip drivers on targets that support it.

/// Extra RMT configuration enabling DMA-backed transfers for LED strip drivers.
pub const struct_led_strip_rmt_extra_config_20 = extern struct {
    // Enables DMA-backed RMT transfers when supported by the target.
    with_dma: u32 = 0,
};
