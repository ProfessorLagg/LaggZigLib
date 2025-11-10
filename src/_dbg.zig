const builtin = @import("builtin");
const std = @import("std");
const lib = @import("LaggZigLib");
const intrinsics = lib.intrinsics;

pub const std_options: std.Options = .{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe => .debug,
        .ReleaseSmall => .debug,
        .ReleaseFast => .debug,
    },
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .CPUID, .level = .err },
    },
};

pub fn main() !void {
}
