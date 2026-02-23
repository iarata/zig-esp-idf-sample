//! # MQTT & Transport-Layer Bindings (`mqtt`)
//!
//! **What:** Raw Zig bindings for the ESP-IDF MQTT client library and the
//! underlying TCP transport layer.  Includes all type definitions, event
//! structs, and extern function declarations needed to build, configure,
//! and drive an MQTT client entirely from Zig.
//!
//! **What it does:**
//!   - **Transport types** — `esp_transport_handle_t`, keep-alive config,
//!     connect/read/write/close function pointers.
//!   - **MQTT client types** — `esp_mqtt_client_handle_t`, event IDs,
//!     error codes, protocol versions, QoS, retain flags, transport mode.
//!   - **MQTT config struct** — `esp_mqtt_client_config_t` (broker address
//!     & TLS, credentials, session/LWT, network reconnect, task/buffer sizes).
//!   - **Transport API** — `esp_transport_init/connect/read/write/close/destroy`.
//!   - **MQTT client API** — `esp_mqtt_client_init/start/stop/subscribe/
//!     publish/destroy` (declared as `extern fn`).
//!
//! **How:** The types are `extern struct` / `extern union` / `enum` that map
//! 1:1 to the C headers, with Zig-safe defaults (`std.mem.zeroes`).  The
//! extern function declarations let the linker resolve against the ESP-IDF
//! MQTT component.
//!
//! **When to use:** IoT telemetry, command channels, or any publish/subscribe
//! messaging scenario over TCP/TLS/WebSocket.
//!
//! **What it takes:**
//!   - An `esp_mqtt_client_config_t` struct with broker URI, credentials,
//!     TLS settings, and optional LWT.
//!   - An event handler callback to process connect/disconnect/data events.
//!
//! **Example:**
//! ```zig
//! const mqtt = idf.mqtt;
//! const cfg: mqtt.esp_mqtt_client_config_t = .{
//!     .broker = .{ .address = .{ .uri = "mqtt://broker.local" } },
//! };
//! const client = mqtt.esp_mqtt_client_init(&cfg);
//! _ = mqtt.esp_mqtt_client_start(client);
//! ```

const std = @import("std");
const sys = @import("sys");

