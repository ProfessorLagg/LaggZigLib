const std = @import("std");
const types = @import("types.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");

pub fn VectorIterator(comptime T: type) type {
    comptime {
        const Ti: std.builtin.Type = @typeInfo(T);
        // (T == u8) or (T == u16) or (T == u32) or (T == u64) or (T == usize) or (T == f32) or (T == f64)
        const isValid = (Ti == .pointer) or switch (T) {
            u8, u16, u32, u64, usize, f32, f64 => true,
            else => false,
        };
        if (!isValid) @compileError("Cannot vectorize type " ++ @typeName(T));
        if (std.simd.suggestVectorLength(T) == null) @compileError("Could not get vector length for type " ++ @typeName(T));
    }

    return struct {
        const TSelf = @This();
        pub const veclen: comptime_int = std.simd.suggestVectorLength(T).?;

        /// default value of vector elements
        default_value: T = 0,
        slice: []const T,

        pub fn init(a: []const T) TSelf {
            return TSelf{ .slice = a };
        }

        pub fn next(self: *TSelf) ?@Vector(veclen, T) {
            if (self.slice.len == 0) {
                return null;
            }

            var arr: [veclen]T = undefined;
            @memset(arr[0..], self.default_value);
            if (self.slice.len >= veclen) {
                mem.copy(T, arr[0..], self.slice[0..veclen]);
                self.slice = self.slice[veclen..];
                return arr;
            } else {
                debug.assert(self.slice.len < veclen);
                mem.copy(T, arr[0..], self.slice);
                self.slice = self.slice[self.slice.len..];
                return arr;
            }
        }

        test {
            const l0: comptime_int = 256 / @bitSizeOf(T);
            const l1: comptime_int = l0 + 1;
            var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
            var byteValues: [l1]u8 = undefined;
            prng.fill(std.mem.sliceAsBytes(byteValues[0..]));

            var arr0: [l0]T = undefined;
            var arr1: [l1]T = undefined;
            for (0..arr1.len) |i| {
                arr1[i] = switch (@typeInfo(T)) {
                    .float => @as(T, @floatFromInt(byteValues[i])),
                    .int => @as(T, @intCast(byteValues[i])),
                    else => unreachable,
                };
            }
            mem.copy(T, arr0[0..], arr1[0..arr0.len]);

            prng.fill(std.mem.sliceAsBytes(arr1[0..]));
            var slice0: []T = try std.testing.allocator.alloc(T, l0);
            var slice1: []T = try std.testing.allocator.alloc(T, l1);
            defer std.testing.allocator.free(slice0);
            defer std.testing.allocator.free(slice1);
            mem.copy(T, slice0, arr0[0..]);
            mem.copy(T, slice1, arr1[0..]);

            const runTestFn = struct {
                pub fn f(a: []const T) !void {
                    var iter: TSelf = TSelf.init(a);
                    var L: usize = 0;
                    while (iter.next()) |vec| {
                        const testCount: usize = @min(TSelf.veclen, a.len - L);
                        for (0..testCount) |i| {
                            try std.testing.expectEqual(a[L], vec[i]);
                            L += 1;
                        }
                    }
                }
            }.f;

            try runTestFn(arr0[0..]);
            try runTestFn(arr1[0..]);
            try runTestFn(slice0[0..]);
            try runTestFn(slice1[0..]);
        }
    };
}

test "VectorIterator" {
    _ = VectorIterator(u8);
    _ = VectorIterator(u16);
    _ = VectorIterator(u32);
    _ = VectorIterator(u64);
    _ = VectorIterator(f32);
    _ = VectorIterator(f64);
}
