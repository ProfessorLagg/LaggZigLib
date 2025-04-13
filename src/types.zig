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
pub fn assertIsNumberType(comptime T: type) void {
    comptime if (!isNumberType(T)) @compileError("Expected number, but found: " ++ @typeName(T));
}

pub fn isIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int;
}
pub fn isInteger(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isIntegerType(T);
}
pub fn assertIsIntegerType(comptime T: type) void {
    comptime if (!isIntegerType(T)) @compileError("Expected integer, but found: " ++ @typeName(T));
}

pub fn isUnsignedIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int and Ti.int.signedness == .unsigned;
}
pub fn isUnsignedInteger(v: anytype) bool {
    return isUnsignedIntegerType(@TypeOf(v));
}
pub fn assertIsUnsignedIntegerType(comptime T: type) void {
    comptime if (!isUnsignedIntegerType(T)) @compileError("Expected unsigned integer, but found: " ++ @typeName(T));
}

pub fn isSignedIntegerType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .int and Ti.int.signedness == .signed;
}
pub fn isSignedInteger(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isSignedIntegerType(T);
}
pub fn assertIsSignedIntegerType(comptime T: type) void {
    comptime if (!isSignedIntegerType(T)) @compileError("Expected signed integer, but found: " ++ @typeName(T));
}

pub fn isFloatType(comptime T: type) bool {
    const Ti = @typeInfo(T);
    return Ti == .float;
}
pub fn isFloat(v: anytype) bool {
    const T = comptime @TypeOf(v);
    return isSignedIntegerType(T);
}
pub fn assertIsFloatType(comptime T: type) void {
    comptime if (!isFloatType(T)) @compileError("Expected floating point, but found: " ++ @typeName(T));
}

pub fn isVectorType(comptime T: type) bool {
    return @typeInfo(T) == .vector;
}
pub fn isVector(v: anytype) bool {
    const T: type = comptime @TypeOf(v);
    return isVectorType(T);
}
pub fn assertIsVectorType(comptime T: type) void {
    comptime if (!isVectorType(T)) @compileError("Expected vector, but found: " ++ @typeName(T));
}

pub fn isNumberVectorType(comptime T: type) bool {
    const Ti: std.builtin.Type = @typeInfo(T);
    if (Ti != .vector) return false;
    return isNumber(Ti.vector.child);
}
pub fn isNumberVector(v: anytype) bool {
    const T: type = @TypeOf(v);
    return isNumberType(T);
}
pub fn assertIsNumberVectorType(comptime T: type) void {
    comptime if (!isNumberVectorType(T)) @compileError("Expected vector of numbers, but found: " ++ @typeName(T));
}

pub fn isIntegerVectorType(comptime T: type) bool {
    const Ti: std.builtin.Type = @typeInfo(T);
    return Ti == .vector and isIntegerType(Ti.vector.child);
}
pub fn isIntegerVector(v: anytype) bool {
    const T: type = comptime @TypeOf(v);
    return isIntegerVectorType(T);
}
pub fn assertIsIntegerVectorType(comptime T: type) void {
    comptime if (!isIntegerVectorType(T)) @compileError("Expected integer vector, but found: " ++ @typeName(T));
}

pub fn isFloatVectorType(comptime T: type) bool {
    const Ti: std.builtin.Type = @typeInfo(T);
    return Ti == .vector and isFloatType(Ti.vector.child);
}
pub fn isFloatVector(v: anytype) bool {
    const T: type = comptime @TypeOf(v);
    return isFloatVectorType(T);
}
pub fn assertIsFloatVectorType(comptime T: type) void {
    comptime if (!isFloatVectorType(T)) @compileError("Expected vector of floats, but found: " ++ @typeName(T));
}

pub fn isNumberOrNumberVectorType(comptime T: type) bool {
    return isNumberType(T) or isNumberVectorType(T);
}
pub fn isNumberOrNumberVector(v: anytype) bool {
    const T: type = @TypeOf(v);
    return isNumberOrNumberVectorType(T);
}
pub fn assertIsNumberOrNumberVectorType(comptime T: type) void {
    comptime if (!isNumberOrNumberVector(T)) @compileError("Expected number or vector of numbers, but found: " ++ @typeName(T));
}
