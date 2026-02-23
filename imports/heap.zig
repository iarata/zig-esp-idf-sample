//! # Heap & Memory Allocator Wrappers (`heap`)
//!
//! **What:** Zig `std.mem.Allocator` implementations backed by ESP-IDF's
//! capability-based heap system, plus heap-trace debugging helpers.
//!
//! **What it does:**
//!   - **Caps** — a `packed struct(u32)` that mirrors the `MALLOC_CAP_*` bit
//!     flags from `esp_heap_caps.h`.  Named presets (`default_caps`,
//!     `dma_caps`, `spiram_caps`, `rtcram_caps`, `exec_caps`, etc.) cover
//!     the most common use cases.
//!   - **HeapCapsAllocator** — full `std.mem.Allocator` backed by
//!     `heap_caps_aligned_alloc/realloc/free`.  Specify capability flags at
//!     construction time (e.g. DMA-capable, SPIRAM, internal).  Debug builds
//!     run `heap_caps_check_integrity_all` after every free.
//!   - **MultiHeapAllocator** — allocator for a specific `multi_heap_handle_t`
//!     (useful for custom memory pools).
//!   - **VPortAllocator** — allocator using FreeRTOS `pvPortMalloc` /
//!     `vPortFree` for tasks that must use the RTOS heap.
//!   - **TRACE** — `heap_trace_*` wrapper for leak detection: `initStandalone`,
//!     `start`, `stop`, `dump`, `summary`.
//!
//! **How:** Each allocator struct stores its config (caps or heap handle) and
//! exposes a `fn allocator(self: *Self) std.mem.Allocator` method that can
//! be passed to any Zig code expecting an allocator.
//!
//! **When to use:**
//!   - Use `HeapCapsAllocator` when memory placement matters (DMA buffers,
//!     SPIRAM-backed large arrays, RTC-retained data).
//!   - Use `VPortAllocator` for compatibility with code that must use
//!     `pvPortMalloc`.
//!   - Use `TRACE` during development to find memory leaks.
//!
//! **What it takes:**
//!   - `Caps` flags describing the required memory region.
//!
//! **Example:**
//! ```zig
//! const heap = idf.heap;
//! var alloc_inst = heap.HeapCapsAllocator.init(heap.Caps.dma_caps);
//! const allocator = alloc_inst.allocator();
//! const buf = try allocator.alloc(u8, 1024);  // DMA-capable buffer
//! defer allocator.free(buf);
//!
//! // SPIRAM allocator
//! var spiram_alloc = heap.HeapCapsAllocator.init(heap.Caps.spiram_caps);
//! ```

const sys = @import("sys");
const std = @import("std");
const errors = @import("error");
const builtin = @import("builtin");

// read: https://github.com/espressif/esp-idf/blob/97d95853572ab74f4769597496af9d5fe8b6bdea/components/heap/include/esp_heap_caps.h#L29-L53
// ---------------------------------------------------------------------------
// Caps — packed struct matching esp_heap_caps.h bit positions exactly.
//
// Bit layout (matches MALLOC_CAP_* defines):
//   0        exec          (only when CONFIG_HEAP_HAS_EXEC_HEAP)
//   1        32bit
//   2        8bit
//   3        dma
//   4- 9     pid2..pid7
//   10       spiram
//   11       internal
//   12       default
//   13       iram_8bit
//   14       retention
//   15       rtcram
//   16       tcm
//   17       dma_desc_ahb
//   18       dma_desc_axi
//   19       cache_aligned
//   20       simd
//   21-30    (reserved)
//   31       invalid
// ---------------------------------------------------------------------------
/// Capability bit-field matching `MALLOC_CAP_*` defines in `esp_heap_caps.h`.
///
/// Use named presets (`.default_caps`, `.dma_caps`, `.spiram_caps`, etc.)
/// or set individual bits for fine-grained heap region selection.
pub const Caps = packed struct(u32) {
    exec: bool = false, // bit  0  — requires CONFIG_HEAP_HAS_EXEC_HEAP
    @"32bit": bool = false, // bit  1
    @"8bit": bool = false, // bit  2
    dma: bool = false, // bit  3
    pid2: bool = false, // bit  4
    pid3: bool = false, // bit  5
    pid4: bool = false, // bit  6
    pid5: bool = false, // bit  7
    pid6: bool = false, // bit  8
    pid7: bool = false, // bit  9
    spiram: bool = false, // bit 10
    internal: bool = false, // bit 11
    default: bool = false, // bit 12
    iram_8bit: bool = false, // bit 13
    retention: bool = false, // bit 14
    rtcram: bool = false, // bit 15
    tcm: bool = false, // bit 16
    dma_desc_ahb: bool = false, // bit 17
    dma_desc_axi: bool = false, // bit 18
    cache_aligned: bool = false, // bit 19
    simd: bool = false, // bit 20
    _reserved: u10 = 0, // bits 21-30
    invalid: bool = false, // bit 31

    /// Cast to the raw u32 value the heap_caps_* C functions expect.
    pub fn toRaw(self: Caps) u32 {
        return @bitCast(self);
    }

    /// Re-hydrate from a raw C bitmask (e.g. value returned by a C API).
    pub fn fromRaw(raw: u32) Caps {
        return @bitCast(raw);
    }

    // -- Named presets matching common ESP-IDF usage patterns ---------------

    /// General-purpose heap (equivalent to malloc/calloc).
    pub const default_caps: Caps = .{ .default = true };
    /// Internal RAM, byte-addressable.
    pub const internal_caps: Caps = .{ .internal = true, .@"8bit" = true };
    /// DMA-capable internal RAM.
    pub const dma_caps: Caps = .{ .dma = true, .@"8bit" = true, .internal = true };
    /// External SPI RAM, byte-addressable.
    pub const spiram_caps: Caps = .{ .spiram = true, .@"8bit" = true };
    /// RTC fast memory (survives deep sleep).
    pub const rtcram_caps: Caps = .{ .rtcram = true };
    /// Tightly-coupled memory.
    pub const tcm_caps: Caps = .{ .tcm = true };
    /// Executable memory (requires CONFIG_HEAP_HAS_EXEC_HEAP).
    pub const exec_caps: Caps = .{ .exec = true };
    /// Cache-line aligned memory.
    pub const cache_aligned_caps: Caps = .{ .cache_aligned = true, .default = true };
};

