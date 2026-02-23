//! # GPIO Wrapper (`gpio`)
//!
//! **What:** A target-aware, type-safe GPIO abstraction layer that wraps the
//! entire ESP-IDF GPIO driver and exposes only the pins physically present on
//! the selected SoC.
//!
//! **What it does:**
//!   - `Num()` / `GpioNum` — comptime-generated enum containing only pin
//!     numbers declared by the current target (e.g. ESP32-S3 has 0–48,
//!     ESP32-C3 has 0–21).  Referencing a pin that doesn't exist is a
//!     compile error.
//!   - `config()` — applies a full GPIO configuration struct (direction, pull,
//!     interrupt type) in one call.
//!   - `Level.set/get` — digital write / read.
//!   - `Direction.set` — change pin direction at runtime.
//!   - `isrHandlerAdd/Remove` — per-pin ISR registration.
//!   - Hold, deep-sleep, wakeup, drive-strength, sleep-mode, IOMUX, ETM, and
//!     ROM helper sections.
//!
//! **How:** Every function converts the Zig `GpioNum` enum to the raw C
//! `gpio_num_t` via `numToC()`, calls the underlying `sys.gpio_*` function,
//! and maps the returned `esp_err_t` to a Zig error with `espCheckError`.
//!
//! **When to use:** Any time you need to configure or interact with GPIO pins
//! from Zig code (LEDs, buttons, chip-selects, interrupt lines, etc.).
//!
//! **What it takes:** A `GpioNum` pin identifier and the relevant config
//! option (mode, level, interrupt type, etc.).
//!
//! **Example:**
//! ```zig
//! const gpio = idf.gpio;
//!
//! // Configure GPIO 2 as push-pull output
//! var cfg = std.mem.zeroes(sys.gpio_config_t);
//! cfg.pin_bit_mask = 1 << 2;
//! cfg.mode = @intFromEnum(gpio.Mode.output);
//! cfg.pull_up_en = @intFromEnum(gpio.Pullup.disable);
//! cfg.pull_down_en = @intFromEnum(gpio.Pulldown.disable);
//! try gpio.config(&cfg);
//!
//! // Toggle the pin
//! try gpio.Level.set(.@"2", 1);
//! idf.rtos.Task.delayMs(500);
//! try gpio.Level.set(.@"2", 0);
//!
//! // Read an input
//! const high = gpio.Level.get(.@"0");
//! ```

const sys = @import("sys");
const std = @import("std");
const errors = @import("error");

// ---------------------------------------------------------------------------
// Num — generated enum containing only pins that exist on the current target.
// ---------------------------------------------------------------------------

/// Generate the GPIO pin enum at comptime for the current SoC target.
///
/// Returns an exhaustive enum whose fields are the GPIO numbers that exist
/// on the active `sys` bindings (e.g. `0`–`48` for ESP32-S3), plus the
/// `NC` (not-connected) and `MAX` sentinel values.  Referencing a pin
/// number that the target does not declare is a compile error.
pub fn Num() type {
    comptime var names: []const []const u8 = &.{};
    comptime var values: []const sys.gpio_num_t = &.{};

    // Always-present sentinels.
    names = names ++ &[_][]const u8{ "NC", "MAX" };
    values = values ++ &[_]sys.gpio_num_t{
        @intCast(sys.GPIO_NUM_NC),
        @intCast(sys.GPIO_NUM_MAX),
    };

    // Add only the pins the current target actually declares in sys.
    inline for (0..49) |n| {
        @setEvalBranchQuota(200000);
        const decl = std.fmt.comptimePrint("GPIO_NUM_{d}", .{n});
        if (@hasDecl(sys, decl)) {
            names = names ++ &[_][]const u8{std.fmt.comptimePrint("{d}", .{n})};
            values = values ++ &[_]sys.gpio_num_t{@intCast(@field(sys, decl))};
        }
    }

    // @Enum(TagInt, mode, field_names, field_values)
    return @Enum(
        sys.gpio_num_t,
        .exhaustive,
        names,
        values[0..],
    );
}

/// The GPIO pin enum for the current target.
/// Only pins declared by the BSP/sys module are present as fields.
/// Referencing a missing pin (e.g. `.@"22"` on ESP32-C3) is a compile error.
pub const GpioNum = Num();

