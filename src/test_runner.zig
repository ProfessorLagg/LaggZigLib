const std = @import("std");
const builtin = @import("builtin");

const ansi_esc = "\x1b[";
const ansi_text_reset = ansi_esc ++ "0m";
const ansi_text_fail = ansi_esc ++ "1;31m";
const ansi_text_pass = ansi_esc ++ "1;32m";
pub fn main() !void {
    const out = std.io.getStdOut().writer();

    for (builtin.test_functions) |t| {
        t.func() catch |err| {
            const trace = @errorReturnTrace();
            if (trace != null) {
                try std.fmt.format(out, "{}{s}FAIL{s}\t{s}\n", .{ trace.?, ansi_text_fail, ansi_text_reset, t.name });
            } else {
                try std.fmt.format(out, "{}\n{s}FAIL{s}\t{s}\n", .{ err, ansi_text_fail, ansi_text_reset, t.name });
            }

            continue;
        };
        try std.fmt.format(out, "{s}PASS{s}\t{s}\n", .{ ansi_text_pass, ansi_text_reset, t.name });
    }
}

fn setCursorLineStart(writer: anytype) !void {
    _ = try writer.write("\x1b[0F\r");
}
fn clearCurrentLine(writer: anytype) !void {
    try setCursorLineStart(writer);
    _ = try writer.write("\x1b[0K");
}

fn writePass(writer: anytype, t: std.builtin.TestFn) !void {
    try clearCurrentLine(writer);
    try std.fmt.format(writer, "\x1b[32mV {s}\x1b[0m\n", .{t.name});
}
fn writeFail(writer: anytype, t: std.builtin.TestFn, err: anyerror) !void {
    try clearCurrentLine(writer);
    try std.fmt.format(writer, "\x1b[31mX {s}:\x1b[0m {}\n", .{ t.name, err });
}
fn setCursorNextLine(writer: anytype) !void {
    _ = try writer.write("\n\n");
}
