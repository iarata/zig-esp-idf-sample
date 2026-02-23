//! # POSIX pthread Bindings (`pthread`)
//!
//! **What:** Raw type and function declarations for the POSIX pthread API as
//! exposed by ESP-IDF's newlib/FreeRTOS compatibility layer.
//!
//! **What it does:** Provides `extern struct` types for `pthread_t`,
//! `pthread_attr_t`, `pthread_mutex_t`, `pthread_mutexattr_t`,
//! `pthread_cond_t`, `pthread_condattr_t`, `pthread_key_t`,
//! `pthread_once_t`, `sched_param`, and `pthread_cleanup_context`, plus
//! `extern fn` declarations for the full mutex, condition-variable, thread
//! creation/join, TLS key, and cancel API.
//!
//! **How:** Direct `extern` declarations that resolve against ESP-IDF's
//! newlib at link time.  No error wrapping — functions return `c_int` per
//! POSIX convention.
//!
//! **When to use:** Porting existing POSIX-based C/C++ code to Zig on ESP32,
//! or when a library requires pthread support.  **For new code, prefer the
//! `rtos` module** (FreeRTOS native tasks, semaphores, etc.) which is more
//! memory-efficient and better integrated with ESP-IDF.
//!
//! **What it takes:** Standard POSIX `pthread_*` call conventions.
//!
//! **Example:**
//! ```zig
//! const pt = idf.pthread;  // (available via idf.sys re-export)
//! var tid: pt.pthread_t = 0;
//! _ = pt.pthread_create(&tid, null, threadFn, null);
//! _ = pt.pthread_join(tid, null);
//! ```

