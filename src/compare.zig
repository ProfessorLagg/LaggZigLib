const std = @import("std");
const types = @import("types.zig");

pub const CompareResult = enum(i8) { less = -1, equal = 0, greater = 1 };

pub fn Comparison(comptime T: type) type {
    return fn (T, T) CompareResult;
}

pub fn ComparisonR(comptime T: type) type {
    return fn (*const T, *const T) CompareResult;
}

fn compareNumberVectorFn(comptime T: type) Comparison(T) {
    types.assertIsNumberVectorType(T);
    const vlen: comptime_int = comptime @typeInfo(T).vector.len;
    comptime if (vlen >= std.math.maxInt(i8)) unreachable;
    return struct {
        pub fn cmp(a: T, b: T) CompareResult {
            const lt: @Vector(vlen, i8) = @as(@Vector(vlen, i8), @intFromBool(a < b)) * @as(@Vector(vlen, i8), -1); // -1 if true, 0 if false
            const gt: @Vector(vlen, i8) = @as(@Vector(vlen, i8), @intFromBool(a > b)); // 1 if true, 0 if false
            const cr: @Vector(vlen, i8) = lt + gt;
            inline for (0..vlen) |i| {
                if (cr[i] != 0) return @enumFromInt(cr[i]);
            }
            return .equal;
        }
    }.cmp;
}
pub fn compareNumberFn(comptime T: type) Comparison(T) {
    types.assertIsNumberType(T);
    return struct {
        pub fn cmp(a: T, b: T) CompareResult {
            const lt: i8 = @intFromBool(a < b) * @as(i8, -1); // -1 if true, 0 if false
            const gt: i8 = @intFromBool(a > b); // 1 if true, 0 if false
            return @as(CompareResult, @enumFromInt(lt + gt));
        }
    }.cmp;
}

pub fn compareNumber(a: anytype, b: anytype) CompareResult {
    const T: type = comptime @TypeOf(a);
    comptime {
        const Tb: type = @TypeOf(b);
        if (T != Tb) @compileError("expected a and b to be the same type, but found: " + @typeName(T) ++ " and " ++ @typeName(Tb));
        types.assertIsNumberOrNumberVectorType(T);
    }
    const Ti: std.builtin.Type = @typeInfo(T);
    const comparison: Comparison(T) = comptime switch (Ti) {
        .vector => compareNumberVectorFn(T),
        .int, .comptime_int, .float, .comptime_float => compareNumberFn(T),

        else => unreachable,
    };
    return comparison(a, b);
}
