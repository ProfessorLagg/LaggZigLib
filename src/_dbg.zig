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
    test_timer();
}


fn test_timer() void {
    const timer = lib.time.Timer.init();

    const itercount: comptime_int = 9;
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var dt_arr: [itercount]u64 = undefined;
    var t0: u64 = timer.timestamp_ns();
    for (0..itercount) |i| {
        const t1: u64 = timer.timestamp_ns();
        dt_arr[i] = t1 - t0;
        t0 = t1;
    }
    for (dt_arr) |dt| {
        lib.fmt.formatPanic(writer, "dt = {d}ns\n", .{dt});
    }
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
