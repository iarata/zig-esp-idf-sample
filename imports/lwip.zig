//! # lwIP Networking Bindings (`lwip`)
//!
//! **What:** Low-level Zig bindings for the lwIP TCP/IP stack used by ESP-IDF.
//! Includes socket polling, IP address types, pbuf management, netif
//! structures, SNTP helpers, and DNS/TCP/UDP utilities.
//!
//! **What it does:**
//!   - **Polling** — `poll(fds, nfds, timeout)` for `select`-style I/O
//!     multiplexing on lwIP sockets.
//!   - **SNTP** — `sntp_get_sync_interval`, `sntp_set_system_time`,
//!     `sntp_get_system_time` for NTP time sync.
//!   - **IP addresses** — `ip4_addr_t`, `ip6_addr_t`, `ip_addr_t` with
//!     conversion functions `ipaddr_aton`, `ipaddr_ntoa`, `ip4addr_aton`,
//!     `ip6addr_aton`, etc.
//!   - **pbuf** — packet buffer struct and allocation/free/chain functions
//!     (`pbuf_alloc`, `pbuf_free`, `pbuf_ref`, `pbuf_cat`, etc.).
//!   - **netif** — full network interface struct with input/output callbacks,
//!     MTU, hardware address, and IGMP/MLD filter hooks.
//!   - **RAW/UDP/TCP pcb** — protocol control blocks, bind, connect,
//!     send/recv, listen, and DNS resolver.
//!   - **Thread** — lwIP thread-local semaphore and core-lock helpers.
//!   - **Error codes** — `err_enum_t` matching lwIP's `ERR_*` defines.
//!
//! **How:** Direct `extern fn` and `extern struct` declarations that map 1:1
//! to the lwIP C API as compiled by ESP-IDF.  No error wrapping — caller
//! must check returns according to lwIP conventions.
//!
//! **When to use:** When you need lower-level networking access than what
//! `esp_http_client` or `esp_tls` provide — e.g. raw sockets, custom
//! protocols, or direct pbuf manipulation.
//!
//! **What it takes:** Knowledge of the lwIP API and ESP-IDF networking
//! architecture (netif, tcpip_adapter, esp_netif).
//!
//! **Example:**
//! ```zig
//! const lwip = idf.lwip;
//! // Convert string IP to binary
//! var addr: lwip.ip4_addr_t = .{};
//! _ = lwip.ip4addr_aton("192.168.1.1", &addr);
//! // Poll a socket
//! var pfd = lwip.pollfd{ .fd = sockfd, .events = 1 }; // POLLIN
//! _ = lwip.poll(&pfd, 1, 1000);
//! ```

const std = @import("std");
const sys = @import("sys");