/// Convert a GpioNum to the raw C type expected by esp-idf APIs.
pub inline fn numToC(gpio_num: GpioNum) sys.gpio_num_t {
    return @intFromEnum(gpio_num);
}

// ---------------------------------------------------------------------------
// Other enumerations
// ---------------------------------------------------------------------------

/// GPIO port enumeration.
pub const Port = enum(sys.gpio_port_t) {
    GPIO_PORT_0 = sys.GPIO_PORT_0,
    GPIO_PORT_MAX = sys.GPIO_PORT_MAX,
};

/// GPIO interrupt trigger type.
pub const IntType = enum(sys.gpio_int_type_t) {
    disable = sys.GPIO_INTR_DISABLE,
    posedge = sys.GPIO_INTR_POSEDGE,
    negedge = sys.GPIO_INTR_NEGEDGE,
    anyedge = sys.GPIO_INTR_ANYEDGE,
    low_level = sys.GPIO_INTR_LOW_LEVEL,
    high_level = sys.GPIO_INTR_HIGH_LEVEL,
    max = sys.GPIO_INTR_MAX,
};

/// GPIO pin direction mode.
pub const Mode = enum(sys.gpio_mode_t) {
    disable = sys.GPIO_MODE_DISABLE,
    input = sys.GPIO_MODE_INPUT,
    output = sys.GPIO_MODE_OUTPUT,
    output_od = sys.GPIO_MODE_OUTPUT_OD,
    input_output_od = sys.GPIO_MODE_INPUT_OUTPUT_OD,
    input_output = sys.GPIO_MODE_INPUT_OUTPUT,
};

/// GPIO internal pull-up resistor control.
pub const Pullup = enum(sys.gpio_pullup_t) {
    disable = sys.GPIO_PULLUP_DISABLE,
    enable = sys.GPIO_PULLUP_ENABLE,
};

/// GPIO internal pull-down resistor control.
pub const Pulldown = enum(sys.gpio_pulldown_t) {
    disable = sys.GPIO_PULLDOWN_DISABLE,
    enable = sys.GPIO_PULLDOWN_ENABLE,
};

/// GPIO pull resistor configuration mode.
pub const PullMode = enum(sys.gpio_pull_mode_t) {
    pullup_only = sys.GPIO_PULLUP_ONLY,
    pulldown_only = sys.GPIO_PULLDOWN_ONLY,
    pullup_pulldown = sys.GPIO_PULLUP_PULLDOWN,
    floating = sys.GPIO_FLOATING,
};

/// GPIO output drive strength capability.
pub const DriveCap = enum(sys.gpio_drive_cap_t) {
    cap_0 = sys.GPIO_DRIVE_CAP_0,
    cap_1 = sys.GPIO_DRIVE_CAP_1,
    cap_2 = sys.GPIO_DRIVE_CAP_2,
    default = sys.GPIO_DRIVE_CAP_DEFAULT,
    cap_3 = sys.GPIO_DRIVE_CAP_3,
    max = sys.GPIO_DRIVE_CAP_MAX,
};

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Apply a full GPIO configuration (direction, pull, interrupt type) to one
/// or more pins selected by the `pin_bit_mask` field in `cfg`.
pub fn config(cfg: [*c]const sys.gpio_config_t) !void {
    try errors.espCheckError(sys.gpio_config(cfg));
}

/// Reset a GPIO pin to its default state (input, no pull, no interrupt).
pub fn resetPin(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_reset_pin(numToC(gpio_num)));
}

// ---------------------------------------------------------------------------
// Interrupts
// ---------------------------------------------------------------------------

/// Set the interrupt trigger type for a specific GPIO pin.
pub fn setIntrType(gpio_num: GpioNum, intr_type: IntType) !void {
    try errors.espCheckError(sys.gpio_set_intr_type(numToC(gpio_num), @intFromEnum(intr_type)));
}

/// Enable interrupt for a specific GPIO pin.
pub fn intrEnable(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_intr_enable(numToC(gpio_num)));
}

/// Disable interrupt for a specific GPIO pin.
pub fn intrDisable(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_intr_disable(numToC(gpio_num)));
}

/// Install the GPIO ISR service with the given interrupt allocation flags.
pub fn installISRService(intr_alloc_flags: c_int) !void {
    try errors.espCheckError(sys.gpio_install_isr_service(intr_alloc_flags));
}

