const builtin = @import("builtin");
const std = @import("std");

fn debugEnabled() bool {
    return switch (builtin.mode) {
        .Debug => true,
        else => false,
    };
}

pub const assert: @TypeOf(assertFn) = switch (debugEnabled()) {
    true => assertFn,
    false => assertNoOp,
};
inline fn assertFn(check: bool) void {
    if (!check) unreachable;
}
inline fn assertNoOp(check: bool) void {
    _ = &check;
}

pub const assertLog: @TypeOf(assertLogFn) = switch (debugEnabled()) {
    true => assertLogFn,
    false => assertLogNoOp,
};
inline fn assertLogFn(check: bool, comptime format: []const u8, args: anytype) void {
    if (!check) {
        std.log.err(format, args);
        unreachable;
    }
}
inline fn assertLogNoOp(check: bool, comptime format: []const u8, args: anytype) void {
    _ = &check;
    _ = &format;
    _ = &args;
}
