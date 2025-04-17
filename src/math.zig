const types = @import("types.zig");

pub fn isEven(comptime T: type, num: T) bool {
    comptime if (!@import("types.zig").isUnsignedIntegerType(T)) @compileError("Expected unsigned integer, but found " + @typeName(T));
    return (num & @as(T, 1)) == 0;
}

pub fn isUneven(comptime T: type, num: T) bool {
    comptime if (!@import("types.zig").isUnsignedIntegerType(T)) @compileError("Expected unsigned integer, but found " + @typeName(T));
    return (num & @as(T, 1)) == 1;
}

/// Maps integers or vectors of integers from one range to another
inline fn mapInt(comptime T: type, x: T, input_start: T, input_end: T, output_start: T, output_end: T) T {
    comptime if (!(types.isIntegerType(T) or types.isIntegerVectorType(T))) @compileError("Expected integer or vector of integers, but found: " ++ @typeName(T));
    return (x - input_start) / (input_end - input_start) * (output_end - output_start) + output_start;
}
/// Maps floats or vectors of floats from one range to another
inline fn mapFloat(comptime T: type, x: T, input_start: T, input_end: T, output_start: T, output_end: T) T {
    @setFloatMode(.optimized);
    comptime if (!(types.isFloatType(T) or types.isFloatVectorType(T))) @compileError("Expected float or vector of floats, but found: " ++ @typeName(T));
    const a = (x - input_start) / (input_end - input_start);
    const b = output_end - output_start;
    return @mulAdd(T, a, b, output_start);
}
/// Maps a number from one range to another range
pub fn map(comptime T: type, x: T, input_start: T, input_end: T, output_start: T, output_end: T) T {
    const mapfn = comptime blk: {
        if (types.isIntegerType(T)) break :blk mapInt;
        if (types.isIntegerVectorType(T)) break :blk mapInt;
        if (types.isFloatType(T)) break :blk mapFloat;
        if (types.isFloatVectorType(T)) break :blk mapFloat;
        unreachable;
    };
    return @call(.always_inline, mapfn, .{ T, x, input_start, input_end, output_start, output_end });
}

inline fn sumIntFn(comptime T: type) (fn ([]const T) T) {
    comptime {
        return struct {
            pub fn f(a: []const T) T {
                // TODO Vectorize this
                var r: T = 0;
                for (0..a.len) |i| {
                    r +%= a[i];
                }
                return r;
            }
        }.f;
    }
}
inline fn sumFloatFn(comptime T: type) (fn ([]const T) T) {
    comptime types.assertIsFloatType(T);
    return struct {
        pub fn f(a: []const T) T {
            @setFloatMode(.optimized);
            // TODO Vectorize this
            var r: T = 0;
            for (0..a.len) |i| {
                r += a[i];
            }
            return r;
        }
    }.f;
}
/// Sums an array of numbers. For integers, the result will wrap instead of overflow
pub fn sum(comptime T: type, a: []const T) T {
    const sumFn = comptime blk: {
        types.assertIsNumberType(T);
        if (types.isIntegerType(T)) break :blk sumIntFn(T);
        if (types.isFloatType(T)) break :blk sumFloatFn(T);
    };

    return sumFn(a);
}

test "map" {
    // TODO
}