// Verify the bit layout matches the C header at compile time.
comptime {
    std.debug.assert(@as(u32, @bitCast(Caps{ .exec = true })) == (1 << 0));
    std.debug.assert(@as(u32, @bitCast(Caps{ .@"32bit" = true })) == (1 << 1));
    std.debug.assert(@as(u32, @bitCast(Caps{ .@"8bit" = true })) == (1 << 2));
    std.debug.assert(@as(u32, @bitCast(Caps{ .dma = true })) == (1 << 3));
    std.debug.assert(@as(u32, @bitCast(Caps{ .spiram = true })) == (1 << 10));
    std.debug.assert(@as(u32, @bitCast(Caps{ .internal = true })) == (1 << 11));
    std.debug.assert(@as(u32, @bitCast(Caps{ .default = true })) == (1 << 12));
    std.debug.assert(@as(u32, @bitCast(Caps{ .simd = true })) == (1 << 20));
    std.debug.assert(@as(u32, @bitCast(Caps{ .invalid = true })) == (1 << 31));
}

// ---------------------------------------------------------------------------
// HeapCapsAllocator
// ---------------------------------------------------------------------------

/// `std.mem.Allocator` backed by `heap_caps_aligned_alloc/realloc/free`.
///
/// Specify capability flags at construction time to control which memory
/// region allocations come from (internal, DMA, SPIRAM, etc.).
pub const HeapCapsAllocator = struct {
    caps: Caps = Caps.default_caps,

    const Self = @This();

    /// Create an allocator instance targeting the given capability flags.
    pub fn init(caps: ?Caps) Self {
        return .{ .caps = caps orelse Caps.default_caps };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    /// Dump detailed heap block information (for debugging).
    pub fn dump(self: Self) void {
        sys.heap_caps_dump(self.caps.toRaw());
    }
    /// Return the usable allocation size including alignment overhead.
    pub fn allocatedSize(_: Self, ptr: ?*anyopaque) usize {
        return sys.heap_caps_get_allocated_size(ptr);
    }
    /// Return the largest contiguous free block in the matching regions.
    pub fn largestFreeBlock(self: Self) usize {
        return sys.heap_caps_get_largest_free_block(self.caps.toRaw());
    }
    /// Return the total size of all matching heap regions.
    pub fn totalSize(self: Self) usize {
        return sys.heap_caps_get_total_size(self.caps.toRaw());
    }
    pub fn freeSize(self: Self) usize {
        return sys.heap_caps_get_free_size(self.caps.toRaw());
    }
    pub fn minimumFreeSize(self: Self) usize {
        return sys.heap_caps_get_minimum_free_size(self.caps.toRaw());
    }
    /// Return the free internal (non-SPIRAM) heap size.
    pub fn internalFreeSize(_: Self) usize {
        return sys.esp_get_free_internal_heap_size();
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return @ptrCast(sys.heap_caps_aligned_alloc(
            alignment.toByteUnits(),
            len,
            self.caps.toRaw(),
        ));
    }

    fn resize(_: *anyopaque, buf: []u8, _: std.mem.Alignment, new_len: usize, _: usize) bool {
        if (new_len <= buf.len) return true;
        if (@TypeOf(sys.heap_caps_get_allocated_size) != void) {
            if (new_len <= sys.heap_caps_get_allocated_size(buf.ptr)) return true;
        }
        return false;
    }

    fn remap(ctx: *anyopaque, memory: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return @ptrCast(sys.heap_caps_realloc(memory.ptr, new_len, self.caps.toRaw()));
    }

    fn free(_: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void {
        sys.heap_caps_free(buf.ptr);
        if (builtin.mode == .Debug) {
            if (!sys.heap_caps_check_integrity_all(true))
                @panic("heap_caps: integrity check failed after free");
        }
    }
};

// ---------------------------------------------------------------------------
// MultiHeapAllocator
// ---------------------------------------------------------------------------

/// `std.mem.Allocator` targeting a specific `multi_heap_handle_t` memory pool.
pub const MultiHeapAllocator = struct {
    handle: sys.multi_heap_handle_t = null,

    const Self = @This();

    /// Create an allocator for a specific multi-heap handle.
    pub fn init(handle: sys.multi_heap_handle_t) Self {
        return .{ .handle = handle };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn allocatedSize(self: Self, p: ?*anyopaque) usize {
        return sys.multi_heap_get_allocated_size(self.handle, p);
    }
    pub fn freeSize(self: Self) usize {
        return sys.multi_heap_free_size(self.handle);
    }
    pub fn minimumFreeSize(self: Self) usize {
        return sys.multi_heap_minimum_free_size(self.handle);
    }

    fn alloc(ctx: *anyopaque, len: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return @ptrCast(sys.multi_heap_malloc(self.handle, len));
    }

    fn resize(ctx: *anyopaque, buf: []u8, _: std.mem.Alignment, new_len: usize, _: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (new_len <= buf.len) return true;
        if (@TypeOf(sys.multi_heap_get_allocated_size) != void) {
            if (new_len <= sys.multi_heap_get_allocated_size(self.handle, buf.ptr))
                return true;
        }
        return false;
    }

    fn remap(ctx: *anyopaque, memory: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return @ptrCast(sys.multi_heap_realloc(self.handle, memory.ptr, new_len));
    }

    fn free(ctx: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        sys.multi_heap_free(self.handle, buf.ptr);
        if (builtin.mode == .Debug) {
            if (!sys.multi_heap_check(self.handle, true))
                @panic("multi_heap: integrity check failed after free");
        }
    }
};

// ---------------------------------------------------------------------------
// VPortAllocator
// ---------------------------------------------------------------------------

/// `std.mem.Allocator` using FreeRTOS `pvPortMalloc` / `vPortFree`.
///
/// Use this when interfacing with code that expects the FreeRTOS heap.
pub const VPortAllocator = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    pub fn freeSize(_: Self) usize {
        return sys.xPortGetFreeHeapSize();
    }
    pub fn minimumFreeSize(_: Self) usize {
        return sys.xPortGetMinimumEverFreeHeapSize();
    }

    fn alloc(_: *anyopaque, len: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        return @ptrCast(sys.pvPortMalloc(len));
    }

    fn resize(_: *anyopaque, buf: []u8, _: std.mem.Alignment, new_len: usize, _: usize) bool {
        return new_len <= buf.len;
    }

    fn remap(_: *anyopaque, memory: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
        const new_ptr = sys.pvPortMalloc(new_len) orelse return null;
        @memcpy(@as([*]u8, @ptrCast(new_ptr))[0..@min(memory.len, new_len)], memory[0..@min(memory.len, new_len)]);
        sys.vPortFree(memory.ptr);
        return @ptrCast(new_ptr);
    }

    fn free(_: *anyopaque, buf: []u8, _: std.mem.Alignment, _: usize) void {
        sys.vPortFree(buf.ptr);
    }
};

// ---------------------------------------------------------------------------
// TRACE
// ---------------------------------------------------------------------------

/// Heap-trace leak detection helpers.
///
/// Use `initStandalone`, `start`/`stop`, then `dump` or `summary` to
/// find memory leaks during development.
pub const TRACE = struct {
    /// Initialise standalone heap tracing with a pre-allocated record buffer.
    pub fn initStandalone(record_buffer: [*c]sys.heap_trace_record_t, num_records: usize) !void {
        try errors.espCheckError(sys.heap_trace_init_standalone(record_buffer, num_records));
    }
    /// Initialise heap tracing in host-stream mode (SystemView etc.).
    pub fn initTohost() !void {
        try errors.espCheckError(sys.heap_trace_init_tohost());
    }
    /// Start recording heap allocations.
    pub fn start(mode: sys.heap_trace_mode_t) !void {
        try errors.espCheckError(sys.heap_trace_start(mode));
    }
    /// Stop recording heap allocations.
    pub fn stop() !void {
        try errors.espCheckError(sys.heap_trace_stop());
    }
    /// Resume recording after a `stop`.
    pub fn @"resume"() !void {
        try errors.espCheckError(sys.heap_trace_resume());
    }
    /// Return the number of recorded trace entries.
    pub fn getCount() usize {
        return sys.heap_trace_get_count();
    }
    /// Get a specific trace record by index.
    pub fn get(index: usize, record: [*c]sys.heap_trace_record_t) !void {
        try errors.espCheckError(sys.heap_trace_get(index, record));
    }
    /// Print all trace records to the console.
    pub fn dump() void {
        sys.heap_trace_dump();
    }
    /// Print trace records filtered by capability flags.
    pub fn dumpCaps(caps: Caps) void {
        sys.heap_trace_dump_caps(caps.toRaw());
    }
    /// Retrieve a summary of traced allocations.
    pub fn summary(sum: [*c]sys.heap_trace_summary_t) !void {
        try errors.espCheckError(sys.heap_trace_summary(sum));
    }
};
