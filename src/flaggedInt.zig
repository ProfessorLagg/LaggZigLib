const builtin = @import("builtin");
const std = @import("std");

/// Flagged uint
pub fn fuint(comptime uN: type) type {
    comptime {
        switch (uN) {
            u8, u16, u32, u64, usize => {},
            else => @compileError(@typeName(uN) ++ " is not a valid backing integer"),
        }
    }

    return packed struct {
        const TSelf = @This();
        const maxVal: uN = std.math.maxInt(uN) >> 1;
        const flgMask: uN = 1;
        const valMask: uN = std.math.maxInt(uN) - 1;

        data: uN = 0,

        /// reads the flag value
        pub inline fn getFlag(self: TSelf) bool {
            const flg_u = self.data & flgMask;
            return flg_u == 1;
        }
        /// Sets the flag to true
        pub inline fn setFlag(self: TSelf) TSelf {
            const new_data: uN = self.data | flgMask;
            return TSelf{ .data = new_data };
        }
        /// Sets the flag to false
        pub inline fn unsetFlag(self: TSelf) TSelf {
            const new_data: uN = self.data & valMask;
            return TSelf{ .data = new_data };
        }

        /// Reads the value
        pub inline fn getValue(self: TSelf) uN {
            return self.data >> 1;
        }
        /// Sets the value
        pub inline fn setValue(self: TSelf, v: uN) TSelf {
            std.debug.assert(v <= maxVal);
            const new_data = (self.data & flgMask) | v << 1;
            return TSelf{ .data = new_data };
        }

        pub inline fn make(value: uN, flag: bool) TSelf {
            std.debug.assert(value <= maxVal);
            return TSelf{ .data = (value << 1) | @as(uN, @intFromBool(flag)) };
        }

        test {
            const v: uN = 123;
            const v0 = TSelf.make(v, false);

            const v_set = v0.setFlag();
            const v_unset = v_set.unsetFlag();

            try std.testing.expectEqual(true, v_set.getFlag());
            try std.testing.expectEqual(false, v_unset.getFlag());
            try std.testing.expectEqual(v, v0.getValue());
            try std.testing.expectEqual(v, v_set.getValue());
            try std.testing.expectEqual(v, v_unset.getValue());
        }
    };
}

test {
    _ = fuint(u8);
    _ = fuint(u16);
    _ = fuint(u32);
    _ = fuint(u64);
    _ = fuint(usize);
}
