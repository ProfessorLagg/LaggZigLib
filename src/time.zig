const builtin = @import("builtin");
const std = @import("std");
const debug = @import("debug.zig");

var init_std_timestamp: i128 = 0;
fn stdTimestamp() u64 {
    const init_is_0 = init_std_timestamp == 0;
    init_std_timestamp = init_std_timestamp + (std.time.nanoTimestamp() * @as(i128, @intCast(@intFromBool(init_is_0))));
    const dt: u128 = @intCast(std.time.nanoTimestamp() - init_std_timestamp);
    return @truncate(dt);
}

pub const Timer = struct {
    const VTable = struct {
        timestamp_s: *const fn () u64,
        timestamp_ms: *const fn () u64,
        timestamp_us: *const fn () u64,
        timestamp_ns: *const fn () u64,
    };

    vtable: VTable,

    pub fn init() Timer {
        const tscTimer = rdtscTimer.init();
        if (tscTimer != null) {
            std.log.debug("Using Timer type: {s}", .{@typeName(rdtscTimer)});
            return tscTimer.?;
        }

        std.log.debug("Using Timer type: {s}", .{@typeName(stdTimer)});
        return stdTimer.init();
    }
    pub fn timestamp_s(self: *const Timer) u64 {
        return self.vtable.timestamp_s();
    }
    pub fn timestamp_ms(self: *const Timer) u64 {
        return self.vtable.timestamp_ms();
    }
    pub fn timestamp_us(self: *const Timer) u64 {
        return self.vtable.timestamp_us();
    }
    pub fn timestamp_ns(self: *const Timer) u64 {
        return self.vtable.timestamp_ns();
    }
};

const rdtscTimer = struct {
    const TSelf = @This();
    /// How many tsc's happen per second
    var tsc_per_s: u64 = 0;
    var tsc_per_ms: u64 = 0;
    var tsc_per_us: u64 = 0;
    var tsc_per_ns: u64 = 0;

    fn getFrequency() ?u64 {
        if (builtin.target.cpu.arch != .x86_64) return null;
        return @import("intrinsics.zig").x86_x64.CPUID.tscFrequencyHz();
    }
    /// Attemps to set the tsc_per_xx variables
    fn tryGetFrequency() bool {
        tsc_per_s = getFrequency() orelse 0;
        tsc_per_ms = tsc_per_s / std.time.ms_per_s;
        tsc_per_us = tsc_per_s / std.time.us_per_s;
        tsc_per_ns = tsc_per_s / std.time.ns_per_s;
        return tsc_per_s > 0;
    }

    pub fn init() ?Timer {
        // TODO Ensure Invariant RDTSC
        if (tsc_per_s == 0 and (!tryGetFrequency())) return null;
        return Timer{ .vtable = Timer.VTable{
            .timestamp_s = &TSelf._s,
            .timestamp_ms = &TSelf._ms,
            .timestamp_us = &TSelf._us,
            .timestamp_ns = &TSelf._ns,
        } };
    }

    fn rdtsc_fenced() u64 {
        comptime debug.assert(builtin.target.cpu.arch == .x86_64);
        return @import("intrinsics.zig").x86_x64.rdtsc_fenced();
    }

    fn _s() u64 {
        const tsc = rdtsc_fenced();
        return tsc / tsc_per_s;
    }
    fn _ms() u64 {
        const tsc = rdtsc_fenced();
        return tsc / tsc_per_ms;
    }
    fn _us() u64 {
        const tsc = rdtsc_fenced();
        return tsc / tsc_per_us;
    }
    fn _ns() u64 {
        const tsc = rdtsc_fenced();
        return tsc / tsc_per_ns;
    }
};

const stdTimer = struct {
    const TSelf = @This();
    pub fn init() Timer {
        return Timer{ .vtable = Timer.VTable{
            .timestamp_s = TSelf._s,
            .timestamp_ms = TSelf._ms,
            .timestamp_us = TSelf._us,
            .timestamp_ns = TSelf._ns,
        } };
    }

    /// Timestamp value in seconds
    pub fn _s() u64 {
        const max_t: i128 = comptime @as(i128, @intCast(std.math.maxInt(u64)));
        const t: i128 = @divFloor(std.time.nanoTimestamp(), std.time.ns_per_s);
        debug.assert(t > 0);
        debug.assert(t < max_t);
        return @intCast(t);
    }
    fn _ms() u64 {
        const max_t: i128 = comptime @as(i128, @intCast(std.math.maxInt(u64)));
        const t: i128 = @divFloor(std.time.nanoTimestamp(), std.time.ns_per_ms);
        debug.assert(t > 0);
        debug.assert(t < max_t);
        return @intCast(t);
    }
    fn _us() u64 {
        const max_t: i128 = comptime @as(i128, @intCast(std.math.maxInt(u64)));
        const t: i128 = @divFloor(std.time.nanoTimestamp(), std.time.ns_per_us);
        debug.assert(t > 0);
        debug.assert(t < max_t);
        return @intCast(t);
    }
    fn _ns() u64 {
        const max_t: i128 = comptime @as(i128, @intCast(std.math.maxInt(u64)));
        const t: i128 = std.time.nanoTimestamp();
        debug.assert(t > 0);
        debug.assert(t < max_t);
        return @intCast(t);
    }
};
