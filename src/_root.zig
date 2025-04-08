const builtin = @import("builtin");
const std = @import("std");

pub const intrinsics = switch (builtin.cpu.arch) {
    .x86_64 => @import("intrinsics.zig").x86_x64,
    else => struct {},
};

pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const types = @import("types.zig");

test {
    _ = intrinsics;
    _ = math;
    _ = mem;
    _ = types;
}

test "Alignment vs Size" {
    const sT = struct {
        data1: bool = true,
    };

    try std.testing.expectEqual(1, @alignOf(sT));
    try std.testing.expectEqual(1, @sizeOf(sT));
}
