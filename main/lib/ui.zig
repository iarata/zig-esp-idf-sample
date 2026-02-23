//! # UI Composition Helpers (`ui.zig`)
//!
//! **What:** A lightweight wrapper that creates and manages a centred LVGL
//! label on the active screen.  Intended as the default “hello world” UI
//! layer for the demo app.
//!
//! **What it does:**
//!   - `mount(options)` — obtains the active LVGL screen, creates a label
//!     widget, sets its text, optionally applies the “Runa” decorative style,
//!     and centres it.  Returns a `Root` handle (or `null` on failure).
//!   - `Root.setText(text)` — updates the label text and re-centres it so
//!     layout stays correct when line count or width changes.
//!
//! **How:** Call `mount` while the LVGL lock is held (between
//! `lvgl.lock()` and `lvgl.unlock()`).  The returned `Root` can be kept
//! and used later to update the label text.
//!
//! **When to use:** For quick prototyping when you just need a text label
//! on screen.  Replace with your own widget tree for production UIs.
//!
//! **What it takes:**
//!   - `RootOptions.text`       — initial label string (default: "Zig + LVGL\nUI loaded").
//!   - `RootOptions.runa_style` — whether to apply decorative font/style.
//!
//! **Example:**
//! ```zig
//! const ui = @import("app_ui");
//! const idf = @import("esp_idf");
//!
//! idf.lvgl.lock();
//! defer idf.lvgl.unlock();
//!
//! var root = ui.mount(.{ .text = "Hello!" }) orelse return;
//! root.setText("Updated text");
//! ```

const idf = @import("esp_idf");
const lvgl = idf.lvgl;

pub const RootOptions = struct {
    text: [*:0]const u8 = "Zig + LVGL\nUI loaded",
    runa_style: bool = false,
};

pub const Root = struct {
    label: ?*lvgl.Object = null,

    /// Re-centers after every text update because LVGL label geometry can shift
    /// when line count/width changes.
    pub fn setText(self: *Root, text: [*:0]const u8) void {
        if (self.label) |label| {
            lvgl.setLabelText(label, text);
            lvgl.center(label);
        }
    }
};

/// Uses nullable return instead of propagating errors so call-sites can decide
/// whether UI creation failure should be fatal in their startup path.
pub fn mount(options: RootOptions) ?Root {
    const screen = lvgl.activeScreen() orelse return null;
    const label = lvgl.createLabel(screen) orelse return null;
    lvgl.setLabelText(label, options.text);
    if (options.runa_style) {
        lvgl.applyRunaStyle(screen, label);
    }
    lvgl.center(label);
    return .{ .label = label };
}