/// Uninstall the GPIO ISR service, freeing all per-pin handlers.
pub fn uninstallISRService() void {
    sys.gpio_uninstall_isr_service();
}

/// Register a global GPIO ISR handler for all pins.
pub fn isrRegister(
    handler: ?*const fn (?*anyopaque) callconv(.c) void,
    arg: ?*anyopaque,
    intr_alloc_flags: c_int,
    handle: [*c]sys.gpio_isr_handle_t,
) !void {
    try errors.espCheckError(sys.gpio_isr_register(handler, arg, intr_alloc_flags, handle));
}

/// Add a per-pin ISR handler for the given GPIO.
pub fn isrHandlerAdd(gpio_num: GpioNum, isr_handler: sys.gpio_isr_t, args: ?*anyopaque) !void {
    try errors.espCheckError(sys.gpio_isr_handler_add(numToC(gpio_num), isr_handler, args));
}

/// Remove a per-pin ISR handler for the given GPIO.
pub fn isrHandlerRemove(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_isr_handler_remove(numToC(gpio_num)));
}

// ---------------------------------------------------------------------------
// Level / Direction
// ---------------------------------------------------------------------------

/// Digital output level and input read operations.
pub const Level = struct {
    /// Set the output level of a GPIO pin.
    ///
    /// **Parameters**
    /// - `gpio_num`: The GPIO pin to drive.
    /// - `level`: `1` for high, `0` for low.
    pub fn set(gpio_num: GpioNum, level: u32) !void {
        try errors.espCheckError(sys.gpio_set_level(numToC(gpio_num), level));
    }
    /// Returns true if the pin is high, false if low.
    pub fn get(gpio_num: GpioNum) bool {
        return sys.gpio_get_level(numToC(gpio_num)) != 0;
    }
};

/// GPIO direction control.
pub const Direction = struct {
    /// Set the direction of a GPIO pin at runtime.
    pub fn set(gpio_num: GpioNum, mode: Mode) !void {
        try errors.espCheckError(sys.gpio_set_direction(numToC(gpio_num), @intFromEnum(mode)));
    }
    /// Set the GPIO direction for sleep mode.
    pub fn sleepSet(gpio_num: GpioNum, mode: Mode) !void {
        try errors.espCheckError(sys.gpio_sleep_set_direction(numToC(gpio_num), @intFromEnum(mode)));
    }
};

// ---------------------------------------------------------------------------
// Pull resistors
// ---------------------------------------------------------------------------

/// Set the internal pull resistor mode for a GPIO pin.
pub fn setPullMode(gpio_num: GpioNum, pull: PullMode) !void {
    try errors.espCheckError(sys.gpio_set_pull_mode(numToC(gpio_num), @intFromEnum(pull)));
}

/// Set pull mode for a GPIO pin during light-sleep.
pub fn sleepSetPullMode(gpio_num: GpioNum, pull: PullMode) !void {
    try errors.espCheckError(sys.gpio_sleep_set_pull_mode(numToC(gpio_num), @intFromEnum(pull)));
}

/// Pull-up and pull-down resistor enable/disable helpers.
pub const PULL = struct {
    /// Enable the internal pull-up resistor.
    pub fn upEn(gpio_num: GpioNum) !void {
        try errors.espCheckError(sys.gpio_pullup_en(numToC(gpio_num)));
    }
    /// Disable the internal pull-up resistor.
    pub fn upDis(gpio_num: GpioNum) !void {
        try errors.espCheckError(sys.gpio_pullup_dis(numToC(gpio_num)));
    }
    /// Enable the internal pull-down resistor.
    pub fn downEn(gpio_num: GpioNum) !void {
        try errors.espCheckError(sys.gpio_pulldown_en(numToC(gpio_num)));
    }
    /// Disable the internal pull-down resistor.
    pub fn downDis(gpio_num: GpioNum) !void {
        try errors.espCheckError(sys.gpio_pulldown_dis(numToC(gpio_num)));
    }
};

// ---------------------------------------------------------------------------
// Drive strength
// ---------------------------------------------------------------------------

/// Set the output drive strength for a GPIO pin.
pub fn setDriveCapability(gpio_num: GpioNum, strength: DriveCap) !void {
    try errors.espCheckError(sys.gpio_set_drive_capability(numToC(gpio_num), @intFromEnum(strength)));
}

