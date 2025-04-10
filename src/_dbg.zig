const builtin = @import("builtin");
const std = @import("std");
const laggLibZig = @import("_root.zig");
const intrinsics = laggLibZig.intrinsics;

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
    const basicLeaves = [_]intrinsics.CPUID.RegisterResult{
        .{ .eax = 13, .ebx = 1752462657, .ecx = 1145913699, .edx = 1769238117 },
        .{ .eax = 10620690, .ebx = 34605056, .ecx = 4275581443, .edx = 395049983 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 1, .edx = 0 },
        .{ .eax = 0, .ebx = 563909545, .ecx = 4195972, .edx = 16 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
        .{ .eax = 0, .ebx = 0, .ecx = 0, .edx = 0 },
    };
    _ = &basicLeaves;

    test_tsc_via_rdmsr();
    //try test_repmovsb();
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

    laggLibZig.intrinsics.repmovsb(dst_page.ptr, src_page.ptr, src_page.len);

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
