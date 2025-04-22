const builtin = @import("builtin");
const std = @import("std");
const types = @import("types.zig");

/// runs std.fmt.format, but panics instead of returning error
pub fn formatPanic(writer: anytype, comptime fmt: []const u8, args: anytype) void {
    std.fmt.format(writer, fmt, args) catch |err| {
        std.debug.panic("format failed due to error: {any}{any}", .{ err, @errorReturnTrace() });
    };
}