/// POSIX scheduling parameters (thread priority).
pub const sched_param = extern struct {
    sched_priority: c_int = std.mem.zeroes(c_int),
};
/// Yield the processor to another ready-to-run thread.
pub extern fn sched_yield() c_int;
/// POSIX thread identifier (opaque integer handle).
pub const pthread_t = c_uint;
/// Thread creation attributes: stack, scheduling policy, detach state, etc.
pub const pthread_attr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    stackaddr: ?*anyopaque = null,
    stacksize: c_int = std.mem.zeroes(c_int),
    contentionscope: c_int = std.mem.zeroes(c_int),
    inheritsched: c_int = std.mem.zeroes(c_int),
    schedpolicy: c_int = std.mem.zeroes(c_int),
    schedparam: sched_param = std.mem.zeroes(sched_param),
    detachstate: c_int = std.mem.zeroes(c_int),
};
/// POSIX mutex handle (opaque integer).
pub const pthread_mutex_t = c_uint;
/// Mutex attributes: initialization flag, type (normal/recursive/errorcheck), and recursion flag.
pub const pthread_mutexattr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    type: c_int = std.mem.zeroes(c_int),
    recursive: c_int = std.mem.zeroes(c_int),
};
/// POSIX condition variable handle (opaque integer).
pub const pthread_cond_t = c_uint;
/// Condition variable attributes: initialization flag and clock source.
pub const pthread_condattr_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    clock: c_ulong = std.mem.zeroes(c_ulong),
};
/// Thread-local storage key.
pub const pthread_key_t = c_uint;
/// One-time initialization control (ensures a function runs exactly once).
pub const pthread_once_t = extern struct {
    is_initialized: c_int = std.mem.zeroes(c_int),
    init_executed: c_int = std.mem.zeroes(c_int),
};
/// BSD binary time representation (seconds + 64-bit fraction).
pub const bintime = extern struct {
    sec: i64 = std.mem.zeroes(i64),
    frac: u64 = std.mem.zeroes(u64),
};
/// Context for `pthread_cleanup_push`/`pthread_cleanup_pop` cleanup handlers.
pub const pthread_cleanup_context = extern struct {
    _routine: ?*const fn (?*anyopaque) callconv(.C) void = std.mem.zeroes(?*const fn (?*anyopaque) callconv(.C) void),
    _arg: ?*anyopaque = null,
    _canceltype: c_int = std.mem.zeroes(c_int),
    _previous: [*c]pthread_cleanup_context = std.mem.zeroes([*c]pthread_cleanup_context),
};
/// Initialize a mutex attributes object with default values.
pub extern fn pthread_mutexattr_init(__attr: [*c]pthread_mutexattr_t) c_int;
/// Destroy a mutex attributes object.
pub extern fn pthread_mutexattr_destroy(__attr: [*c]pthread_mutexattr_t) c_int;
pub extern fn pthread_mutexattr_getpshared(__attr: [*c]const pthread_mutexattr_t, __pshared: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_setpshared(__attr: [*c]pthread_mutexattr_t, __pshared: c_int) c_int;
pub extern fn pthread_mutexattr_gettype(__attr: [*c]const pthread_mutexattr_t, __kind: [*c]c_int) c_int;
pub extern fn pthread_mutexattr_settype(__attr: [*c]pthread_mutexattr_t, __kind: c_int) c_int;
/// Initialize a mutex with the given attributes (or defaults if null).
pub extern fn pthread_mutex_init(__mutex: [*c]pthread_mutex_t, __attr: [*c]const pthread_mutexattr_t) c_int;
/// Destroy a mutex.
pub extern fn pthread_mutex_destroy(__mutex: [*c]pthread_mutex_t) c_int;
/// Lock a mutex (blocking).
pub extern fn pthread_mutex_lock(__mutex: [*c]pthread_mutex_t) c_int;
/// Try to lock a mutex without blocking. Returns `EBUSY` if already locked.
pub extern fn pthread_mutex_trylock(__mutex: [*c]pthread_mutex_t) c_int;
/// Unlock a mutex.
pub extern fn pthread_mutex_unlock(__mutex: [*c]pthread_mutex_t) c_int;
/// Lock a mutex with an absolute timeout.
pub extern fn pthread_mutex_timedlock(__mutex: [*c]pthread_mutex_t, __timeout: [*c]const timespec) c_int;
pub extern fn pthread_condattr_init(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_destroy(__attr: [*c]pthread_condattr_t) c_int;
pub extern fn pthread_condattr_getclock(noalias __attr: [*c]const pthread_condattr_t, noalias __clock_id: [*c]c_ulong) c_int;
pub extern fn pthread_condattr_setclock(__attr: [*c]pthread_condattr_t, __clock_id: c_ulong) c_int;
pub extern fn pthread_condattr_getpshared(__attr: [*c]const pthread_condattr_t, __pshared: [*c]c_int) c_int;
pub extern fn pthread_condattr_setpshared(__attr: [*c]pthread_condattr_t, __pshared: c_int) c_int;
/// Initialize a condition variable with the given attributes (or defaults if null).
pub extern fn pthread_cond_init(__cond: [*c]pthread_cond_t, __attr: [*c]const pthread_condattr_t) c_int;
/// Destroy a condition variable.
pub extern fn pthread_cond_destroy(__mutex: [*c]pthread_cond_t) c_int;
/// Wake one thread waiting on this condition variable.
pub extern fn pthread_cond_signal(__cond: [*c]pthread_cond_t) c_int;
/// Wake all threads waiting on this condition variable.
pub extern fn pthread_cond_broadcast(__cond: [*c]pthread_cond_t) c_int;
/// Block until the condition variable is signaled (releases and re-acquires the mutex).
pub extern fn pthread_cond_wait(__cond: [*c]pthread_cond_t, __mutex: [*c]pthread_mutex_t) c_int;
/// Block until signaled or the absolute timeout expires.
pub extern fn pthread_cond_timedwait(__cond: [*c]pthread_cond_t, __mutex: [*c]pthread_mutex_t, __abstime: [*c]const timespec) c_int;
pub extern fn pthread_attr_setschedparam(__attr: [*c]pthread_attr_t, __param: [*c]const sched_param) c_int;
pub extern fn pthread_attr_getschedparam(__attr: [*c]const pthread_attr_t, __param: [*c]sched_param) c_int;
pub extern fn pthread_attr_init(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_destroy(__attr: [*c]pthread_attr_t) c_int;
pub extern fn pthread_attr_setstack(attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque, __stacksize: usize) c_int;
pub extern fn pthread_attr_getstack(attr: [*c]const pthread_attr_t, __stackaddr: [*c]?*anyopaque, __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_getstacksize(__attr: [*c]const pthread_attr_t, __stacksize: [*c]usize) c_int;
pub extern fn pthread_attr_setstacksize(__attr: [*c]pthread_attr_t, __stacksize: usize) c_int;
pub extern fn pthread_attr_getstackaddr(__attr: [*c]const pthread_attr_t, __stackaddr: [*c]?*anyopaque) c_int;
pub extern fn pthread_attr_setstackaddr(__attr: [*c]pthread_attr_t, __stackaddr: ?*anyopaque) c_int;
pub extern fn pthread_attr_getdetachstate(__attr: [*c]const pthread_attr_t, __detachstate: [*c]c_int) c_int;
pub extern fn pthread_attr_setdetachstate(__attr: [*c]pthread_attr_t, __detachstate: c_int) c_int;
pub extern fn pthread_attr_getguardsize(__attr: [*c]const pthread_attr_t, __guardsize: [*c]usize) c_int;
pub extern fn pthread_attr_setguardsize(__attr: [*c]pthread_attr_t, __guardsize: usize) c_int;
/// Create a new thread. The thread starts executing `__start_routine(__arg)`.
pub extern fn pthread_create(__pthread: [*c]pthread_t, __attr: [*c]const pthread_attr_t, __start_routine: ?*const fn (?*anyopaque) callconv(.C) ?*anyopaque, __arg: ?*anyopaque) c_int;
/// Wait for a thread to terminate and optionally retrieve its return value.
pub extern fn pthread_join(__pthread: pthread_t, __value_ptr: [*c]?*anyopaque) c_int;
/// Mark a thread as detached (resources freed automatically on exit).
pub extern fn pthread_detach(__pthread: pthread_t) c_int;
/// Terminate the calling thread with the given return value.
pub extern fn pthread_exit(__value_ptr: ?*anyopaque) noreturn;
/// Return the thread ID of the calling thread.
pub extern fn pthread_self() pthread_t;
/// Compare two thread IDs for equality.
pub extern fn pthread_equal(__t1: pthread_t, __t2: pthread_t) c_int;
pub extern fn pthread_getcpuclockid(thread: pthread_t, clock_id: [*c]c_ulong) c_int;
pub extern fn pthread_setconcurrency(new_level: c_int) c_int;
pub extern fn pthread_getconcurrency() c_int;
pub extern fn pthread_yield() void;
/// Ensure an initialization routine runs exactly once.
pub extern fn pthread_once(__once_control: [*c]pthread_once_t, __init_routine: ?*const fn () callconv(.C) void) c_int;
/// Create a thread-local storage key with an optional destructor.
pub extern fn pthread_key_create(__key: [*c]pthread_key_t, __destructor: ?*const fn (?*anyopaque) callconv(.C) void) c_int;
/// Set the value for a thread-local storage key in the calling thread.
pub extern fn pthread_setspecific(__key: pthread_key_t, __value: ?*const anyopaque) c_int;
/// Get the value for a thread-local storage key in the calling thread.
pub extern fn pthread_getspecific(__key: pthread_key_t) ?*anyopaque;
/// Delete a thread-local storage key.
pub extern fn pthread_key_delete(__key: pthread_key_t) c_int;
/// Request cancellation of a thread.
pub extern fn pthread_cancel(__pthread: pthread_t) c_int;
/// Set the cancelability state (enabled/disabled) of the calling thread.
pub extern fn pthread_setcancelstate(__state: c_int, __oldstate: [*c]c_int) c_int;
/// Set the cancelability type (deferred/asynchronous) of the calling thread.
pub extern fn pthread_setcanceltype(__type: c_int, __oldtype: [*c]c_int) c_int;
/// Create a cancellation point in the calling thread.
pub extern fn pthread_testcancel() void;
/// Push a cleanup handler onto the calling thread's cleanup stack (internal).
pub extern fn _pthread_cleanup_push(_context: [*c]pthread_cleanup_context, _routine: ?*const fn (?*anyopaque) callconv(.C) void, _arg: ?*anyopaque) void;
/// Pop and optionally execute a cleanup handler from the calling thread's cleanup stack (internal).
pub extern fn _pthread_cleanup_pop(_context: [*c]pthread_cleanup_context, _execute: c_int) void;
/// POSIX time specification: seconds and nanoseconds.
pub const timespec = extern struct {
    tv_sec: i64 = std.mem.zeroes(i64),
    tv_nsec: c_long = std.mem.zeroes(c_long),
};
/// POSIX interval timer specification (initial value + repeat interval).
pub const itimerspec = extern struct {
    it_interval: timespec = std.mem.zeroes(timespec),
    it_value: timespec = std.mem.zeroes(timespec),
};
const std = @import("std");
// TODO: port zig (std.Thread) to FreeRTOS
