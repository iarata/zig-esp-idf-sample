//! # Pulse Counter Wrapper (`pulse`)
//!
//! **What:** Zig wrapper for the ESP-IDF Pulse Counter (PCNT) peripheral,
//! which counts signal edges in hardware without CPU involvement.
//!
//! **What it does:**
//!   - **PulseCounter.Unit** — create, enable, start, stop, clear, get count,
//!     set glitch filter, add/remove watch points, register event callbacks.
//!   - **PulseCounter.Channel** — create a channel on a unit and configure
//!     edge/level actions (increment, decrement, hold) for each signal
//!     transition.
//!
//! **How:** Each function calls the corresponding `sys.pcnt_*` C function and
//! converts `esp_err_t` → Zig error.
//!
//! **When to use:**
//!   - Rotary encoder reading (quadrature decoding).
//!   - Frequency or event counting.
//!   - Any scenario where you need to count GPIO edges efficiently.
//!
//! **What it takes:**
//!   - `pcnt_unit_config_t` specifying count limits.
//!   - `pcnt_chan_config_t` specifying signal and control GPIOs.
//!   - Edge and level action enums to configure counting behaviour.
//!
//! **Example:**
//! ```zig
//! const pcnt = idf.pulse;
//! var unit: sys.pcnt_unit_handle_t = null;
//! try pcnt.PulseCounter.Unit.init(&.{ .low_limit = -100, .high_limit = 100 }, &unit);
//!
//! var chan: sys.pcnt_channel_handle_t = null;
//! try pcnt.PulseCounter.Channel.init(unit, &.{
//!     .edge_gpio_num = 4,
//!     .level_gpio_num = 5,
//! }, &chan);
//!
//! try pcnt.PulseCounter.Unit.enable(unit);
//! try pcnt.PulseCounter.Unit.start(unit);
//! var count: c_int = 0;
//! try pcnt.PulseCounter.Unit.getCount(unit, &count);
//! ```

const sys = @import("sys");
const errors = @import("error");

/// Hardware pulse counter peripheral wrapper.
///
/// Provides `Unit` (counter instance) and `Channel` (signal input)
/// abstractions for the PCNT hardware.
pub const PulseCounter = struct {
    /// Watch-point event payload type.
    pub const watchEventData_t = sys.pcnt_watch_event_data_t;
    /// Callback function table for PCNT events.
    pub const eventCallbacks_t = sys.pcnt_event_callbacks_t;
    /// Glitch filter configuration.
    pub const glitchFilterConfig_t = sys.pcnt_glitch_filter_config_t;

    /// A single PCNT counting unit.
    pub const Unit = struct {
        pub const config_t = sys.pcnt_unit_config_t;
        pub const handle_t = sys.pcnt_unit_handle_t;

        /// Allocate and configure a new PCNT unit.
        pub fn init(config: ?*const sys.pcnt_unit_config_t, unit: ?*sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_new_unit(config, unit));
        }
        /// Delete a PCNT unit and free its resources.
        pub fn del(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_del_unit(unit));
        }
        /// Enable a PCNT unit so it can start counting.
        pub fn enable(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_enable(unit));
        }
        /// Disable a PCNT unit.
        pub fn disable(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_disable(unit));
        }
        /// Start the PCNT unit's counting.
        pub fn start(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_start(unit));
        }
        /// Stop the PCNT unit's counting.
        pub fn stop(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_stop(unit));
        }
        /// Clear (reset to zero) the PCNT unit's internal count.
        pub fn clear(unit: sys.pcnt_unit_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_clear_count(unit));
        }
        /// Set the glitch filter for the PCNT unit to ignore short pulses.
        pub fn setGlitchFilter(unit: sys.pcnt_unit_handle_t, config: ?*const sys.pcnt_glitch_filter_config_t) !void {
            return try errors.espCheckError(sys.pcnt_unit_set_glitch_filter(unit, config));
        }
        /// Read the current accumulated count value.
        pub fn getCount(unit: sys.pcnt_unit_handle_t, value: ?*c_int) !void {
            return try errors.espCheckError(sys.pcnt_unit_get_count(unit, value));
        }
        /// Register event callbacks for watch-point hits.
        pub fn registerEventCallbacks(unit: sys.pcnt_unit_handle_t, cbs: ?*const sys.pcnt_event_callbacks_t, user_data: ?*anyopaque) !void {
            return try errors.espCheckError(sys.pcnt_unit_register_event_callbacks(unit, cbs, user_data));
        }
        /// Add a watch point that triggers an event at a specific count value.
        pub fn addWatchPoint(unit: sys.pcnt_unit_handle_t, watch_point: c_int) !void {
            return try errors.espCheckError(sys.pcnt_unit_add_watch_point(unit, watch_point));
        }
        /// Remove a previously added watch point.
        pub fn removeWatchPoint(unit: sys.pcnt_unit_handle_t, watch_point: c_int) !void {
            return try errors.espCheckError(sys.pcnt_unit_remove_watch_point(unit, watch_point));
        }
    };
    /// A signal input channel attached to a PCNT unit.
    pub const Channel = struct {
        pub const handle_t = sys.pcnt_channel_handle_t;
        pub const config_t = sys.pcnt_chan_config_t;
        pub const edgeAction_t = sys.pcnt_channel_edge_action_t;
        pub const level_t = sys.pcnt_channel_level_t;

        /// Create a new channel on the given PCNT unit.
        pub fn init(unit: sys.pcnt_unit_handle_t, config: ?*const sys.pcnt_chan_config_t, chan: ?*sys.pcnt_channel_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_new_channel(unit, config, chan));
        }
        /// Delete a PCNT channel.
        pub fn del(chan: sys.pcnt_channel_handle_t) !void {
            return try errors.espCheckError(sys.pcnt_del_channel(chan));
        }
        /// Edge and level action configuration helpers.
        const set = struct {
            /// Configure how the channel reacts to signal edges.
            pub fn edgeAction(chan: sys.pcnt_channel_handle_t, pos_act: sys.pcnt_channel_edge_action_t, neg_act: sys.pcnt_channel_edge_action_t) !void {
                return try errors.espCheckError(sys.pcnt_channel_set_edge_action(chan, pos_act, neg_act));
            }
            /// Configure how the channel reacts to the control signal level.
            pub fn levelAction(chan: sys.pcnt_channel_handle_t, high_act: sys.pcnt_channel_level_action_t, low_act: sys.pcnt_channel_level_action_t) !void {
                return try errors.espCheckError(sys.pcnt_channel_set_edge_action(chan, high_act, low_act));
            }
        };
    };
};