/// Returns the drive capability of the given pin.
pub fn getDriveCapability(gpio_num: GpioNum) !DriveCap {
    var raw: sys.gpio_drive_cap_t = undefined;
    try errors.espCheckError(sys.gpio_get_drive_capability(numToC(gpio_num), &raw));
    return @enumFromInt(raw);
}

// ---------------------------------------------------------------------------
// Hold / deep-sleep
// ---------------------------------------------------------------------------

/// Enable pad hold function for a GPIO pin (output latched during deep sleep).
pub fn holdEn(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_hold_en(numToC(gpio_num)));
}

/// Disable pad hold function for a GPIO pin.
pub fn holdDis(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_hold_dis(numToC(gpio_num)));
}

/// Force-hold all GPIO pads (keeps state during deep sleep).
pub fn forceHoldAll() !void {
    try errors.espCheckError(sys.gpio_force_hold_all());
}

/// Release force-hold on all GPIO pads.
pub fn forceUnholdAll() !void {
    try errors.espCheckError(sys.gpio_force_unhold_all());
}

/// Enable GPIO pad hold during deep sleep (persists across all GPIOs).
pub fn deepSleepHoldEn() void {
    sys.gpio_deep_sleep_hold_en();
}

/// Disable GPIO pad hold during deep sleep.
pub fn deepSleepHoldDis() void {
    sys.gpio_deep_sleep_hold_dis();
}

/// Enable a GPIO pin as a deep-sleep wakeup source with the given trigger.
pub fn deepSleepWakeupEnable(gpio_num: GpioNum, intr_type: IntType) !void {
    try errors.espCheckError(sys.gpio_deep_sleep_wakeup_enable(numToC(gpio_num), @intFromEnum(intr_type)));
}

/// Disable a GPIO pin as a deep-sleep wakeup source.
pub fn deepSleepWakeupDisable(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_deep_sleep_wakeup_disable(numToC(gpio_num)));
}

// ---------------------------------------------------------------------------
// Sleep select
// ---------------------------------------------------------------------------

/// Enable sleep mode function for a GPIO pin.
pub fn sleepSelEn(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_sleep_sel_en(numToC(gpio_num)));
}

/// Disable sleep mode function for a GPIO pin.
pub fn sleepSelDis(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_sleep_sel_dis(numToC(gpio_num)));
}

// ---------------------------------------------------------------------------
// Wakeup
// ---------------------------------------------------------------------------

/// Enable GPIO wakeup from light sleep with the given trigger type.
pub fn wakeupEnable(gpio_num: GpioNum, intr_type: IntType) !void {
    try errors.espCheckError(sys.gpio_wakeup_enable(numToC(gpio_num), @intFromEnum(intr_type)));
}

/// Disable GPIO light-sleep wakeup.
pub fn wakeupDisable(gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_wakeup_disable(numToC(gpio_num)));
}

// ---------------------------------------------------------------------------
// IOMUX
// ---------------------------------------------------------------------------

/// Route an internal peripheral signal to a GPIO pad via the IO MUX.
pub fn iomuxIn(gpio_num: GpioNum, signal_idx: u32) void {
    sys.gpio_iomux_in(numToC(gpio_num), signal_idx);
}

/// Configure a GPIO pad as an IO MUX output for the given function.
pub fn iomuxOut(gpio_num: GpioNum, func: c_int, oen_inv: bool) void {
    sys.gpio_iomux_out(numToC(gpio_num), func, oen_inv);
}

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------

/// Dump the IO configuration of selected pins to a file stream.
pub fn dumpIOConfiguration(out_stream: ?*std.c.FILE, io_bit_mask: u64) !void {
    try errors.espCheckError(sys.gpio_dump_io_configuration(out_stream, io_bit_mask));
}

// ---------------------------------------------------------------------------
// ROM helpers
// ---------------------------------------------------------------------------

