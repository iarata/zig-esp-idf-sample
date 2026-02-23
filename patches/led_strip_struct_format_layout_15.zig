//! # LED Strip Format Layout Patch
//!
//! Provides the explicit `struct_format_layout_15` that describes per-channel
//! position metadata (R/G/B/W offsets, bytes per color, component count)
//! used by `led_color_component_format_t`.

/// Per-channel color position layout: channel positions (r/g/b/w), bytes per color, and component count.
pub const struct_format_layout_15 = extern struct {
    // Explicit channel-position metadata used by led_color_component_format_t.
    r_pos: u32 = 0,
    g_pos: u32 = 0,
    b_pos: u32 = 0,
    w_pos: u32 = 0,
    reserved: u32 = 0,
    bytes_per_color: u32 = 0,
    num_components: u32 = 0,
};
