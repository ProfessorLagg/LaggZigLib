const builtin = @import("builtin");
const std = @import("std");

pub const compare = @import("compare.zig");

pub const flaggedInts = @import("flaggedInt.zig");
pub const fmt = @import("fmt.zig");
pub const intrinsics = @import("intrinsics.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const simd = @import("simd.zig");
pub const sorting = @import("sorting.zig");
pub const time = @import("time.zig");
pub const types = @import("types.zig");
pub const sso = @import("sso.zig");

test {
    _ = compare;
    _ = flaggedInts;
    _ = fmt;
    _ = intrinsics;
    _ = math;
    _ = mem;
    _ = simd;
    _ = sorting;
    _ = time;
    _ = types;
    _ = sso;
}