/// GPIO ROM helper functions (direct register / pad-level operations).
pub const ROM = struct {
    /// Select a pad for GPIO function via the IO MUX.
    pub fn padSelectGPIO(iopad_num: u32) void {
        sys.esp_rom_gpio_pad_select_gpio(iopad_num);
    }
    /// Enable pull-up only on a pad (ROM helper).
    pub fn padPullupOnly(iopad_num: u32) void {
        sys.esp_rom_gpio_pad_pullup_only(iopad_num);
    }
    /// Release pad hold (ROM helper).
    pub fn padUnhold(gpio_num: GpioNum) void {
        sys.esp_rom_gpio_pad_unhold(numToC(gpio_num));
    }
    /// Set drive strength on a pad (ROM helper).
    pub fn padSetDrive(iopad_num: u32, drv: u32) void {
        sys.esp_rom_gpio_pad_set_drv(iopad_num, drv);
    }
    /// Connect an input signal to a GPIO via the GPIO matrix (ROM helper).
    pub fn connectInSignal(gpio_num: GpioNum, signal_idx: u32, inv: bool) void {
        sys.esp_rom_gpio_connect_in_signal(numToC(gpio_num), signal_idx, inv);
    }
    /// Connect a GPIO to an output signal via the GPIO matrix (ROM helper).
    pub fn connectOutSignal(gpio_num: GpioNum, signal_idx: u32, out_inv: bool, oen_inv: bool) void {
        sys.esp_rom_gpio_connect_out_signal(numToC(gpio_num), signal_idx, out_inv, oen_inv);
    }
};

// ---------------------------------------------------------------------------
// ETM (Event Task Matrix)
// ---------------------------------------------------------------------------

/// Event Task Matrix (ETM) channel management for GPIO-triggered hardware events.
pub const ETM = struct {
    /// Create a new ETM channel.
    pub fn newChannel(cfg: [*c]const sys.esp_etm_channel_config_t, ret_chan: [*c]sys.esp_etm_channel_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_new_channel(cfg, ret_chan));
    }
    /// Delete an ETM channel.
    pub fn delChannel(chan: sys.esp_etm_channel_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_del_channel(chan));
    }
    /// Enable an ETM channel.
    pub fn channelEnable(chan: sys.esp_etm_channel_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_channel_enable(chan));
    }
    /// Disable an ETM channel.
    pub fn channelDisable(chan: sys.esp_etm_channel_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_channel_disable(chan));
    }
    /// Connect an event and task to an ETM channel.
    pub fn channelConnect(
        chan: sys.esp_etm_channel_handle_t,
        event: sys.esp_etm_event_handle_t,
        task: sys.esp_etm_task_handle_t,
    ) !void {
        try errors.espCheckError(sys.esp_etm_channel_connect(chan, event, task));
    }
    /// Delete an ETM event handle.
    pub fn delEvent(event: sys.esp_etm_event_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_del_event(event));
    }
    /// Delete an ETM task handle.
    pub fn delTask(task: sys.esp_etm_task_handle_t) !void {
        try errors.espCheckError(sys.esp_etm_del_task(task));
    }
    /// Dump ETM channel configuration to a file stream.
    pub fn dump(out_stream: ?*std.c.FILE) !void {
        try errors.espCheckError(sys.esp_etm_dump(out_stream));
    }
};

// ---------------------------------------------------------------------------
// GPIO ETM event/task binding
// ---------------------------------------------------------------------------

/// Create a new GPIO ETM event.
pub fn newEtmEvent(cfg: [*c]const sys.gpio_etm_event_config_t, ret_event: [*c]sys.esp_etm_event_handle_t) !void {
    try errors.espCheckError(sys.gpio_new_etm_event(cfg, ret_event));
}

/// Bind a GPIO pin to an existing ETM event.
pub fn etmEventBindGPIO(event: sys.esp_etm_event_handle_t, gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_etm_event_bind_gpio(event, numToC(gpio_num)));
}

/// Create a new GPIO ETM task.
pub fn newEtmTask(cfg: [*c]const sys.gpio_etm_task_config_t, ret_task: [*c]sys.esp_etm_task_handle_t) !void {
    try errors.espCheckError(sys.gpio_new_etm_task(cfg, ret_task));
}

/// Add a GPIO pin to an existing ETM task.
pub fn etmTaskAddGPIO(task: sys.esp_etm_task_handle_t, gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_etm_task_add_gpio(task, numToC(gpio_num)));
}

/// Remove a GPIO pin from an existing ETM task.
pub fn etmTaskRemoveGPIO(task: sys.esp_etm_task_handle_t, gpio_num: GpioNum) !void {
    try errors.espCheckError(sys.gpio_etm_task_rm_gpio(task, numToC(gpio_num)));
}
