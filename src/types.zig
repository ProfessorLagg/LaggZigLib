const std = @import("std");

pub fn isNumberType(comptime T: type) bool {
    const Ti = comptime @typeInfo(T);
    return switch (Ti) {
        .int, .float, .comptime_float, .comptime_int => true,
        else => false,
    };
}
pub fn isNumber(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isNumberType(T);
}
pub fn isIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int;
}
pub fn isInteger(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isIntegerType(T);
}
pub fn isUnsignedIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int and Ti.int.signedness == .unsigned;
}
pub fn isUnsignedInteger(v: anytype) bool {
    return isUnsignedIntegerType(@TypeOf(v));
}
pub fn isSignedIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int and Ti.int.signedness == .signed;
}
pub fn isSignedInteger(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isSignedIntegerType(T);
}
pub fn isFloatType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .float;
}
pub fn isFloat(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isSignedIntegerType(T);
}