/// File descriptor entry for the `poll()` system call.
/// Maps to POSIX `struct pollfd` — specifies a socket to monitor and the events of interest.
pub const pollfd = extern struct {
    fd: c_int = std.mem.zeroes(c_int),
    events: c_short = std.mem.zeroes(c_short),
    revents: c_short = std.mem.zeroes(c_short),
};
/// Unsigned type representing the number of file descriptors in a `poll()` call.
pub const nfds_t = c_uint;
/// Poll an array of sockets for I/O readiness, blocking up to `timeout` milliseconds.
/// Returns the number of descriptors with events, 0 on timeout, or -1 on error.
pub extern fn poll(fds: [*c]pollfd, nfds: nfds_t, timeout: c_int) c_int;
/// Return the current SNTP synchronization interval in milliseconds.
pub extern fn sntp_get_sync_interval() u32;
/// Set the system time from SNTP (seconds and microseconds since epoch).
pub extern fn sntp_set_system_time(sec: u32, us: u32) void;
/// Retrieve the current system time as seconds and microseconds since epoch.
pub extern fn sntp_get_system_time(sec: [*c]u32, us: [*c]u32) void;
/// Opaque handle representing an internal lwIP socket structure.
pub const lwip_sock = opaque {};
/// Extended implementation for setting socket options (ESP-IDF extension).
pub extern fn lwip_setsockopt_impl_ext(sock: ?*lwip_sock, level: c_int, optname: c_int, optval: ?*const anyopaque, optlen: u32, err: [*c]c_int) bool;
/// Extended implementation for getting socket options (ESP-IDF extension).
pub extern fn lwip_getsockopt_impl_ext(sock: ?*lwip_sock, level: c_int, optname: c_int, optval: ?*anyopaque, optlen: [*c]u32, err: [*c]c_int) bool;
/// lwIP semaphore type, backed by a FreeRTOS semaphore handle.
pub const sys_sem_t = sys.SemaphoreHandle_t;
/// lwIP mutex type, backed by a FreeRTOS semaphore handle.
pub const sys_mutex_t = sys.SemaphoreHandle_t;
/// lwIP thread type, backed by a FreeRTOS task handle.
pub const sys_thread_t = sys.TaskHandle_t;
/// lwIP mailbox structure wrapping a FreeRTOS queue for inter-thread message passing.
pub const sys_mbox_s = extern struct {
    os_mbox: sys.QueueHandle_t = std.mem.zeroes(sys.QueueHandle_t),
    owner: ?*anyopaque = null,
};
/// Pointer to an lwIP mailbox (message queue).
pub const sys_mbox_t = [*c]sys_mbox_s;
/// Delay the current thread for `ms` milliseconds.
pub extern fn sys_delay_ms(ms: u32) void;
/// Initialize the thread-local semaphore for the calling thread.
pub extern fn sys_thread_sem_init() [*c]sys_sem_t;
/// Deinitialize and free the thread-local semaphore for the calling thread.
pub extern fn sys_thread_sem_deinit() void;
/// Get the thread-local semaphore for the calling thread.
pub extern fn sys_thread_sem_get() [*c]sys_sem_t;
/// Actions for the lwIP TCP/IP core-lock mechanism, used to manage thread-safe access
/// to the lwIP core from multiple FreeRTOS tasks.
pub const sys_thread_core_lock_t = enum(c_uint) {
    LWIP_CORE_LOCK_QUERY_HOLDER = 0,
    LWIP_CORE_LOCK_MARK_HOLDER = 1,
    LWIP_CORE_LOCK_UNMARK_HOLDER = 2,
    LWIP_CORE_MARK_TCPIP_TASK = 3,
    LWIP_CORE_IS_TCPIP_INITIALIZED = 4,
};
/// Query or modify the TCP/IP core lock state for the calling thread.
pub extern fn sys_thread_tcpip(@"type": sys_thread_core_lock_t) bool;
/// Compute a DHCP timeout value from an offered lease duration.
/// If `lease` is zero, falls back to `min`.
pub fn timeout_from_offered(lease: u32, min: u32) callconv(.C) u32 {
    var timeout: u32 = lease;
    if (timeout == @as(u32, @bitCast(@as(c_int, 0)))) {
        timeout = min;
    }
    timeout = ((timeout +% @as(u32, @bitCast(@as(c_int, 1)))) -% @as(u32, @bitCast(@as(c_int, 1)))) / @as(u32, @bitCast(@as(c_int, 1)));
    return timeout;
}
/// lwIP error codes matching the C `ERR_*` defines.
/// Used throughout the lwIP stack to indicate success or specific failure reasons.
pub const err_enum_t = enum(c_int) {
    ERR_OK = 0,
    ERR_MEM = -1,
    ERR_BUF = -2,
    ERR_TIMEOUT = -3,
    ERR_RTE = -4,
    ERR_INPROGRESS = -5,
    ERR_VAL = -6,
    ERR_WOULDBLOCK = -7,
    ERR_USE = -8,
    ERR_ALREADY = -9,
    ERR_ISCONN = -10,
    ERR_CONN = -11,
    ERR_IF = -12,
    ERR_ABRT = -13,
    ERR_RST = -14,
    ERR_CLSD = -15,
    ERR_ARG = -16,
};
/// Compact error type used in lwIP function return values (signed 8-bit).
pub const err_t = i8;
/// Convert an lwIP error code to a POSIX errno value.
pub extern fn err_to_errno(err: err_t) c_int;
/// Convert a 16-bit value from host byte order to network byte order (big-endian).
pub extern fn lwip_htons(x: u16) u16;
/// Convert a 32-bit value from host byte order to network byte order (big-endian).
pub extern fn lwip_htonl(x: u32) u32;
/// Convert an integer to its ASCII decimal string representation.
pub extern fn lwip_itoa(result: [*c]u8, bufsize: usize, number: c_int) void;
/// Case-insensitive comparison of up to `len` characters of two strings.
pub extern fn lwip_strnicmp(str1: [*:0]const u8, str2: [*:0]const u8, len: usize) c_int;
/// Case-insensitive comparison of two null-terminated strings.
pub extern fn lwip_stricmp(str1: [*:0]const u8, str2: [*:0]const u8) c_int;
/// Search for `token` in the first `n` bytes of `buffer` (bounded strstr).
pub extern fn lwip_strnstr(buffer: [*:0]const u8, token: [*:0]const u8, n: usize) [*c]u8;
/// IPv4 address structure containing a single 32-bit address in network byte order.
pub const ip4_addr = extern struct {
    addr: u32 = std.mem.zeroes(u32),
};
/// Alias for `ip4_addr`.
pub const ip4_addr_t = ip4_addr;
/// IPv6 address structure containing four 32-bit words and a zone identifier.
pub const ip6_addr = extern struct {
    addr: [4]u32 = std.mem.zeroes([4]u32),
    zone: u8 = std.mem.zeroes(u8),
};
/// Alias for `ip6_addr`.
pub const ip6_addr_t = ip6_addr;
const union_unnamed_5 = extern union {
    ip6: ip6_addr_t,
    ip4: ip4_addr_t,
};
/// Dual-stack IP address that can hold either an IPv4 or IPv6 address.
/// The `type` field indicates which union member is active.
pub const ip_addr = extern struct {
    u_addr: union_unnamed_5 = std.mem.zeroes(union_unnamed_5),
    type: u8 = std.mem.zeroes(u8),
};
/// Alias for `ip_addr`.
pub const ip_addr_t = ip_addr;
/// lwIP packet buffer — the fundamental data carrier in the stack.
/// Buffers can be chained via `next`; `tot_len` is the total length of the chain,
/// while `len` is the length of this individual buffer.
pub const pbuf = extern struct {
    next: [*c]pbuf = std.mem.zeroes([*c]pbuf),
    payload: ?*anyopaque = null,
    tot_len: u16 = std.mem.zeroes(u16),
    len: u16 = std.mem.zeroes(u16),
    type_internal: u8 = std.mem.zeroes(u8),
    flags: u8 = std.mem.zeroes(u8),
    ref: u8 = std.mem.zeroes(u8),
    if_idx: u8 = std.mem.zeroes(u8),
};
/// Callback type for passing received packets from a netif to the IP layer.
pub const netif_input_fn = ?*const fn ([*c]pbuf, [*c]netif) callconv(.C) err_t;
/// Callback type for sending IPv4 packets through a netif.
pub const netif_output_fn = ?*const fn ([*c]netif, [*c]pbuf, [*c]const ip4_addr_t) callconv(.C) err_t;
/// Callback type for sending raw link-layer frames through a netif.
pub const netif_linkoutput_fn = ?*const fn ([*c]netif, [*c]pbuf) callconv(.C) err_t;
/// Callback type for sending IPv6 packets through a netif.
pub const netif_output_ip6_fn = ?*const fn ([*c]netif, [*c]pbuf, [*c]const ip6_addr_t) callconv(.C) err_t;
/// Actions for adding or removing multicast MAC filters on a network interface.
pub const enum_netif_mac_filter_action = enum(c_uint) {
    NETIF_DEL_MAC_FILTER = 0,
    NETIF_ADD_MAC_FILTER = 1,
};
/// Callback for IGMP MAC-level multicast group filtering.
pub const netif_igmp_mac_filter_fn = ?*const fn ([*c]netif, [*c]const ip4_addr_t, enum_netif_mac_filter_action) callconv(.C) err_t;
/// Callback for MLD (IPv6) MAC-level multicast group filtering.
pub const netif_mld_mac_filter_fn = ?*const fn ([*c]netif, [*c]const ip6_addr_t, enum_netif_mac_filter_action) callconv(.C) err_t;
/// Network interface structure — the central data type for an lwIP network device.
/// Contains IP addresses, hardware address, MTU, I/O callbacks, and state.
pub const netif = extern struct {
    next: [*c]netif = std.mem.zeroes([*c]netif),
    ip_addr: ip_addr_t = std.mem.zeroes(ip_addr_t),
    netmask: ip_addr_t = std.mem.zeroes(ip_addr_t),
    gw: ip_addr_t = std.mem.zeroes(ip_addr_t),
    ip6_addr: [3]ip_addr_t = std.mem.zeroes([3]ip_addr_t),
    ip6_addr_state: [3]u8 = std.mem.zeroes([3]u8),
    ip6_addr_valid_life: [3]u32 = std.mem.zeroes([3]u32),
    ip6_addr_pref_life: [3]u32 = std.mem.zeroes([3]u32),
    input: netif_input_fn = std.mem.zeroes(netif_input_fn),
    output: netif_output_fn = std.mem.zeroes(netif_output_fn),
    linkoutput: netif_linkoutput_fn = std.mem.zeroes(netif_linkoutput_fn),
    output_ip6: netif_output_ip6_fn = std.mem.zeroes(netif_output_ip6_fn),
    state: ?*anyopaque = null,
    client_data: [3]?*anyopaque = std.mem.zeroes([3]?*anyopaque),
    hostname: [*:0]const u8 = std.mem.zeroes([*:0]const u8),
    mtu: u16 = std.mem.zeroes(u16),
    mtu6: u16 = std.mem.zeroes(u16),
    hwaddr: [6]u8 = std.mem.zeroes([6]u8),
    hwaddr_len: u8 = std.mem.zeroes(u8),
    flags: u8 = std.mem.zeroes(u8),
    name: [2]u8 = std.mem.zeroes([2]u8),
    num: u8 = std.mem.zeroes(u8),
    ip6_autoconfig_enabled: u8 = std.mem.zeroes(u8),
    rs_count: u8 = std.mem.zeroes(u8),
    igmp_mac_filter: netif_igmp_mac_filter_fn = std.mem.zeroes(netif_igmp_mac_filter_fn),
    mld_mac_filter: netif_mld_mac_filter_fn = std.mem.zeroes(netif_mld_mac_filter_fn),
    loop_first: [*c]pbuf = std.mem.zeroes([*c]pbuf),
    loop_last: [*c]pbuf = std.mem.zeroes([*c]pbuf),
    loop_cnt_current: u16 = std.mem.zeroes(u16),
    reschedule_poll: u8 = std.mem.zeroes(u8),
};
/// Check whether an IPv4 address is a broadcast address for the given netif.
pub extern fn ip4_addr_isbroadcast_u32(addr: u32, netif: [*c]const netif) u8;
/// Validate an IPv4 subnet mask (must be contiguous leading 1s followed by 0s).
pub extern fn ip4_addr_netmask_valid(netmask: u32) u8;
/// Convert a dotted-decimal IPv4 string to a 32-bit address in network byte order.
pub extern fn ipaddr_addr(cp: [*:0]const u8) u32;
/// Parse a dotted-decimal IPv4 string into an `ip4_addr_t`. Returns 1 on success.
pub extern fn ip4addr_aton(cp: [*:0]const u8, addr: [*c]ip4_addr_t) c_int;
/// Convert an `ip4_addr_t` to a dotted-decimal string (static buffer).
pub extern fn ip4addr_ntoa(addr: [*c]const ip4_addr_t) [*c]u8;
/// Convert an `ip4_addr_t` to a dotted-decimal string in a caller-supplied buffer.
pub extern fn ip4addr_ntoa_r(addr: [*c]const ip4_addr_t, buf: [*c]u8, buflen: c_int) [*c]u8;
/// IPv6 address scope classification.
pub const enum_lwip_ipv6_scope_type = enum(c_uint) {
    IP6_UNKNOWN = 0,
    IP6_UNICAST = 1,
    IP6_MULTICAST = 2,
};
/// Parse an IPv6 address string into an `ip6_addr_t`. Returns 1 on success.
pub extern fn ip6addr_aton(cp: [*:0]const u8, addr: [*c]ip6_addr_t) c_int;
/// Convert an `ip6_addr_t` to a colon-hex string (static buffer).
pub extern fn ip6addr_ntoa(addr: [*c]const ip6_addr_t) [*c]u8;
/// Convert an `ip6_addr_t` to a colon-hex string in a caller-supplied buffer.
pub extern fn ip6addr_ntoa_r(addr: [*c]const ip6_addr_t, buf: [*c]u8, buflen: c_int) [*c]u8;
/// Discriminator for dual-stack IP address types.
pub const enum_lwip_ip_addr_type = enum(c_uint) {
    /// IPv4 address.
    IPADDR_TYPE_V4 = 0,
    /// IPv6 address.
    IPADDR_TYPE_V6 = 6,
    /// Accept any address type (IPv4 or IPv6).
    IPADDR_TYPE_ANY = 46,
};
/// Sentinel IP address that matches any address type.
pub extern const ip_addr_any_type: ip_addr_t;
/// Convert a dual-stack `ip_addr_t` to a human-readable string (static buffer).
pub extern fn ipaddr_ntoa(addr: [*c]const ip_addr_t) [*c]u8;
/// Convert a dual-stack `ip_addr_t` to a string in a caller-supplied buffer.
pub extern fn ipaddr_ntoa_r(addr: [*c]const ip_addr_t, buf: [*c]u8, buflen: c_int) [*c]u8;
/// Parse a human-readable IP address string (v4 or v6) into an `ip_addr_t`.
pub extern fn ipaddr_aton(cp: [*:0]const u8, addr: [*c]ip_addr_t) c_int;
/// The all-zeros IP address constant (INADDR_ANY).
pub extern const ip_addr_any: ip_addr_t;
/// The IPv4 broadcast address constant (255.255.255.255).
pub extern const ip_addr_broadcast: ip_addr_t;
/// The IPv6 all-zeros address constant (in6addr_any).
pub extern const ip6_addr_any: ip_addr_t;
/// Protocol layer at which to reserve header space when allocating a pbuf.
pub const pbuf_layer = enum(c_uint) {
    PBUF_TRANSPORT = 74,
    PBUF_IP = 54,
    PBUF_LINK = 14,
    PBUF_RAW_TX = 0,
    PBUF_RAW = 0,
};
/// Memory allocation strategy for a pbuf.
pub const pbuf_type = enum(c_uint) {
    /// Allocated from the heap; payload is in contiguous RAM.
    PBUF_RAM = 640,
    /// Payload points to ROM/flash; buffer header only.
    PBUF_ROM = 1,
    /// Payload references external RAM; single reference.
    PBUF_REF = 65,
    /// Allocated from a fixed-size memory pool.
    PBUF_POOL = 386,
};
/// Read-only pbuf variant with a const payload pointer (for ROM/flash data).
pub const pbuf_rom = extern struct {
    next: [*c]pbuf = std.mem.zeroes([*c]pbuf),
    payload: ?*const anyopaque = std.mem.zeroes(?*const anyopaque),
};
/// Callback invoked when a custom pbuf is freed.
pub const pbuf_free_custom_fn = ?*const fn ([*c]pbuf) callconv(.C) void;
/// Custom pbuf with a user-supplied free function, for zero-copy DMA buffers, etc.
pub const pbuf_custom = extern struct {
    pbuf: pbuf = std.mem.zeroes(pbuf),
    custom_free_function: pbuf_free_custom_fn = std.mem.zeroes(pbuf_free_custom_fn),
};
/// Allocate a new pbuf of the given layer, length, and memory type.
pub extern fn pbuf_alloc(l: pbuf_layer, length: u16, @"type": pbuf_type) [*c]pbuf;
/// Allocate a reference pbuf pointing to an existing payload.
pub extern fn pbuf_alloc_reference(payload: ?*anyopaque, length: u16, @"type": pbuf_type) [*c]pbuf;
/// Allocate a custom pbuf with user-provided memory and free callback.
pub extern fn pbuf_alloced_custom(l: pbuf_layer, length: u16, @"type": pbuf_type, p: [*c]pbuf_custom, payload_mem: ?*anyopaque, payload_mem_len: u16) [*c]pbuf;
pub extern fn pbuf_realloc(p: [*c]pbuf, size: u16) void;
pub extern fn pbuf_header(p: [*c]pbuf, header_size: i16) u8;
pub extern fn pbuf_header_force(p: [*c]pbuf, header_size: i16) u8;
pub extern fn pbuf_add_header(p: [*c]pbuf, header_size_increment: usize) u8;
pub extern fn pbuf_add_header_force(p: [*c]pbuf, header_size_increment: usize) u8;
pub extern fn pbuf_remove_header(p: [*c]pbuf, header_size: usize) u8;
pub extern fn pbuf_free_header(q: [*c]pbuf, size: u16) [*c]pbuf;
pub extern fn pbuf_ref(p: [*c]pbuf) void;
pub extern fn pbuf_free(p: [*c]pbuf) u8;
pub extern fn pbuf_clen(p: [*c]const pbuf) u16;
pub extern fn pbuf_cat(head: [*c]pbuf, tail: [*c]pbuf) void;
pub extern fn pbuf_chain(head: [*c]pbuf, tail: [*c]pbuf) void;
pub extern fn pbuf_dechain(p: [*c]pbuf) [*c]pbuf;
pub extern fn pbuf_copy(p_to: [*c]pbuf, p_from: [*c]const pbuf) err_t;
pub extern fn pbuf_copy_partial_pbuf(p_to: [*c]pbuf, p_from: [*c]const pbuf, copy_len: u16, offset: u16) err_t;
pub extern fn pbuf_copy_partial(p: [*c]const pbuf, dataptr: ?*anyopaque, len: u16, offset: u16) u16;
pub extern fn pbuf_get_contiguous(p: [*c]const pbuf, buffer: ?*anyopaque, bufsize: usize, len: u16, offset: u16) ?*anyopaque;
pub extern fn pbuf_take(buf: [*c]pbuf, dataptr: ?*const anyopaque, len: u16) err_t;
pub extern fn pbuf_take_at(buf: [*c]pbuf, dataptr: ?*const anyopaque, len: u16, offset: u16) err_t;
pub extern fn pbuf_skip(in: [*c]pbuf, in_offset: u16, out_offset: [*c]u16) [*c]pbuf;
pub extern fn pbuf_coalesce(p: [*c]pbuf, layer: pbuf_layer) [*c]pbuf;
pub extern fn pbuf_clone(l: pbuf_layer, @"type": pbuf_type, p: [*c]pbuf) [*c]pbuf;
pub extern fn pbuf_get_at(p: [*c]const pbuf, offset: u16) u8;
pub extern fn pbuf_try_get_at(p: [*c]const pbuf, offset: u16) c_int;
pub extern fn pbuf_put_at(p: [*c]pbuf, offset: u16, data: u8) void;
pub extern fn pbuf_memcmp(p: [*c]const pbuf, offset: u16, s2: ?*const anyopaque, n: u16) u16;
pub extern fn pbuf_memfind(p: [*c]const pbuf, mem: ?*const anyopaque, mem_len: u16, start_offset: u16) u16;
pub extern fn pbuf_strstr(p: [*c]const pbuf, substr: [*:0]const u8) u16;
/// Size type for the lwIP heap memory allocator.
pub const mem_size_t = usize;
/// Initialize the lwIP heap memory allocator.
pub extern fn mem_init() void;
/// Shrink a previously allocated block to `size` bytes. Returns the (possibly moved) pointer.
pub extern fn mem_trim(mem: ?*anyopaque, size: mem_size_t) ?*anyopaque;
/// Allocate `size` bytes from the lwIP heap.
pub extern fn mem_malloc(size: mem_size_t) ?*anyopaque;
/// Allocate and zero-initialize `count * size` bytes from the lwIP heap.
pub extern fn mem_calloc(count: mem_size_t, size: mem_size_t) ?*anyopaque;
/// Free a block previously allocated with `mem_malloc` or `mem_calloc`.
pub extern fn mem_free(mem: ?*anyopaque) void;
/// Enumeration of lwIP fixed-size memory pool types (one per protocol/subsystem).
pub const memp_t = enum(c_uint) {
    MEMP_RAW_PCB = 0,
    MEMP_UDP_PCB = 1,
    MEMP_TCP_PCB = 2,
    MEMP_TCP_PCB_LISTEN = 3,
    MEMP_TCP_SEG = 4,
    MEMP_FRAG_PBUF = 5,
    MEMP_NETBUF = 6,
    MEMP_NETCONN = 7,
    MEMP_TCPIP_MSG_API = 8,
    MEMP_TCPIP_MSG_INPKT = 9,
    MEMP_ARP_QUEUE = 10,
    MEMP_IGMP_GROUP = 11,
    MEMP_SYS_TIMEOUT = 12,
    MEMP_NETDB = 13,
    MEMP_ND6_QUEUE = 14,
    MEMP_MLD6_GROUP = 15,
    MEMP_PBUF = 16,
    MEMP_PBUF_POOL = 17,
    MEMP_MAX = 18,
};
/// Descriptor for a fixed-size memory pool, specifying the element size.
pub const memp_desc = extern struct {
    size: u16 = std.mem.zeroes(u16),
};
pub extern fn memp_init_pool(desc: [*c]const memp_desc) void;
pub extern fn memp_malloc_pool(desc: [*c]const memp_desc) ?*anyopaque;
pub extern fn memp_free_pool(desc: [*c]const memp_desc, mem: ?*anyopaque) void;
pub extern const memp_pools: [18][*c]const memp_desc;
pub extern fn memp_init() void;
pub extern fn memp_malloc(@"type": memp_t) ?*anyopaque;
pub extern fn memp_free(@"type": memp_t, mem: ?*anyopaque) void;
/// Enumeration of netif client data slot indices used internally by lwIP.
pub const enum_lwip_internal_netif_client_data_index = enum(c_uint) {
    LWIP_NETIF_CLIENT_DATA_INDEX_DHCP = 0,
    LWIP_NETIF_CLIENT_DATA_INDEX_IGMP = 1,
    LWIP_NETIF_CLIENT_DATA_INDEX_MLD6 = 2,
    LWIP_NETIF_CLIENT_DATA_INDEX_MAX = 3,
};
/// Callback type for netif initialization.
pub const netif_init_fn = ?*const fn ([*c]netif) callconv(.C) err_t;
/// Callback type invoked when netif status changes (up/down).
pub const netif_status_callback_fn = ?*const fn ([*c]netif) callconv(.C) void;
/// Index type for netif IPv6 addresses.
pub const netif_addr_idx_t = u8;
/// Head of the global linked list of all registered network interfaces.
pub extern var netif_list: [*c]netif;
/// The current default network interface used for routing.
pub extern var netif_default: [*c]netif;
/// Initialize the netif subsystem.
pub extern fn netif_init() void;
pub extern fn netif_add_noaddr(netif: [*c]netif, state: ?*anyopaque, init: netif_init_fn, input: netif_input_fn) [*c]netif;
pub extern fn netif_add(netif: [*c]netif, ipaddr: [*c]const ip4_addr_t, netmask: [*c]const ip4_addr_t, gw: [*c]const ip4_addr_t, state: ?*anyopaque, init: netif_init_fn, input: netif_input_fn) [*c]netif;
pub extern fn netif_set_addr(netif: [*c]netif, ipaddr: [*c]const ip4_addr_t, netmask: [*c]const ip4_addr_t, gw: [*c]const ip4_addr_t) void;
pub extern fn netif_remove(netif: [*c]netif) void;
pub extern fn netif_find(name: [*:0]const u8) [*c]netif;
pub extern fn netif_set_default(netif: [*c]netif) void;
pub extern fn netif_set_ipaddr(netif: [*c]netif, ipaddr: [*c]const ip4_addr_t) void;
pub extern fn netif_set_netmask(netif: [*c]netif, netmask: [*c]const ip4_addr_t) void;
pub extern fn netif_set_gw(netif: [*c]netif, gw: [*c]const ip4_addr_t) void;
pub extern fn netif_set_up(netif: [*c]netif) void;
pub extern fn netif_set_down(netif: [*c]netif) void;
pub extern fn netif_set_link_up(netif: [*c]netif) void;
pub extern fn netif_set_link_down(netif: [*c]netif) void;
pub extern fn netif_loop_output(netif: [*c]netif, p: [*c]pbuf) err_t;
pub extern fn netif_poll(netif: [*c]netif) void;
pub extern fn netif_input(p: [*c]pbuf, inp: [*c]netif) err_t;
pub extern fn netif_ip6_addr_set(netif: [*c]netif, addr_idx: i8, addr6: [*c]const ip6_addr_t) void;
pub extern fn netif_ip6_addr_set_parts(netif: [*c]netif, addr_idx: i8, @"i0": u32, @"i1": u32, @"i2": u32, @"i3": u32) void;
pub extern fn netif_ip6_addr_set_state(netif: [*c]netif, addr_idx: i8, state: u8) void;
pub extern fn netif_get_ip6_addr_match(netif: [*c]netif, ip6addr: [*c]const ip6_addr_t) i8;
pub extern fn netif_create_ip6_linklocal_address(netif: [*c]netif, from_mac_48bit: u8) void;
pub extern fn netif_add_ip6_address(netif: [*c]netif, ip6addr: [*c]const ip6_addr_t, chosen_idx: [*c]i8) err_t;
pub extern fn netif_name_to_index(name: [*:0]const u8) u8;
pub extern fn netif_index_to_name(idx: u8, name: [*c]u8) [*c]u8;
pub extern fn netif_get_by_index(idx: u8) [*c]netif;
/// Reason code bitmask for netif extended callbacks.
pub const netif_nsc_reason_t = u16;
pub const link_changed_s_6 = extern struct {
    state: u8 = std.mem.zeroes(u8),
};
pub const status_changed_s_7 = extern struct {
    state: u8 = std.mem.zeroes(u8),
};
pub const ipv4_changed_s_8 = extern struct {
    old_address: [*c]const ip_addr_t = std.mem.zeroes([*c]const ip_addr_t),
    old_netmask: [*c]const ip_addr_t = std.mem.zeroes([*c]const ip_addr_t),
    old_gw: [*c]const ip_addr_t = std.mem.zeroes([*c]const ip_addr_t),
};
pub const ipv6_set_s_9 = extern struct {
    addr_index: i8 = std.mem.zeroes(i8),
    old_address: [*c]const ip_addr_t = std.mem.zeroes([*c]const ip_addr_t),
};
pub const ipv6_addr_state_changed_s_10 = extern struct {
    addr_index: i8 = std.mem.zeroes(i8),
    old_state: u8 = std.mem.zeroes(u8),
    address: [*c]const ip_addr_t = std.mem.zeroes([*c]const ip_addr_t),
};
/// Union of arguments passed to netif extended callbacks, one variant per event type.
pub const netif_ext_callback_args_t = extern union {
    link_changed: link_changed_s_6,
    status_changed: status_changed_s_7,
    ipv4_changed: ipv4_changed_s_8,
    ipv6_set: ipv6_set_s_9,
    ipv6_addr_state_changed: ipv6_addr_state_changed_s_10,
};
/// Callback type for extended netif status notifications.
pub const netif_ext_callback_fn = ?*const fn ([*c]netif, netif_nsc_reason_t, [*c]const netif_ext_callback_args_t) callconv(.C) void;
/// Linked-list node for extended netif callbacks.
pub const netif_ext_callback = extern struct {
    callback_fn: netif_ext_callback_fn = std.mem.zeroes(netif_ext_callback_fn),
    next: [*c]netif_ext_callback = std.mem.zeroes([*c]netif_ext_callback),
};
/// Alias for `netif_ext_callback`.
pub const netif_ext_callback_t = netif_ext_callback;
/// Register an extended callback for netif events.
pub extern fn netif_add_ext_callback(callback: [*c]netif_ext_callback_t, @"fn": netif_ext_callback_fn) void;
/// Unregister a previously registered extended netif callback.
pub extern fn netif_remove_ext_callback(callback: [*c]netif_ext_callback_t) void;
/// Invoke all registered extended callbacks with the given reason and args.
pub extern fn netif_invoke_ext_callback(netif: [*c]netif, reason: netif_nsc_reason_t, args: [*c]const netif_ext_callback_args_t) void;
/// BSD IPv4 address structure (`struct in_addr`).
pub const in_addr = extern struct {
    s_addr: u32 = std.mem.zeroes(u32),
};
const union_unnamed_11 = extern union {
    u32_addr: [4]u32,
    u8_addr: [16]u8,
};
/// BSD IPv6 address structure (`struct in6_addr`).
pub const in6_addr = extern struct {
    un: union_unnamed_11 = std.mem.zeroes(union_unnamed_11),
};
pub extern const in6addr_any: in6_addr;
/// Address family type for socket address structures.
pub const sa_family_t = u8;
/// IPv4 socket address (`struct sockaddr_in`).
pub const sockaddr_in = extern struct {
    sin_len: u8 = std.mem.zeroes(u8),
    sin_family: sa_family_t = std.mem.zeroes(sa_family_t),
    sin_port: u16 = std.mem.zeroes(u16),
    sin_addr: in_addr = std.mem.zeroes(in_addr),
    sin_zero: [8]u8 = std.mem.zeroes([8]u8),
};
/// IPv6 socket address (`struct sockaddr_in6`).
pub const sockaddr_in6 = extern struct {
    sin6_len: u8 = std.mem.zeroes(u8),
    sin6_family: sa_family_t = std.mem.zeroes(sa_family_t),
    sin6_port: u16 = std.mem.zeroes(u16),
    sin6_flowinfo: u32 = std.mem.zeroes(u32),
    sin6_addr: in6_addr = std.mem.zeroes(in6_addr),
    sin6_scope_id: u32 = std.mem.zeroes(u32),
};
/// Generic socket address (`struct sockaddr`).
pub const sockaddr = extern struct {
    sa_len: u8 = std.mem.zeroes(u8),
    sa_family: sa_family_t = std.mem.zeroes(sa_family_t),
    sa_data: [14]u8 = std.mem.zeroes([14]u8),
};
/// Socket address storage large enough to hold any address family.
pub const sockaddr_storage = extern struct {
    s2_len: u8 = std.mem.zeroes(u8),
    ss_family: sa_family_t = std.mem.zeroes(sa_family_t),
    s2_data1: [2]u8 = std.mem.zeroes([2]u8),
    s2_data2: [3]u32 = std.mem.zeroes([3]u32),
    s2_data3: [3]u32 = std.mem.zeroes([3]u32),
};
/// Socket address length type.
pub const socklen_t = u32;
/// Scatter/gather I/O vector for `readv`/`writev` style operations.
pub const iovec = extern struct {
    iov_base: ?*anyopaque = null,
    iov_len: usize = std.mem.zeroes(usize),
};
/// Message header for `sendmsg`/`recvmsg` operations, supporting scatter/gather I/O and ancillary data.
pub const msghdr = extern struct {
    msg_name: ?*anyopaque = null,
    msg_namelen: socklen_t = std.mem.zeroes(socklen_t),
    msg_iov: [*c]iovec = std.mem.zeroes([*c]iovec),
    msg_iovlen: c_int = std.mem.zeroes(c_int),
    msg_control: ?*anyopaque = null,
    msg_controllen: socklen_t = std.mem.zeroes(socklen_t),
    msg_flags: c_int = std.mem.zeroes(c_int),
};
/// Control message header for ancillary data in `msghdr`.
pub const cmsghdr = extern struct {
    cmsg_len: socklen_t = std.mem.zeroes(socklen_t),
    cmsg_level: c_int = std.mem.zeroes(c_int),
    cmsg_type: c_int = std.mem.zeroes(c_int),
};
/// Interface request structure for `ioctl` calls.
pub const ifreq = extern struct {
    ifr_name: [6]u8 = std.mem.zeroes([6]u8),
};
/// Linger option for controlling socket close behavior (`SO_LINGER`).
pub const linger = extern struct {
    l_onoff: c_int = std.mem.zeroes(c_int),
    l_linger: c_int = std.mem.zeroes(c_int),
};
/// IPv4 multicast group membership request (`IP_ADD_MEMBERSHIP`/`IP_DROP_MEMBERSHIP`).
pub const ip_mreq = extern struct {
    imr_multiaddr: in_addr = std.mem.zeroes(in_addr),
    imr_interface: in_addr = std.mem.zeroes(in_addr),
};
/// Ancillary data for `IP_PKTINFO` — provides the destination address and interface index.
pub const in_pktinfo = extern struct {
    ipi_ifindex: c_uint = std.mem.zeroes(c_uint),
    ipi_addr: in_addr = std.mem.zeroes(in_addr),
};
/// IPv6 multicast group membership request.
pub const ipv6_mreq = extern struct {
    ipv6mr_multiaddr: in6_addr = std.mem.zeroes(in6_addr),
    ipv6mr_interface: c_uint = std.mem.zeroes(c_uint),
};
/// Initialize per-thread lwIP socket support. Call once per thread that uses sockets.
pub extern fn lwip_socket_thread_init() void;
/// Clean up per-thread lwIP socket resources.
pub extern fn lwip_socket_thread_cleanup() void;
/// Accept an incoming connection on a listening socket. Returns the new socket fd.
pub extern fn lwip_accept(s: c_int, addr: [*c]sockaddr, addrlen: [*c]socklen_t) c_int;
/// Bind a socket to a local address and port.
pub extern fn lwip_bind(s: c_int, name: [*c]const sockaddr, namelen: socklen_t) c_int;
/// Shut down part or all of a full-duplex socket connection.
pub extern fn lwip_shutdown(s: c_int, how: c_int) c_int;
pub extern fn lwip_getpeername(s: c_int, name: [*c]sockaddr, namelen: [*c]socklen_t) c_int;
pub extern fn lwip_getsockname(s: c_int, name: [*c]sockaddr, namelen: [*c]socklen_t) c_int;
pub extern fn lwip_getsockopt(s: c_int, level: c_int, optname: c_int, optval: ?*anyopaque, optlen: [*c]socklen_t) c_int;
pub extern fn lwip_setsockopt(s: c_int, level: c_int, optname: c_int, optval: ?*const anyopaque, optlen: socklen_t) c_int;
pub extern fn lwip_close(s: c_int) c_int;
pub extern fn lwip_connect(s: c_int, name: [*c]const sockaddr, namelen: socklen_t) c_int;
pub extern fn lwip_listen(s: c_int, backlog: c_int) c_int;
pub extern fn lwip_recv(s: c_int, mem: ?*anyopaque, len: usize, flags: c_int) isize;
pub extern fn lwip_read(s: c_int, mem: ?*anyopaque, len: usize) isize;
pub extern fn lwip_readv(s: c_int, iov: [*c]const iovec, iovcnt: c_int) isize;
pub extern fn lwip_recvfrom(s: c_int, mem: ?*anyopaque, len: usize, flags: c_int, from: [*c]sockaddr, fromlen: [*c]socklen_t) isize;
pub extern fn lwip_recvmsg(s: c_int, message: [*c]msghdr, flags: c_int) isize;
pub extern fn lwip_send(s: c_int, dataptr: ?*const anyopaque, size: usize, flags: c_int) isize;
pub extern fn lwip_sendmsg(s: c_int, message: [*c]const msghdr, flags: c_int) isize;
pub extern fn lwip_sendto(s: c_int, dataptr: ?*const anyopaque, size: usize, flags: c_int, to: [*c]const sockaddr, tolen: socklen_t) isize;
/// Create a new socket. Returns the file descriptor or -1 on error.
pub extern fn lwip_socket(domain: c_int, @"type": c_int, protocol: c_int) c_int;
pub extern fn lwip_write(s: c_int, dataptr: ?*const anyopaque, size: usize) isize;
pub extern fn lwip_writev(s: c_int, iov: [*c]const iovec, iovcnt: c_int) isize;
pub extern fn lwip_select(maxfdp1: c_int, readset: [*c]fd_set, writeset: [*c]fd_set, exceptset: [*c]fd_set, timeout: [*c]std.os.timeval) c_int;
pub extern fn lwip_poll(fds: [*c]pollfd, nfds: nfds_t, timeout: c_int) c_int;
pub extern fn lwip_ioctl(s: c_int, cmd: c_long, argp: ?*anyopaque) c_int;
pub extern fn lwip_fcntl(s: c_int, cmd: c_int, val: c_int) c_int;
/// Convert an IP address from binary to presentation format.
pub extern fn lwip_inet_ntop(af: c_int, src: ?*const anyopaque, dst: [*c]u8, size: socklen_t) [*:0]const u8;
/// Convert an IP address from presentation to binary format.
pub extern fn lwip_inet_pton(af: c_int, src: [*:0]const u8, dst: ?*anyopaque) c_int;
/// POSIX-compatible `accept` wrapper — delegates to `lwip_accept`.
pub fn accept(s: c_int, addr: [*c]sockaddr, addrlen: [*c]socklen_t) callconv(.C) c_int {
    return lwip_accept(s, addr, addrlen);
}
/// POSIX-compatible `bind` wrapper — delegates to `lwip_bind`.
pub fn bind(s: c_int, name: [*c]const sockaddr, namelen: socklen_t) callconv(.C) c_int {
    return lwip_bind(s, name, namelen);
}
/// POSIX-compatible `shutdown` wrapper — delegates to `lwip_shutdown`.
pub fn shutdown(s: c_int, how: c_int) callconv(.C) c_int {
    return lwip_shutdown(s, how);
}
/// POSIX-compatible `getpeername` wrapper — delegates to `lwip_getpeername`.
pub fn getpeername(s: c_int, name: [*c]sockaddr, namelen: [*c]socklen_t) callconv(.C) c_int {
    return lwip_getpeername(s, name, namelen);
}
/// POSIX-compatible `getsockname` wrapper — delegates to `lwip_getsockname`.
pub fn getsockname(s: c_int, name: [*c]sockaddr, namelen: [*c]socklen_t) callconv(.C) c_int {
    return lwip_getsockname(s, name, namelen);
}
/// POSIX-compatible `setsockopt` wrapper — delegates to `lwip_setsockopt`.
pub fn setsockopt(s: c_int, level: c_int, optname: c_int, opval: ?*const anyopaque, optlen: socklen_t) callconv(.C) c_int {
    return lwip_setsockopt(s, level, optname, opval, optlen);
}
/// POSIX-compatible `getsockopt` wrapper — delegates to `lwip_getsockopt`.
pub fn getsockopt(s: c_int, level: c_int, optname: c_int, opval: ?*anyopaque, optlen: [*c]socklen_t) callconv(.C) c_int {
    return lwip_getsockopt(s, level, optname, opval, optlen);
}
/// Close a socket (POSIX `closesocket` convention) — delegates to `lwip_close`.
pub fn closesocket(s: c_int) callconv(.C) c_int {
    return lwip_close(s);
}
/// POSIX-compatible `connect` wrapper — delegates to `lwip_connect`.
pub fn connect(s: c_int, name: [*c]const sockaddr, namelen: socklen_t) callconv(.C) c_int {
    return lwip_connect(s, name, namelen);
}
/// POSIX-compatible `listen` wrapper — delegates to `lwip_listen`.
pub fn listen(s: c_int, backlog: c_int) callconv(.C) c_int {
    return lwip_listen(s, backlog);
}
/// POSIX-compatible `recvmsg` wrapper — delegates to `lwip_recvmsg`.
pub fn recvmsg(sockfd: c_int, msg: [*c]msghdr, flags: c_int) callconv(.C) isize {
    return lwip_recvmsg(sockfd, msg, flags);
}
/// POSIX-compatible `recv` wrapper — delegates to `lwip_recv`.
pub fn recv(s: c_int, mem: ?*anyopaque, len: usize, flags: c_int) callconv(.C) isize {
    return lwip_recv(s, mem, len, flags);
}
/// POSIX-compatible `recvfrom` wrapper — delegates to `lwip_recvfrom`.
pub fn recvfrom(s: c_int, mem: ?*anyopaque, len: usize, flags: c_int, from: [*c]sockaddr, fromlen: [*c]socklen_t) callconv(.C) isize {
    return lwip_recvfrom(s, mem, len, flags, from, fromlen);
}
/// POSIX-compatible `send` wrapper — delegates to `lwip_send`.
pub fn send(s: c_int, dataptr: ?*const anyopaque, size: usize, flags: c_int) callconv(.C) isize {
    return lwip_send(s, dataptr, size, flags);
}
/// POSIX-compatible `sendmsg` wrapper — delegates to `lwip_sendmsg`.
pub fn sendmsg(s: c_int, message: [*c]const msghdr, flags: c_int) callconv(.C) isize {
    return lwip_sendmsg(s, message, flags);
}
/// POSIX-compatible `sendto` wrapper — delegates to `lwip_sendto`.
pub fn sendto(s: c_int, dataptr: ?*const anyopaque, size: usize, flags: c_int, to: [*c]const sockaddr, tolen: socklen_t) callconv(.C) isize {
    return lwip_sendto(s, dataptr, size, flags, to, tolen);
}
/// POSIX-compatible `socket` wrapper — delegates to `lwip_socket`.
pub fn socket(domain: c_int, @"type": c_int, protocol: c_int) callconv(.C) c_int {
    return lwip_socket(domain, @"type", protocol);
}
/// POSIX-compatible `inet_ntop` wrapper — delegates to `lwip_inet_ntop`.
pub fn inet_ntop(af: c_int, src: ?*const anyopaque, dst: [*c]u8, size: socklen_t) callconv(.C) [*:0]const u8 {
    return lwip_inet_ntop(af, src, dst, size);
}
/// POSIX-compatible `inet_pton` wrapper — delegates to `lwip_inet_pton`.
pub fn inet_pton(af: c_int, src: [*:0]const u8, dst: ?*anyopaque) callconv(.C) c_int {
    return lwip_inet_pton(af, src, dst);
}
/// Thread function signature for lwIP system threads.
pub const lwip_thread_fn = ?*const fn (?*anyopaque) callconv(.C) void;
/// Create a new lwIP mutex. Returns `ERR_OK` on success.
pub extern fn sys_mutex_new(mutex: [*c]sys_mutex_t) err_t;
/// Lock an lwIP mutex (blocking).
pub extern fn sys_mutex_lock(mutex: [*c]sys_mutex_t) void;
/// Unlock an lwIP mutex.
pub extern fn sys_mutex_unlock(mutex: [*c]sys_mutex_t) void;
/// Free an lwIP mutex and release its resources.
pub extern fn sys_mutex_free(mutex: [*c]sys_mutex_t) void;
/// Create a new lwIP semaphore with the given initial count.
pub extern fn sys_sem_new(sem: [*c]sys_sem_t, count: u8) err_t;
/// Signal (post) an lwIP semaphore.
pub extern fn sys_sem_signal(sem: [*c]sys_sem_t) void;
/// Wait on an lwIP semaphore with a timeout in milliseconds. Returns time waited or `SYS_ARCH_TIMEOUT`.
pub extern fn sys_arch_sem_wait(sem: [*c]sys_sem_t, timeout: u32) u32;
/// Free an lwIP semaphore.
pub extern fn sys_sem_free(sem: [*c]sys_sem_t) void;
/// Create a new lwIP mailbox (message queue) with the given size.
pub extern fn sys_mbox_new(mbox: [*c]sys_mbox_t, size: c_int) err_t;
/// Post a message to an lwIP mailbox (blocking if full).
pub extern fn sys_mbox_post(mbox: [*c]sys_mbox_t, msg: ?*anyopaque) void;
/// Try to post a message to an lwIP mailbox without blocking.
pub extern fn sys_mbox_trypost(mbox: [*c]sys_mbox_t, msg: ?*anyopaque) err_t;
/// Try to post a message to an lwIP mailbox from an ISR context.
pub extern fn sys_mbox_trypost_fromisr(mbox: [*c]sys_mbox_t, msg: ?*anyopaque) err_t;
/// Fetch a message from an lwIP mailbox, blocking up to `timeout` ms.
pub extern fn sys_arch_mbox_fetch(mbox: [*c]sys_mbox_t, msg: [*c]?*anyopaque, timeout: u32) u32;
/// Try to fetch a message from an lwIP mailbox without blocking.
pub extern fn sys_arch_mbox_tryfetch(mbox: [*c]sys_mbox_t, msg: [*c]?*anyopaque) u32;
/// Free an lwIP mailbox.
pub extern fn sys_mbox_free(mbox: [*c]sys_mbox_t) void;
/// Create a new lwIP system thread with the given name, stack size, and priority.
pub extern fn sys_thread_new(name: [*:0]const u8, thread: lwip_thread_fn, arg: ?*anyopaque, stacksize: c_int, prio: c_int) sys_thread_t;
/// Initialize the lwIP system layer (called once during startup).
pub extern fn sys_init() void;
/// Return a monotonic tick counter (jiffies).
pub extern fn sys_jiffies() u32;
/// Return the current system time in milliseconds.
pub extern fn sys_now() u32;
/// Enter a critical section (disable interrupts). Returns the previous protection level.
pub extern fn sys_arch_protect() c_int;
/// Leave a critical section (restore interrupts to `pval`).
pub extern fn sys_arch_unprotect(pval: c_int) void;
/// DNS host entry result from `gethostbyname` — contains hostname, aliases, and address list.
pub const hostent = extern struct {
    h_name: [*c]u8 = std.mem.zeroes([*c]u8),
    h_aliases: [*c][*c]u8 = std.mem.zeroes([*c][*c]u8),
    h_addrtype: c_int = std.mem.zeroes(c_int),
    h_length: c_int = std.mem.zeroes(c_int),
    h_addr_list: [*c][*c]u8 = std.mem.zeroes([*c][*c]u8),
};
/// Address info result from `getaddrinfo` — linked list of resolved addresses with socket hints.
pub const addrinfo = extern struct {
    ai_flags: c_int = std.mem.zeroes(c_int),
    ai_family: c_int = std.mem.zeroes(c_int),
    ai_socktype: c_int = std.mem.zeroes(c_int),
    ai_protocol: c_int = std.mem.zeroes(c_int),
    ai_addrlen: socklen_t = std.mem.zeroes(socklen_t),
    ai_addr: [*c]sockaddr = std.mem.zeroes([*c]sockaddr),
    ai_canonname: [*c]u8 = std.mem.zeroes([*c]u8),
    ai_next: [*c]addrinfo = std.mem.zeroes([*c]addrinfo),
};
/// Thread-local DNS error variable.
pub extern var h_errno: c_int;
/// Resolve a hostname to an IP address (blocking, not thread-safe). Returns a `hostent` pointer.
pub extern fn lwip_gethostbyname(name: [*:0]const u8) [*c]hostent;
/// Thread-safe reentrant version of `gethostbyname`.
pub extern fn lwip_gethostbyname_r(name: [*:0]const u8, ret: [*c]hostent, buf: [*c]u8, buflen: usize, result: [*c][*c]hostent, h_errnop: [*c]c_int) c_int;
/// Free an `addrinfo` linked list returned by `getaddrinfo`.
pub extern fn lwip_freeaddrinfo(ai: [*c]addrinfo) void;
/// Resolve a hostname and/or service name to a list of socket addresses.
pub extern fn lwip_getaddrinfo(nodename: [*:0]const u8, servname: [*:0]const u8, hints: [*c]const addrinfo, res: [*c][*c]addrinfo) c_int;
/// POSIX-compatible `gethostbyname_r` wrapper — delegates to `lwip_gethostbyname_r`.
pub fn gethostbyname_r(name: [*:0]const u8, ret: [*c]hostent, buf: [*c]u8, buflen: usize, result: [*c][*c]hostent, h_errnop: [*c]c_int) callconv(.C) c_int {
    return lwip_gethostbyname_r(name, ret, buf, buflen, result, h_errnop);
}
/// POSIX-compatible `gethostbyname` wrapper — delegates to `lwip_gethostbyname`.
pub fn gethostbyname(name: [*:0]const u8) callconv(.C) [*c]hostent {
    return lwip_gethostbyname(name);
}
/// POSIX-compatible `freeaddrinfo` wrapper — delegates to `lwip_freeaddrinfo`.
pub fn freeaddrinfo(ai: [*c]addrinfo) callconv(.C) void {
    lwip_freeaddrinfo(ai);
}
/// POSIX-compatible `getaddrinfo` wrapper — delegates to `lwip_getaddrinfo`.
pub fn getaddrinfo(nodename: [*:0]const u8, servname: [*:0]const u8, hints: [*c]const addrinfo, res: [*c][*c]addrinfo) callconv(.C) c_int {
    return lwip_getaddrinfo(nodename, servname, hints, res);
}
/// Multicast DNS (mDNS) IPv4 group address constant.
pub extern const dns_mquery_v4group: ip_addr_t;
/// Multicast DNS (mDNS) IPv6 group address constant.
pub extern const dns_mquery_v6group: ip_addr_t;
/// Callback invoked when an asynchronous DNS resolution completes.
pub const dns_found_callback = ?*const fn ([*:0]const u8, [*c]const ip_addr_t, ?*anyopaque) callconv(.C) void;
/// Initialize the DNS client subsystem.
pub extern fn dns_init() void;
/// DNS timer function — must be called periodically (e.g. every second) to handle retries.
pub extern fn dns_tmr() void;
/// Set a DNS server address by index.
pub extern fn dns_setserver(numdns: u8, dnsserver: [*c]const ip_addr_t) void;
/// Get a DNS server address by index.
pub extern fn dns_getserver(numdns: u8) [*c]const ip_addr_t;
/// Resolve a hostname asynchronously. Returns `ERR_OK` if already cached, `ERR_INPROGRESS` if queued.
pub extern fn dns_gethostbyname(hostname: [*:0]const u8, addr: [*c]ip_addr_t, found: dns_found_callback, callback_arg: ?*anyopaque) err_t;
/// Resolve a hostname asynchronously with address type preference (v4, v6, or any).
pub extern fn dns_gethostbyname_addrtype(hostname: [*:0]const u8, addr: [*c]ip_addr_t, found: dns_found_callback, callback_arg: ?*anyopaque, dns_addrtype: u8) err_t;
/// Clear the DNS resolver cache.
pub extern fn dns_clear_cache() void;
/// File descriptor set for `select()` style I/O multiplexing.
pub const fd_set = extern struct {
    __fds_bits: [2]__fd_mask = std.mem.zeroes([2]__fd_mask),
};
pub const __fd_mask = c_ulong;
