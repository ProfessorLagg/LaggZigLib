const builtin = @import("builtin");
const std = @import("std");
const lib = @import("_root.zig");
const intrinsics = lib.intrinsics;

pub const std_options: std.Options = .{
    // Set the log level to info to .debug. use the scope levels instead
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .debug,
        .ReleaseSmall => .debug,
        .ReleaseFast => .debug,
    },
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .CPUID, .level = .err },
    },
};

pub fn main() !void {
    //try test_cpuid();
    // _ = lib.intrinsics.CPUID.readParseAll();
    // try test_rdtsc();
    test_TimeSource();
}

fn test_TimeSource() void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    const lib_timer = lib.time.TimeSource.init();
    var std_timer = lib.time.startTimerPanic();

    const lib_pre = lib_timer.timestamp_ns();
    std_timer.reset();
    for (0..(std.time.ms_per_s / 2)) |_| {
        std.time.sleep(std.time.ns_per_ms);
    }
    const std_delta = std_timer.read();
    const lib_post = lib_timer.timestamp_ns();
    const lib_delta = lib_post - lib_pre;

    const delta_diff: u64 = @max(std_delta, lib_delta) - @min(std_delta, lib_delta);
    const std_delta_f: f128 = @floatFromInt(std_delta);
    const lib_delta_f: f128 = @floatFromInt(lib_delta);
    const delta_diff_rel: f128 = (@max(std_delta_f, lib_delta_f) / @min(std_delta_f, lib_delta_f)) - 1.0;
    lib.fmt.formatPanic(writer, "lib:  {d} ns\n", .{lib_delta});
    lib.fmt.formatPanic(writer, "std:  {d} ns\n", .{std_delta});
    lib.fmt.formatPanic(writer, "diff: {d} ns | {d:.9}%\n", .{ delta_diff, delta_diff_rel * 100.0 });
}

fn test_rdtsc() !void {
    const itercount: comptime_int = 65_356;
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var tsc0: u64 = intrinsics.rdtsc();
    var tsc1: u64 = undefined;
    for (0..itercount) |i| {
        tsc1 = intrinsics.rdtsc();
        const tscD: i128 = @as(i128, @intCast(tsc1)) - @as(i128, @intCast(tsc0));
        try std.testing.expect(tscD > 0);
        tsc0 = tsc1;
        lib.fmt.formatPanic(writer, "tsc {d:5} = {d}\n", .{ i, tsc1 });
        // std.time.sleep(sleep_nanoseconds);
    }
}

fn test_cpuid() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    const basic_leaves = try lib.intrinsics.CPUID.readAllBasicLeaves(allocator);
    defer allocator.free(basic_leaves);
    for (0..basic_leaves.len) |leaf_i| {
        const leaf = basic_leaves[leaf_i];
        lib.fmt.formatPanic(writer, "leaf {X:2}H = eax: {x:8}, ebx: {x:8}, ecx: {x:8}, edx: {x:8}\n", .{ leaf_i, leaf.eax, leaf.ebx, leaf.ecx, leaf.edx });
    }

    lib.fmt.formatPanic(writer, "tsc frequency: {d}  Hz\n", .{lib.intrinsics.CPUID.tscFrequencyHz() orelse 0});
    lib.fmt.formatPanic(writer, "CPUID struct: {any}", .{lib.intrinsics.CPUID.readParseAll()});
}

fn test_repmovsb() !void {
    const prng: type = std.Random.DefaultPrng;
    const allocator = std.heap.page_allocator;
    const page_size = std.heap.pageSize();

    const src_page: []u8 = try allocator.alloc(u8, page_size);
    defer allocator.free(src_page);

    const dst_page: []u8 = try allocator.alloc(u8, page_size);
    defer allocator.free(dst_page);

    var rand: prng = prng.init(std.testing.random_seed);
    rand.fill(src_page);

    lib.intrinsics.repmovsb(dst_page.ptr, src_page.ptr, src_page.len);

    try std.testing.expectEqualSlices(u8, src_page, dst_page);
}

noinline fn test_tsc_via_rdmsr() void {
    // const IA32_TIME_STAMP_COUNTER = 0x10;
    for (0..1000) |_| {
        // const tsc: u64 = asm volatile ("mov $16, %eax\n" ++ "rdmsr\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
        //     : [ret] "={rax}" (-> u64),
        //     :
        //     : "eax", "rdx", "edx"
        // );
        const tsc = intrinsics.rdtsc_fenced();
        std.log.debug("tsc: {d}", .{tsc});
    }
}
