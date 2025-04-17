const builtin = @import("builtin");
const std = @import("std");

pub fn allocPanic(allocator: std.mem.Allocator, comptime T: type, n: usize) []T {
    return allocator.alloc(T, n) catch |err| {
        std.debug.panic("Could not alloc due to error: {any} {any}", .{ err, @errorReturnTrace() });
    };
}

pub fn clone(comptime T: type, allocator: std.mem.Allocator, a: []const T) ![]T {
    const result: []T = try allocator.alloc(T, a.len);
    copy(T, result, a);
    return result;
}
pub fn clonePanic(comptime T: type, allocator: std.mem.Allocator, a: []const T) []T {
    const result: []T = allocPanic(allocator, T, a.len);
    copy(T, result, a);
    return result;
}

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

/// Reverses the ordering of the items in the slice
pub fn reverse(comptime T: type, noalias arr: []T) void {
    var i: usize = arr.len;
    var j: usize = 0;
    while (i > j) {
        const temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
        i -= 1;
        j += 1;
    }
}

/// Rotates arr by n positions
pub fn rotate(comptime T: type, noalias arr: []T, n: usize) void {
    reverse(T, arr[0..]);
    reverse(T, arr[0..n]);
    reverse(T, arr[n..]);
}

inline fn swapTemp(comptime T: type, a: *T, b: *T) void {
    const tmp: T = a.*;
    a.* = b.*;
    b.* = tmp;
}

fn swapXorFn(comptime T: type, comptime castTo: type) (fn (comptime type, *T, *T) void) {
    comptime {
        switch (castTo) {
            u8, u16, u32, u64, usize => {},
            else => @compileError(@typeName(castTo) ++ " is not a valid xor swap type"),
        }

        if (@sizeOf(T) != @sizeOf(castTo)) @compileError("Size of " ++ @typeName(T) ++ "did not match size of castTo type (" ++ @typeName(castTo) ++ ")");
        if (@alignOf(T) != @alignOf(castTo)) @compileError("Alignment of " ++ @typeName(T) ++ "did not match alignment of castTo type (" ++ @typeName(castTo) ++ ")");
    }
    return struct {
        pub fn swapXor(comptime T2: type, x: *T2, y: *T2) void {
            comptime if (T != T2) unreachable;

            const a: *castTo = @ptrFromInt(@intFromPtr(x));
            const b: *castTo = @ptrFromInt(@intFromPtr(y));
            a.* = b.* ^ a.*;
            b.* = a.* ^ b.*;
            a.* = b.* ^ a.*;
        }
    }.swapXor;
}

/// Swaps values between 2 pointers. Uses XOR swap if possible
pub fn swap(comptime T: type, a: *T, b: *T) void {
    const swapFn: fn (comptime type, *T, *T) void = comptime blk: {
        const Tsize: comptime_int = @sizeOf(T);
        const Talign: comptime_int = @sizeOf(T);

        break :blk switch (Tsize) {
            @sizeOf(u8) => if (Talign == @alignOf(u8)) swapXorFn(T, u8),
            @sizeOf(u16) => if (Talign == @alignOf(u16)) swapXorFn(T, u16),
            @sizeOf(u32) => if (Talign == @alignOf(u32)) swapXorFn(T, u32),
            @sizeOf(u64) => if (Talign == @alignOf(u64)) swapXorFn(T, u64),
            else => swapTemp,
        };
    };

    @call(.always_inline, swapFn, .{ T, a, b });
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