/// TCP keep-alive configuration for transport connections.
pub const esp_transport_keepalive = extern struct {
    keep_alive_enable: bool = std.mem.zeroes(bool),
    keep_alive_idle: c_int = std.mem.zeroes(c_int),
    keep_alive_interval: c_int = std.mem.zeroes(c_int),
    keep_alive_count: c_int = std.mem.zeroes(c_int),
};
/// Alias for `esp_transport_keepalive`.
pub const esp_transport_keep_alive_t = esp_transport_keepalive;
/// Opaque handle for a list of transports (one per URI scheme).
pub const esp_transport_list_t = opaque {};
/// Nullable handle to a transport list.
pub const esp_transport_list_handle_t = ?*esp_transport_list_t;
/// Opaque handle for an individual transport (TCP, SSL, WebSocket, etc.).
pub const esp_transport_item_t = opaque {};
/// Nullable handle to a transport.
pub const esp_transport_handle_t = ?*esp_transport_item_t;
/// Connect function pointer type: `(transport, host, port, timeout_ms) -> result`.
pub const connect_func = ?*const fn (esp_transport_handle_t, [*:0]const u8, c_int, c_int) callconv(.C) c_int;
/// Write/I/O function pointer type: `(transport, buffer, len, timeout_ms) -> bytes_written`.
pub const io_func = ?*const fn (esp_transport_handle_t, [*:0]const u8, c_int, c_int) callconv(.C) c_int;
/// Read function pointer type: `(transport, buffer, len, timeout_ms) -> bytes_read`.
pub const io_read_func = ?*const fn (esp_transport_handle_t, [*:0]u8, c_int, c_int) callconv(.C) c_int;
/// Simple transport function pointer type (close, destroy): `(transport) -> result`.
pub const trans_func = ?*const fn (esp_transport_handle_t) callconv(.C) c_int;
/// Poll function pointer type: `(transport, timeout_ms) -> ready`.
pub const poll_func = ?*const fn (esp_transport_handle_t, c_int) callconv(.C) c_int;
/// Async connect function pointer type: `(transport, host, port, timeout_ms) -> result`.
pub const connect_async_func = ?*const fn (esp_transport_handle_t, [*:0]const u8, c_int, c_int) callconv(.C) c_int;
/// Function pointer that returns the parent/payload transport handle.
pub const payload_transfer_func = ?*const fn (esp_transport_handle_t) callconv(.C) esp_transport_handle_t;
/// Opaque TLS error details handle.
pub const esp_tls_last_error = opaque {};
/// Nullable handle to TLS error details.
pub const esp_tls_error_handle_t = ?*esp_tls_last_error;
/// TCP transport error codes.
pub const esp_tcp_transport_err_t = enum(c_int) {
    ERR_TCP_TRANSPORT_NO_MEM = -3,
    ERR_TCP_TRANSPORT_CONNECTION_FAILED = -2,
    ERR_TCP_TRANSPORT_CONNECTION_CLOSED_BY_FIN = -1,
    ERR_TCP_TRANSPORT_CONNECTION_TIMEOUT = 0,
};
/// Create a new empty transport list.
pub extern fn esp_transport_list_init() esp_transport_list_handle_t;
/// Destroy a transport list and all its transports.
pub extern fn esp_transport_list_destroy(list: esp_transport_list_handle_t) sys.esp_err_t;
/// Add a transport to a list, associated with a URI scheme (e.g. "tcp", "ssl").
pub extern fn esp_transport_list_add(list: esp_transport_list_handle_t, t: esp_transport_handle_t, scheme: [*:0]const u8) sys.esp_err_t;
/// Remove all transports from a list.
pub extern fn esp_transport_list_clean(list: esp_transport_list_handle_t) sys.esp_err_t;
/// Look up a transport in a list by URI scheme.
pub extern fn esp_transport_list_get_transport(list: esp_transport_list_handle_t, scheme: [*:0]const u8) esp_transport_handle_t;
/// Allocate and initialize a new transport.
pub extern fn esp_transport_init() esp_transport_handle_t;
/// Destroy a transport and free its resources.
pub extern fn esp_transport_destroy(t: esp_transport_handle_t) sys.esp_err_t;
/// Get the default port for a transport.
pub extern fn esp_transport_get_default_port(t: esp_transport_handle_t) c_int;
/// Set the default port for a transport.
pub extern fn esp_transport_set_default_port(t: esp_transport_handle_t, port: c_int) sys.esp_err_t;
/// Connect a transport to the given host and port (blocking, with timeout in ms).
pub extern fn esp_transport_connect(t: esp_transport_handle_t, host: [*:0]const u8, port: c_int, timeout_ms: c_int) c_int;
/// Begin an asynchronous connection to the given host and port.
pub extern fn esp_transport_connect_async(t: esp_transport_handle_t, host: [*:0]const u8, port: c_int, timeout_ms: c_int) c_int;
/// Read data from a connected transport into a buffer.
pub extern fn esp_transport_read(t: esp_transport_handle_t, buffer: [*:0]u8, len: c_int, timeout_ms: c_int) c_int;
/// Poll a transport for read readiness.
pub extern fn esp_transport_poll_read(t: esp_transport_handle_t, timeout_ms: c_int) c_int;
/// Write data to a connected transport.
pub extern fn esp_transport_write(t: esp_transport_handle_t, buffer: [*:0]const u8, len: c_int, timeout_ms: c_int) c_int;
/// Poll a transport for write readiness.
pub extern fn esp_transport_poll_write(t: esp_transport_handle_t, timeout_ms: c_int) c_int;
/// Close a transport connection.
pub extern fn esp_transport_close(t: esp_transport_handle_t) c_int;
/// Get transport-specific context data.
pub extern fn esp_transport_get_context_data(t: esp_transport_handle_t) ?*anyopaque;
/// Get the underlying payload/parent transport handle.
pub extern fn esp_transport_get_payload_transport_handle(t: esp_transport_handle_t) esp_transport_handle_t;
/// Set transport-specific context data.
pub extern fn esp_transport_set_context_data(t: esp_transport_handle_t, data: ?*anyopaque) sys.esp_err_t;
/// Register all I/O callback functions for a custom transport.
pub extern fn esp_transport_set_func(t: esp_transport_handle_t, _connect: connect_func, _read: io_read_func, _write: io_func, _close: trans_func, _poll_read: poll_func, _poll_write: poll_func, _destroy: trans_func) sys.esp_err_t;
/// Set the async connect function for a transport.
pub extern fn esp_transport_set_async_connect_func(t: esp_transport_handle_t, _connect_async_func: connect_async_func) sys.esp_err_t;
/// Set the parent transport discovery function for layered transports.
pub extern fn esp_transport_set_parent_transport_func(t: esp_transport_handle_t, _parent_transport: payload_transfer_func) sys.esp_err_t;
/// Get the TLS error handle from a transport for detailed error inspection.
pub extern fn esp_transport_get_error_handle(t: esp_transport_handle_t) esp_tls_error_handle_t;
/// Get the underlying socket errno from a transport.
pub extern fn esp_transport_get_errno(t: esp_transport_handle_t) c_int;
/// Translate a TCP transport error code to an ESP-IDF `esp_err_t`.
pub extern fn esp_transport_translate_error(@"error": esp_tcp_transport_err_t) sys.esp_err_t;
/// Opaque MQTT client instance.
pub const esp_mqtt_client = opaque {};
/// Nullable handle to an MQTT client.
pub const esp_mqtt_client_handle_t = ?*esp_mqtt_client;
/// MQTT event identifiers delivered to the event handler callback.
pub const esp_mqtt_event_id_t = enum(c_int) {
    /// Wildcard: register for all events.
    MQTT_EVENT_ANY = -1,
    /// An error occurred (check `error_handle` in the event).
    MQTT_EVENT_ERROR = 0,
    /// Successfully connected to the broker.
    MQTT_EVENT_CONNECTED = 1,
    /// Disconnected from the broker.
    MQTT_EVENT_DISCONNECTED = 2,
    /// Subscription acknowledged by the broker.
    MQTT_EVENT_SUBSCRIBED = 3,
    /// Unsubscription acknowledged by the broker.
    MQTT_EVENT_UNSUBSCRIBED = 4,
    /// Publish acknowledged by the broker (QoS 1/2).
    MQTT_EVENT_PUBLISHED = 5,
    /// Incoming publish data received.
    MQTT_EVENT_DATA = 6,
    /// About to connect — can modify config.
    MQTT_EVENT_BEFORE_CONNECT = 7,
    /// A queued outbox message was deleted.
    MQTT_EVENT_DELETED = 8,
    /// User-dispatched custom event.
    MQTT_USER_EVENT = 9,
};
/// CONNACK return codes from the MQTT broker.
pub const esp_mqtt_connect_return_code_t = enum(c_uint) {
    MQTT_CONNECTION_ACCEPTED = 0,
    MQTT_CONNECTION_REFUSE_PROTOCOL = 1,
    MQTT_CONNECTION_REFUSE_ID_REJECTED = 2,
    MQTT_CONNECTION_REFUSE_SERVER_UNAVAILABLE = 3,
    MQTT_CONNECTION_REFUSE_BAD_USERNAME = 4,
    MQTT_CONNECTION_REFUSE_NOT_AUTHORIZED = 5,
};
/// Classification of MQTT error sources.
pub const esp_mqtt_error_type_t = enum(c_uint) {
    MQTT_ERROR_TYPE_NONE = 0,
    MQTT_ERROR_TYPE_TCP_TRANSPORT = 1,
    MQTT_ERROR_TYPE_CONNECTION_REFUSED = 2,
    MQTT_ERROR_TYPE_SUBSCRIBE_FAILED = 3,
};
/// Underlying transport protocol for the MQTT connection.
pub const esp_mqtt_transport_t = enum(c_uint) {
    MQTT_TRANSPORT_UNKNOWN = 0,
    MQTT_TRANSPORT_OVER_TCP = 1,
    MQTT_TRANSPORT_OVER_SSL = 2,
    MQTT_TRANSPORT_OVER_WS = 3,
    MQTT_TRANSPORT_OVER_WSS = 4,
};
/// MQTT protocol version selector.
pub const esp_mqtt_protocol_ver_t = enum(c_uint) {
    MQTT_PROTOCOL_UNDEFINED = 0,
    MQTT_PROTOCOL_V_3_1 = 1,
    MQTT_PROTOCOL_V_3_1_1 = 2,
    MQTT_PROTOCOL_V_5 = 3,
};
/// Detailed error information reported with `MQTT_EVENT_ERROR` events.
pub const esp_mqtt_error_codes = extern struct {
    esp_tls_last_esp_err: sys.esp_err_t = std.mem.zeroes(sys.esp_err_t),
    esp_tls_stack_err: c_int = std.mem.zeroes(c_int),
    esp_tls_cert_verify_flags: c_int = std.mem.zeroes(c_int),
    error_type: esp_mqtt_error_type_t = .MQTT_ERROR_TYPE_NONE,
    connect_return_code: esp_mqtt_connect_return_code_t = std.mem.zeroes(esp_mqtt_connect_return_code_t),
    esp_transport_sock_errno: c_int = std.mem.zeroes(c_int),
};
/// Alias for `esp_mqtt_error_codes`.
pub const esp_mqtt_error_codes_t = esp_mqtt_error_codes;
/// MQTT event structure passed to the event handler callback.
/// Contains event type, client handle, topic/data payload, message ID, QoS, and error details.
pub const esp_mqtt_event_t = extern struct {
    event_id: esp_mqtt_event_id_t = std.mem.zeroes(esp_mqtt_event_id_t),
    client: esp_mqtt_client_handle_t = std.mem.zeroes(esp_mqtt_client_handle_t),
    data: [*:0]u8 = std.mem.zeroes([*:0]u8),
    data_len: c_int = std.mem.zeroes(c_int),
    total_data_len: c_int = std.mem.zeroes(c_int),
    current_data_offset: c_int = std.mem.zeroes(c_int),
    topic: [*:0]u8 = std.mem.zeroes([*:0]u8),
    topic_len: c_int = std.mem.zeroes(c_int),
    msg_id: c_int = std.mem.zeroes(c_int),
    session_present: c_int = std.mem.zeroes(c_int),
    error_handle: [*c]esp_mqtt_error_codes_t = std.mem.zeroes([*c]esp_mqtt_error_codes_t),
    retain: bool = std.mem.zeroes(bool),
    qos: c_int = std.mem.zeroes(c_int),
    dup: bool = std.mem.zeroes(bool),
    protocol_ver: esp_mqtt_protocol_ver_t = std.mem.zeroes(esp_mqtt_protocol_ver_t),
};
/// Pointer to an MQTT event (used as callback parameter type).
pub const esp_mqtt_event_handle_t = [*c]esp_mqtt_event_t;
/// Broker address configuration: URI, hostname, transport type, path, and port.
pub const address_t_5 = extern struct {
    uri: [*:0]const u8 = "",
    hostname: [*:0]const u8 = "",
    transport: esp_mqtt_transport_t = std.mem.zeroes(esp_mqtt_transport_t),
    path: [*:0]const u8 = "",
    port: u32 = std.mem.zeroes(u32),
};
pub const psk_key_hint_7 = opaque {};
/// TLS/certificate verification settings for the broker connection.
pub const verification_t_6 = extern struct {
    use_global_ca_store: bool = false,
    crt_bundle_attach: ?*const fn (?*anyopaque) callconv(.C) sys.esp_err_t = null,
    certificate: [*:0]const u8 = "",
    certificate_len: usize = std.mem.zeroes(usize),
    psk_hint_key: ?*const psk_key_hint_7 = std.mem.zeroes(?*const psk_key_hint_7),
    skip_cert_common_name_check: bool = std.mem.zeroes(bool),
    alpn_protos: [*c][*c]const u8 = std.mem.zeroes([*c][*c]const u8),
    common_name: [*:0]const u8 = "",
};
/// Broker configuration combining address and TLS verification settings.
pub const broker_t_4 = extern struct {
    address: address_t_5 = std.mem.zeroes(address_t_5),
    verification: verification_t_6 = std.mem.zeroes(verification_t_6),
};
/// Client authentication credentials: client certificate, private key, and password.
pub const authentication_t_9 = extern struct {
    password: [*:0]const u8 = "",
    certificate: [*:0]const u8 = "",
    certificate_len: usize = std.mem.zeroes(usize),
    key: [*:0]const u8 = "",
    key_len: usize = std.mem.zeroes(usize),
    key_password: [*:0]const u8 = "",
    key_password_len: c_int = std.mem.zeroes(c_int),
    use_secure_element: bool = std.mem.zeroes(bool),
    ds_data: ?*anyopaque = std.mem.zeroes(?*anyopaque),
};
/// Client credentials: username, client ID, and mutual-TLS authentication.
pub const credentials_t_8 = extern struct {
    username: [*:0]const u8 = "",
    client_id: [*:0]const u8 = "",
    set_null_client_id: bool = std.mem.zeroes(bool),
    authentication: authentication_t_9 = std.mem.zeroes(authentication_t_9),
};
/// Last Will and Testament (LWT) message published by the broker when the client disconnects unexpectedly.
pub const last_will_t_11 = extern struct {
    topic: [*:0]const u8 = "",
    msg: [*:0]const u8 = "",
    msg_len: c_int = std.mem.zeroes(c_int),
    qos: c_int = std.mem.zeroes(c_int),
    retain: c_int = std.mem.zeroes(c_int),
};
/// MQTT session settings: LWT, clean session, keep-alive, protocol version, and retransmit timeout.
pub const session_t_10 = extern struct {
    last_will: last_will_t_11 = std.mem.zeroes(last_will_t_11),
    disable_clean_session: bool = std.mem.zeroes(bool),
    keepalive: c_int = std.mem.zeroes(c_int),
    disable_keepalive: bool = std.mem.zeroes(bool),
    protocol_ver: esp_mqtt_protocol_ver_t = std.mem.zeroes(esp_mqtt_protocol_ver_t),
    message_retransmit_timeout: c_int = std.mem.zeroes(c_int),
};
pub const ifreq_13 = opaque {};
/// Network/reconnection settings: timeouts, auto-reconnect, custom transport, and interface binding.
pub const network_t_12 = extern struct {
    reconnect_timeout_ms: c_int = std.mem.zeroes(c_int),
    timeout_ms: c_int = std.mem.zeroes(c_int),
    refresh_connection_after_ms: c_int = std.mem.zeroes(c_int),
    disable_auto_reconnect: bool = std.mem.zeroes(bool),
    transport: esp_transport_handle_t = std.mem.zeroes(esp_transport_handle_t),
    if_name: ?*ifreq_13 = std.mem.zeroes(?*ifreq_13),
};
/// FreeRTOS task configuration for the MQTT client task.
pub const task_t_14 = extern struct {
    priority: c_int = std.mem.zeroes(c_int),
    stack_size: c_int = std.mem.zeroes(c_int),
};
/// Buffer sizes for incoming and outgoing MQTT messages.
pub const buffer_t_15 = extern struct {
    size: c_int = std.mem.zeroes(c_int),
    out_size: c_int = std.mem.zeroes(c_int),
};
/// Outbox (offline message queue) configuration.
pub const outbox_config_t_16 = extern struct {
    limit: u64 = std.mem.zeroes(u64),
};
/// Complete MQTT client configuration combining broker, credentials, session,
/// network, task, buffer, and outbox settings.
pub const esp_mqtt_client_config_t = extern struct {
    broker: broker_t_4 = std.mem.zeroes(broker_t_4),
    credentials: credentials_t_8 = std.mem.zeroes(credentials_t_8),
    session: session_t_10 = std.mem.zeroes(session_t_10),
    network: network_t_12 = std.mem.zeroes(network_t_12),
    task: task_t_14 = std.mem.zeroes(task_t_14),
    buffer: buffer_t_15 = std.mem.zeroes(buffer_t_15),
    outbox: outbox_config_t_16 = std.mem.zeroes(outbox_config_t_16),
};
/// Topic filter with associated QoS level, used for batch subscribe operations.
pub const topic_t = extern struct {
    filter: [*:0]const u8 = "",
    qos: c_int = std.mem.zeroes(c_int),
};
/// Alias for `topic_t`.
pub const esp_mqtt_topic_t = topic_t;
/// Create and initialize a new MQTT client from the given configuration.
pub extern fn esp_mqtt_client_init(config: [*c]const esp_mqtt_client_config_t) esp_mqtt_client_handle_t;
/// Update the broker URI on an existing MQTT client.
pub extern fn esp_mqtt_client_set_uri(client: esp_mqtt_client_handle_t, uri: [*:0]const u8) sys.esp_err_t;
/// Start the MQTT client (connects to the broker in a background task).
pub extern fn esp_mqtt_client_start(client: esp_mqtt_client_handle_t) sys.esp_err_t;
/// Force a reconnection attempt.
pub extern fn esp_mqtt_client_reconnect(client: esp_mqtt_client_handle_t) sys.esp_err_t;
/// Gracefully disconnect from the broker.
pub extern fn esp_mqtt_client_disconnect(client: esp_mqtt_client_handle_t) sys.esp_err_t;
/// Stop the MQTT client task and disconnect.
pub extern fn esp_mqtt_client_stop(client: esp_mqtt_client_handle_t) sys.esp_err_t;
/// Subscribe to a single topic with the given QoS. Returns message ID or -1 on error.
pub extern fn esp_mqtt_client_subscribe_single(client: esp_mqtt_client_handle_t, topic: [*:0]const u8, qos: c_int) c_int;
/// Subscribe to multiple topics at once. Returns message ID or -1 on error.
pub extern fn esp_mqtt_client_subscribe_multiple(client: esp_mqtt_client_handle_t, topic_list: [*c]const esp_mqtt_topic_t, size: c_int) c_int;
/// Unsubscribe from a topic. Returns message ID or -1 on error.
pub extern fn esp_mqtt_client_unsubscribe(client: esp_mqtt_client_handle_t, topic: [*:0]const u8) c_int;
/// Publish a message to a topic. Returns message ID or -1 on error.
pub extern fn esp_mqtt_client_publish(client: esp_mqtt_client_handle_t, topic: [*:0]const u8, data: [*:0]const u8, len: c_int, qos: c_int, retain: c_int) c_int;
/// Enqueue a message for later publishing (stored in the outbox). Returns message ID or -1 on error.
pub extern fn esp_mqtt_client_enqueue(client: esp_mqtt_client_handle_t, topic: [*:0]const u8, data: [*:0]const u8, len: c_int, qos: c_int, retain: c_int, store: bool) c_int;
/// Destroy an MQTT client and free all associated resources.
pub extern fn esp_mqtt_client_destroy(client: esp_mqtt_client_handle_t) sys.esp_err_t;
/// Apply a new configuration to an existing MQTT client.
pub extern fn esp_mqtt_set_config(client: esp_mqtt_client_handle_t, config: [*c]const esp_mqtt_client_config_t) sys.esp_err_t;
/// Register an event handler for a specific MQTT event type.
pub extern fn esp_mqtt_client_register_event(client: esp_mqtt_client_handle_t, event: esp_mqtt_event_id_t, event_handler: sys.esp_event_handler_t, event_handler_arg: ?*anyopaque) sys.esp_err_t;
/// Unregister a previously registered event handler.
pub extern fn esp_mqtt_client_unregister_event(client: esp_mqtt_client_handle_t, event: esp_mqtt_event_id_t, event_handler: sys.esp_event_handler_t) sys.esp_err_t;
/// Get the current size of the outbox (queued messages in bytes).
pub extern fn esp_mqtt_client_get_outbox_size(client: esp_mqtt_client_handle_t) c_int;
/// Dispatch a custom user event through the MQTT event loop.
pub extern fn esp_mqtt_dispatch_custom_event(client: esp_mqtt_client_handle_t, event: [*c]esp_mqtt_event_t) sys.esp_err_t;
/// MQTT 5.0 client handle (same opaque type as MQTT 3.x).
pub const esp_mqtt5_client_handle_t = ?*esp_mqtt_client;
/// MQTT 5.0 reason codes used in CONNACK, DISCONNECT, and other control packets.
pub const mqtt5_error_reason_code = enum(c_uint) {
    MQTT5_UNSPECIFIED_ERROR = 128,
    MQTT5_MALFORMED_PACKET = 129,
    MQTT5_PROTOCOL_ERROR = 130,
    MQTT5_IMPLEMENT_SPECIFIC_ERROR = 131,
    MQTT5_UNSUPPORTED_PROTOCOL_VER = 132,
    MQTT5_INVAILD_CLIENT_ID = 133,
    MQTT5_INVALID_CLIENT_ID = 133,
    MQTT5_BAD_USERNAME_OR_PWD = 134,
    MQTT5_NOT_AUTHORIZED = 135,
    MQTT5_SERVER_UNAVAILABLE = 136,
    MQTT5_SERVER_BUSY = 137,
    MQTT5_BANNED = 138,
    MQTT5_SERVER_SHUTTING_DOWN = 139,
    MQTT5_BAD_AUTH_METHOD = 140,
    MQTT5_KEEP_ALIVE_TIMEOUT = 141,
    MQTT5_SESSION_TAKEN_OVER = 142,
    MQTT5_TOPIC_FILTER_INVAILD = 143,
    MQTT5_TOPIC_FILTER_INVALID = 143,
    MQTT5_TOPIC_NAME_INVAILD = 144,
    MQTT5_TOPIC_NAME_INVALID = 144,
    MQTT5_PACKET_IDENTIFIER_IN_USE = 145,
    MQTT5_PACKET_IDENTIFIER_NOT_FOUND = 146,
    MQTT5_RECEIVE_MAXIMUM_EXCEEDED = 147,
    MQTT5_TOPIC_ALIAS_INVAILD = 148,
    MQTT5_TOPIC_ALIAS_INVALID = 148,
    MQTT5_PACKET_TOO_LARGE = 149,
    MQTT5_MESSAGE_RATE_TOO_HIGH = 150,
    MQTT5_QUOTA_EXCEEDED = 151,
    MQTT5_ADMINISTRATIVE_ACTION = 152,
    MQTT5_PAYLOAD_FORMAT_INVAILD = 153,
    MQTT5_PAYLOAD_FORMAT_INVALID = 153,
    MQTT5_RETAIN_NOT_SUPPORT = 154,
    MQTT5_QOS_NOT_SUPPORT = 155,
    MQTT5_USE_ANOTHER_SERVER = 156,
    MQTT5_SERVER_MOVED = 157,
    MQTT5_SHARED_SUBSCR_NOT_SUPPORTED = 158,
    MQTT5_CONNECTION_RATE_EXCEEDED = 159,
    MQTT5_MAXIMUM_CONNECT_TIME = 160,
    MQTT5_SUBSCRIBE_IDENTIFIER_NOT_SUPPORT = 161,
    MQTT5_WILDCARD_SUBSCRIBE_NOT_SUPPORT = 162,
};
/// Opaque list of MQTT 5.0 user properties (key-value pairs).
pub const mqtt5_user_property_list_t = opaque {};
/// Nullable handle to an MQTT 5.0 user property list.
pub const mqtt5_user_property_handle_t = ?*mqtt5_user_property_list_t;
/// MQTT 5.0 CONNECT packet property configuration (session expiry, will delay, etc.).
pub const esp_mqtt5_connection_property_config_t = extern struct {
    session_expiry_interval: u32 = std.mem.zeroes(u32),
    maximum_packet_size: u32 = std.mem.zeroes(u32),
    receive_maximum: u16 = std.mem.zeroes(u16),
    topic_alias_maximum: u16 = std.mem.zeroes(u16),
    request_resp_info: bool = std.mem.zeroes(bool),
    request_problem_info: bool = std.mem.zeroes(bool),
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
    will_delay_interval: u32 = std.mem.zeroes(u32),
    message_expiry_interval: u32 = std.mem.zeroes(u32),
    payload_format_indicator: bool = std.mem.zeroes(bool),
    content_type: [*:0]const u8 = "",
    response_topic: [*:0]const u8 = "",
    correlation_data: [*:0]const u8 = "",
    correlation_data_len: u16 = std.mem.zeroes(u16),
    will_user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// MQTT 5.0 PUBLISH packet property configuration (topic alias, expiry, correlation data, etc.).
pub const esp_mqtt5_publish_property_config_t = extern struct {
    payload_format_indicator: bool = std.mem.zeroes(bool),
    message_expiry_interval: u32 = std.mem.zeroes(u32),
    topic_alias: u16 = std.mem.zeroes(u16),
    response_topic: [*:0]const u8 = "",
    correlation_data: [*:0]const u8 = "",
    correlation_data_len: u16 = std.mem.zeroes(u16),
    content_type: [*:0]const u8 = "",
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// MQTT 5.0 SUBSCRIBE packet property configuration (subscription ID, shared subscriptions, etc.).
pub const esp_mqtt5_subscribe_property_config_t = extern struct {
    subscribe_id: u16 = std.mem.zeroes(u16),
    no_local_flag: bool = std.mem.zeroes(bool),
    retain_as_published_flag: bool = std.mem.zeroes(bool),
    retain_handle: u8 = std.mem.zeroes(u8),
    is_share_subscribe: bool = std.mem.zeroes(bool),
    share_name: [*:0]const u8 = "",
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// MQTT 5.0 UNSUBSCRIBE packet property configuration.
pub const esp_mqtt5_unsubscribe_property_config_t = extern struct {
    is_share_subscribe: bool = std.mem.zeroes(bool),
    share_name: [*:0]const u8 = "",
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// MQTT 5.0 DISCONNECT packet property configuration.
pub const esp_mqtt5_disconnect_property_config_t = extern struct {
    session_expiry_interval: u32 = std.mem.zeroes(u32),
    disconnect_reason: u8 = std.mem.zeroes(u8),
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// MQTT 5.0 event properties received with incoming events.
pub const esp_mqtt5_event_property_t = extern struct {
    payload_format_indicator: bool = std.mem.zeroes(bool),
    response_topic: [*:0]u8 = std.mem.zeroes([*:0]u8),
    response_topic_len: c_int = std.mem.zeroes(c_int),
    correlation_data: [*:0]u8 = std.mem.zeroes([*:0]u8),
    correlation_data_len: u16 = std.mem.zeroes(u16),
    content_type: [*:0]u8 = std.mem.zeroes([*:0]u8),
    content_type_len: c_int = std.mem.zeroes(c_int),
    subscribe_id: u16 = std.mem.zeroes(u16),
    user_property: mqtt5_user_property_handle_t = std.mem.zeroes(mqtt5_user_property_handle_t),
};
/// Key-value pair for MQTT 5.0 user properties.
pub const esp_mqtt5_user_property_item_t = extern struct {
    key: [*:0]const u8 = "",
    value: [*:0]const u8 = "",
};
/// Set MQTT 5.0 CONNECT properties on a client.
pub extern fn esp_mqtt5_client_set_connect_property(client: esp_mqtt5_client_handle_t, connect_property: [*c]const esp_mqtt5_connection_property_config_t) sys.esp_err_t;
/// Set MQTT 5.0 PUBLISH properties for the next publish operation.
pub extern fn esp_mqtt5_client_set_publish_property(client: esp_mqtt5_client_handle_t, property: [*c]const esp_mqtt5_publish_property_config_t) sys.esp_err_t;
/// Set MQTT 5.0 SUBSCRIBE properties for the next subscribe operation.
pub extern fn esp_mqtt5_client_set_subscribe_property(client: esp_mqtt5_client_handle_t, property: [*c]const esp_mqtt5_subscribe_property_config_t) sys.esp_err_t;
/// Set MQTT 5.0 UNSUBSCRIBE properties for the next unsubscribe operation.
pub extern fn esp_mqtt5_client_set_unsubscribe_property(client: esp_mqtt5_client_handle_t, property: [*c]const esp_mqtt5_unsubscribe_property_config_t) sys.esp_err_t;
/// Set MQTT 5.0 DISCONNECT properties.
pub extern fn esp_mqtt5_client_set_disconnect_property(client: esp_mqtt5_client_handle_t, property: [*c]const esp_mqtt5_disconnect_property_config_t) sys.esp_err_t;
/// Set user property key-value pairs on a user property handle.
pub extern fn esp_mqtt5_client_set_user_property(user_property: [*c]mqtt5_user_property_handle_t, item: [*c]esp_mqtt5_user_property_item_t, item_num: u8) sys.esp_err_t;
/// Get user property key-value pairs from a user property handle.
pub extern fn esp_mqtt5_client_get_user_property(user_property: mqtt5_user_property_handle_t, item: [*c]esp_mqtt5_user_property_item_t, item_num: [*:0]u8) sys.esp_err_t;
/// Get the number of user properties in a user property handle.
pub extern fn esp_mqtt5_client_get_user_property_count(user_property: mqtt5_user_property_handle_t) u8;
/// Delete and free all user properties in a user property handle.
pub extern fn esp_mqtt5_client_delete_user_property(user_property: mqtt5_user_property_handle_t) void;
