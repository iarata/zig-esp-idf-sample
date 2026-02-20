const idf = @import("esp_idf");
const lvgl = idf.lvgl;

pub const RootOptions = struct {
    text: [*:0]const u8 = "Zig + LVGL\nUI loaded",
};

pub const Root = struct {
    label: ?*lvgl.Object = null,

    pub fn setText(self: *Root, text: [*:0]const u8) void {
        if (self.label) |label| {
            lvgl.setLabelText(label, text);
            lvgl.center(label);
        }
    }
};

pub fn mount(options: RootOptions) ?Root {
    const screen = lvgl.activeScreen() orelse return null;
    const label = lvgl.createLabel(screen) orelse return null;
    lvgl.setLabelText(label, options.text);
    lvgl.center(label);
    return .{ .label = label };
}
