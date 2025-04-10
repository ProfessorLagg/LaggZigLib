const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    const out = std.io.getStdOut().writer();

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            try std.fmt.format(out, "\x1b[31mX {s}: {}[0m\n", .{ t.name, err });
            continue;
        };
        try std.fmt.format(out, "\x1b[32m✓ {s}[0m\n", .{t.name});
    }
}
