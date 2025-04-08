const std = @import("std");

pub fn isEven(comptime T: type, num: T) bool {
    comptime if (!@import("types.zig").isUnsignedIntegerType(T)) @compileError("Expected unsigned integer, but found " + @typeName(T));
    return (num & @as(T, 1)) == 0;
}

pub fn isUneven(comptime T: type, num: T) bool {
    comptime if (!@import("types.zig").isUnsignedIntegerType(T)) @compileError("Expected unsigned integer, but found " + @typeName(T));
    return (num & @as(T, 1)) == 1;
}

test "bool<->u8 conversion" {
    const t: bool = true;
    const f: bool = false;

    const t_bool_to_int: u8 = @intFromBool(t);
    const f_bool_to_int: u8 = @intFromBool(f);
    const t_int_to_bool: bool = t_bool_to_int == 1;
    const f_int_to_bool: bool = t_bool_to_int == 0;

    try std.testing.expectEqual(1, t_bool_to_int);
    try std.testing.expectEqual(0, f_bool_to_int);
    try std.testing.expectEqual(true, t_int_to_bool);
    try std.testing.expectEqual(false, f_int_to_bool);
}