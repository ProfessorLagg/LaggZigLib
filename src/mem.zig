const builtin = @import("builtin");
const std = @import("std");

fn copyBytes_generic(noalias dst: []u8, noalias src: []const u8) void {
    std.debug.assert(dst.len >= src.len);
    for (dst[0..src.len], src) |*d, s| d.* = s;
}

fn copyBytes_x86_64(noalias dst: []u8, noalias src: []const u8) void {
    comptime if (builtin.cpu.arch != .x86_64) @compileError("This function only works for x86_64 targets. You probably want copyBytes_generic");

    @import("intrinsics.zig").x86_x64.repmovsb(dst.ptr, src.ptr, src.len);
}

const copyBytes: @TypeOf(copyBytes_generic) = switch (builtin.cpu.arch) {
    .x86_64 => copyBytes_x86_64,
    else => copyBytes_generic,
};

/// Copies all of src into dst starting at index 0
pub fn copy(comptime T: type, noalias dst: []T, noalias src: []const T) void {
    std.debug.assert(dst.len >= src.len);

    const dst_u8: []u8 = std.mem.sliceAsBytes(dst);
    const src_u8: []const u8 = std.mem.sliceAsBytes(src);
    copyBytes(dst_u8, src_u8);
}

/// Constant time keybased byte swap
pub fn ctswap(comptime Tk: type, k: Tk, a: []u8, b: []u8) void {
    comptime if (!@import("types.zig").isUnsignedIntegerType(Tk)) @compileError("Key must be an unsigned integer type");
    const bitsize = comptime @bitSizeOf(Tk);
    std.debug.assert(a.len == bitsize);
    std.debug.assert(b.len == bitsize);

    var ktemp: Tk = k;
    for (0..bitsize) |i| {
        const bit: u1 = @truncate(ktemp & 1);
        const inv: u1 = ~bit;

        const atemp = a[i];
        const btemp = b[i];

        a[i] = (btemp * bit) + (atemp * inv);
        b[i] = (atemp * bit) + (btemp * inv);

        ktemp = ktemp >> 1;
    }
}

test "copy" {
    const prng: type = std.Random.DefaultPrng;
    const allocator = std.testing.allocator;
    const page_size = std.heap.pageSize();

    const src_page: []u8 = try allocator.alloc(u8, page_size);
    defer allocator.free(src_page);

    const dst_page: []u8 = try allocator.alloc(u8, page_size);
    defer allocator.free(dst_page);

    var rand: prng = prng.init(std.testing.random_seed);
    rand.fill(src_page);

    copy(u8, dst_page, src_page);

    try std.testing.expectEqualSlices(u8, src_page, dst_page);
}
