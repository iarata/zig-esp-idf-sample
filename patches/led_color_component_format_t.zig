//! # LED Color Component Format Patch
//!
//! Provides an explicit `led_color_component_format_t` union that preserves
//! the channel-position format metadata required by LED strip drivers.
//! Replaces the opaque type produced by C-to-Zig translation.

/// Union representing LED color component ordering and layout.
/// Access `format` for per-channel position metadata, or `format_id` as a raw u32.
pub const led_color_component_format_t = extern union {
    // Keeps the explicit union form required by led_strip format selection logic.
    format: struct_format_layout_15,
    format_id: u32,
};
