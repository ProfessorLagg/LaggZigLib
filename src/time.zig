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

pub fn startTimerPanic() std.time.Timer {
    return std.time.Timer.start() catch |err| {
        std.log.err("Could not start std.time.Timer due to err: {any}{any}", .{ err, @errorReturnTrace() });
        @panic("Could not start std.time.Timer");
    };
}

pub const TimeSource = struct {
    const VTable = struct {
        timestamp_s: *const fn () u64,
        timestamp_ms: *const fn () u64,
        timestamp_us: *const fn () u64,
        timestamp_ns: *const fn () u64,
    };

    vtable: VTable,

    pub fn init() TimeSource {
        const tscTimer = rdtscTimer.init();
        if (tscTimer != null) {
            std.log.debug("Using Timer type: {s}({d} MHz)", .{ @typeName(rdtscTimer), rdtscTimer.tsc_per_s / 1_000_000 });
            return tscTimer.?;
        }

        std.log.debug("Using Timer type: {s}", .{@typeName(stdTimer)});
        return stdTimer.init();
    }
    pub fn timestamp_s(self: *const TimeSource) u64 {
        return self.vtable.timestamp_s();
    }
    pub fn timestamp_ms(self: *const TimeSource) u64 {
        return self.vtable.timestamp_ms();
    }
    pub fn timestamp_us(self: *const TimeSource) u64 {
        return self.vtable.timestamp_us();
    }
    pub fn timestamp_ns(self: *const TimeSource) u64 {
        return self.vtable.timestamp_ns();
    }
};

const rdtscTimer = struct {
    const TSelf = @This();
    /// How many tsc's happen per second
    var tsc_per_s: u64 = 0;

    var tsc_mod_s: f64 = 0;
    var tsc_mod_ms: f64 = 0;
    var tsc_mod_us: f64 = 0;
    var tsc_mod_ns: f64 = 0;

    /// Tries to read the tsc frequency in Hz from cpuid leaf 0x15 and/or 0x16
    fn loadTSCFrequency_CPUID() ?u64 {
        const CPUID = @import("intrinsics.zig").x86.CPUID;

        const leaf_15h = CPUID.readLeaf(0x15);
        const leaf_16h = CPUID.readLeaf(0x16);

        // Casting the u32 register values to u64
        // This is done to ensure we can actually sture the full frequency in Hz
        const CPUID_15H_EAX: u64 = leaf_15h.eax;
        const CPUID_15H_EBX: u64 = leaf_15h.ebx;
        const CPUID_15H_ECX: u64 = leaf_15h.ecx;
        const CPUID_16H_EAX: u64 = leaf_16h.eax;

        if (CPUID_15H_EAX != 0 and CPUID_15H_EBX != 0) {
            return CPUID_15H_ECX * (CPUID_15H_EBX / CPUID_15H_EAX);
        } else if (CPUID_15H_ECX == 0 and CPUID_16H_EAX != 0) {
            return CPUID_16H_EAX * 1_000_000;
        }
        return null;
    }
    /// Tries to get the TSC frequency from the windows registry
    fn loadTSCFrequency_windowsRegistry() ?u64 {
        comptime std.debug.assert(builtin.target.os.tag == .windows);

        // reading key Computer\HKEY_LOCAL_MACHINE\HARDWARE\DESCRIPTION\System\CentralProcessor\0
        const advapi32 = std.os.windows.advapi32;
        const LPCWSTR = std.os.windows.LPCWSTR;
        const DWORD = std.os.windows.DWORD;

        // https://learn.microsoft.com/en-us/windows/win32/api/winreg/nf-winreg-reggetvaluew
        const hkey = std.os.windows.HKEY_LOCAL_MACHINE;
        const lpSubKey: LPCWSTR = std.unicode.utf8ToUtf16LeStringLiteral("HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0");
        const lpValue: LPCWSTR = std.unicode.utf8ToUtf16LeStringLiteral("~MHz");
        const dwFlags: DWORD = 0x20000010;

        // const pdwType: ?*DWORD = null;
        var pvData: [@sizeOf(DWORD)]u8 = undefined;
        @memset(pvData[0..], 0);
        var pcbData: DWORD = @sizeOf(@TypeOf(pvData));

        const status = advapi32.RegGetValueW(hkey, lpSubKey, lpValue, dwFlags, null, &pvData, &pcbData);
        if (status != 0) {
            std.log.err("returned error status code {d} (0x{X})", .{ status, status });
            return null;
        }

        const MHz: DWORD = @as(DWORD, @bitCast(pvData));
        const Hz: u64 = @as(u64, @intCast(MHz)) * @as(u64, 1_000_000);
        return Hz;
    }

    fn loadTSCFrequency() ?u64 {
        if (builtin.target.cpu.arch != .x86_64) return null;
        var freq: ?u64 = loadTSCFrequency_CPUID();
        if (freq != null and freq.? > 0) return freq.?;

        if (builtin.target.os.tag == .windows) {
            freq = loadTSCFrequency_windowsRegistry();
            if (freq != null and freq.? > 0) return freq.?;
        }

        return null;
    }
    /// Attemps to set the tsc_per_xx variables
    fn tryLoadTSCFrequency() bool {
        tsc_per_s = loadTSCFrequency() orelse 0;
        if (tsc_per_s != 0) {
            const tsc_per_s_f: f64 = @floatFromInt(tsc_per_s);
            tsc_mod_s = @as(f64, 1.0) / tsc_per_s_f;
            tsc_mod_ms = @as(f64, std.time.ms_per_s) / tsc_per_s_f;
            tsc_mod_us = @as(f64, std.time.us_per_s) / tsc_per_s_f;
            tsc_mod_ns = @as(f64, std.time.ns_per_s) / tsc_per_s_f;
        }

        return tsc_per_s > 0;
    }

    pub fn init() ?TimeSource {
        // TODO Ensure Invariant RDTSC
        if (tsc_per_s == 0 and (!tryLoadTSCFrequency())) return null;
        return TimeSource{ .vtable = TimeSource.VTable{
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
        const tsc_f: f64 = @floatFromInt(tsc);
        const res_f: f64 = tsc_f * tsc_mod_s;
        return @intFromFloat(res_f);
    }
    fn _ms() u64 {
        const tsc = rdtsc_fenced();
        const tsc_f: f64 = @floatFromInt(tsc);
        const res_f: f64 = tsc_f * tsc_mod_ms;
        return @intFromFloat(res_f);
    }
    fn _us() u64 {
        const tsc = rdtsc_fenced();
        const tsc_f: f64 = @floatFromInt(tsc);
        const res_f: f64 = tsc_f * tsc_mod_us;
        return @intFromFloat(res_f);
    }
    fn _ns() u64 {
        const tsc = rdtsc_fenced();
        const tsc_f: f64 = @floatFromInt(tsc);
        const res_f: f64 = tsc_f * tsc_mod_ns;
        return @intFromFloat(res_f);
    }
};

const stdTimer = struct {
    const TSelf = @This();
    pub fn init() TimeSource {
        return TimeSource{ .vtable = TimeSource.VTable{
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
