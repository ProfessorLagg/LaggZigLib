const std = @import("std");
const types = @import("types.zig");

pub fn Vec2D(comptime T: type) type {
    comptime types.assertIsFloatType(T);
    return packed union {
        const TSelf = @This();
        pub const TVec = @Vector(2, T);
        pub const TObj = packed struct { x: T, y: T };
        vec: TVec,
        obj: TObj,

        pub const Zero: TSelf = TSelf{ .vec = @splat(0.0) };
        pub const One: TSelf = TSelf{ .vec = @splat(1.0) };

        /// returns the sign of each float in the vector
        pub inline fn sign(v: TSelf) TSelf {
            @setFloatMode(.optimized);
            const v_gt0: @Vector(2, i32) = @intFromBool(v.vec > Zero.vec);
            const v_lt0: @Vector(2, i32) = @intFromBool(v.vec < Zero.vec);
            const vd: @Vector(2, i32) = v_gt0 - v_lt0;
            return .{ .vec = @floatFromInt(vd) };
        }
        /// Maps a vector from 1 number range to another
        pub inline fn map(x: TSelf, input_start: TSelf, input_end: TSelf, output_start: TSelf, output_end: TSelf) TSelf {
            @setFloatMode(.optimized);
            return TSelf{ .vec = @import("math.zig").map(TVec, x.vec, input_start.vec, input_end.vec, output_start.vec, output_end.vec) };
        }
        /// Clamps the vector to a certain range
        pub inline fn clamp(v: TSelf, min: TSelf, max: TSelf) TSelf {
            @setFloatMode(.optimized);
            return TSelf{ .vec = @max(min.vec, @min(max.vec, v.vec)) };
        }
        /// returns the magnitude (also known as length) of this 2D vector
        pub inline fn magnitude(v: TSelf) T {
            @setFloatMode(.optimized);
            const x2 = v.obj.x * v.obj.x;
            const y2 = v.obj.y * v.obj.y;
            return @sqrt(x2 + y2);
        }
        /// Scales the vector down to have a length of 1
        pub inline fn normalize(v: TSelf) TSelf {
            @setFloatMode(.optimized);
            const m: T = magnitude(v);
            const vm: TVec = @splat(m);
            const result: TVec = v.vec / vm;
            const isNormal: bool = std.math.isNormal(m);
            const pred: @Vector(2, bool) = @splat(isNormal);
            const rvec: TVec = @select(T, pred, result, (comptime TVec{ 0, 0 }));
            return TSelf{ .vec = rvec };
        }
        /// Linear Interpolates between v0 and v1. t should be in the range [0 - 1]
        pub inline fn lerp(x: TSelf, y: TSelf, t: TSelf) TSelf {
            @setFloatMode(.optimized);
            const d: TVec = y.vec - x.vec;
            return TSelf{ .vec = @mulAdd(TVec, d, t.vec, x.vec) };
        }
        /// Returns the square of the euclidian distance between 2 points
        pub inline fn distanceSquared(a: TSelf, b: TSelf) T {
            @setFloatMode(.optimized);
            const d: TVec = a.vec - b.vec;
            const d2: TVec = d * d;
            return @reduce(.Add, d2);
        }
        /// Returns the euclidian distance between 2 points
        pub inline fn distance(a: TSelf, b: TSelf) T {
            @setFloatMode(.optimized);
            return @sqrt(distanceSquared(a, b));
        }
        /// Returns a direction vector going from a to b with a length of 1
        pub inline fn direction(from: TSelf, to: TSelf) TSelf {
            @setFloatMode(.optimized);
            const v_diff: TSelf = @bitCast(to.vec - from.vec);
            return v_diff.normalize();
        }
        /// Returns the sum of xy
        pub inline fn sum(v: TSelf) T {
            @setFloatMode(.optimized);
            return v.obj.x + v.obj.y;
        }

        test "set" {
            // Arrange
            var v: TSelf = TSelf.Zero;
            const r0: T = 0.123;
            const r1: T = 1.123;

            // Act
            v.vec[0] = r0;
            v.obj.y = r1;

            // Assert
            try std.testing.expectEqual(r0, v.obj.x);
            try std.testing.expectEqual(r1, v.vec[1]);
        }
        test "sign" {
            @setFloatMode(.optimized);
            // Arrange
            const v0: TSelf = TSelf{ .vec = TVec{ 0, 0 } };
            const v1: TSelf = TSelf{ .vec = TVec{ 0, 123 } };
            const v2: TSelf = TSelf{ .vec = TVec{ 0, -123 } };
            const v3: TSelf = TSelf{ .vec = TVec{ 123, 0 } };
            const v4: TSelf = TSelf{ .vec = TVec{ 123, 123 } };
            const v5: TSelf = TSelf{ .vec = TVec{ 123, -123 } };
            const v6: TSelf = TSelf{ .vec = TVec{ -123, 0 } };
            const v7: TSelf = TSelf{ .vec = TVec{ -123, 123 } };
            const v8: TSelf = TSelf{ .vec = TVec{ -123, -123 } };

            // Act
            const sv0: TSelf = v0.sign();
            const sv1: TSelf = v1.sign();
            const sv2: TSelf = v2.sign();
            const sv3: TSelf = v3.sign();
            const sv4: TSelf = v4.sign();
            const sv5: TSelf = v5.sign();
            const sv6: TSelf = v6.sign();
            const sv7: TSelf = v7.sign();
            const sv8: TSelf = v8.sign();

            // Assert
            try std.testing.expectEqual((comptime TVec{ 0, 0 }), sv0.vec);
            try std.testing.expectEqual((comptime TVec{ 0, 1 }), sv1.vec);
            try std.testing.expectEqual((comptime TVec{ 0, -1 }), sv2.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 0 }), sv3.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 1 }), sv4.vec);
            try std.testing.expectEqual((comptime TVec{ 1, -1 }), sv5.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 0 }), sv6.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 1 }), sv7.vec);
            try std.testing.expectEqual((comptime TVec{ -1, -1 }), sv8.vec);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 0 }), sv0.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 1 }), sv1.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = -1 }), sv2.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 0 }), sv3.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 1 }), sv4.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = -1 }), sv5.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 0 }), sv6.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 1 }), sv7.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = -1 }), sv8.obj);
        }
        test "map" {
            @setFloatMode(.optimized);

            // Arrange
            const v0: TSelf = TSelf{ .vec = .{ 0, 0 } };
            const v1: TSelf = TSelf{ .vec = .{ 0, 123 } };
            const v2: TSelf = TSelf{ .vec = .{ 0, -123 } };
            const v3: TSelf = TSelf{ .vec = .{ 123, 0 } };
            const v4: TSelf = TSelf{ .vec = .{ 123, 123 } };
            const v5: TSelf = TSelf{ .vec = .{ 123, -123 } };
            const v6: TSelf = TSelf{ .vec = .{ -123, 0 } };
            const v7: TSelf = TSelf{ .vec = .{ -123, 123 } };
            const v8: TSelf = TSelf{ .vec = .{ -123, -123 } };

            const rn1: TSelf = TSelf{ .vec = .{ -1.0, -1.0 } };
            const rp1: TSelf = TSelf{ .vec = .{ 1.0, 1.0 } };
            const rn2: TSelf = TSelf{ .vec = .{ -123.0, -123.0 } };
            const rp2: TSelf = TSelf{ .vec = .{ 123.0, 123.0 } };

            // Act
            const m0: TSelf = v0.map(rn2, rp2, rn1, rp1);
            const m1: TSelf = v1.map(rn2, rp2, rn1, rp1);
            const m2: TSelf = v2.map(rn2, rp2, rn1, rp1);
            const m3: TSelf = v3.map(rn2, rp2, rn1, rp1);
            const m4: TSelf = v4.map(rn2, rp2, rn1, rp1);
            const m5: TSelf = v5.map(rn2, rp2, rn1, rp1);
            const m6: TSelf = v6.map(rn2, rp2, rn1, rp1);
            const m7: TSelf = v7.map(rn2, rp2, rn1, rp1);
            const m8: TSelf = v8.map(rn2, rp2, rn1, rp1);

            // Assert
            try std.testing.expectEqual((comptime TVec{ 0, 0 }), m0.vec);
            try std.testing.expectEqual((comptime TVec{ 0, 1 }), m1.vec);
            try std.testing.expectEqual((comptime TVec{ 0, -1 }), m2.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 0 }), m3.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 1 }), m4.vec);
            try std.testing.expectEqual((comptime TVec{ 1, -1 }), m5.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 0 }), m6.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 1 }), m7.vec);
            try std.testing.expectEqual((comptime TVec{ -1, -1 }), m8.vec);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 0 }), m0.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 1 }), m1.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = -1 }), m2.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 0 }), m3.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 1 }), m4.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = -1 }), m5.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 0 }), m6.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 1 }), m7.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = -1 }), m8.obj);
        }
        test "clamp" {
            @setFloatMode(.optimized);

            // Arrange
            const v0: TSelf = .{ .vec = .{ 0, 0 } };
            const v1: TSelf = .{ .vec = .{ 0, 123 } };
            const v2: TSelf = .{ .vec = .{ 0, -123 } };
            const v3: TSelf = .{ .vec = .{ 123, 0 } };
            const v4: TSelf = .{ .vec = .{ 123, 123 } };
            const v5: TSelf = .{ .vec = .{ 123, -123 } };
            const v6: TSelf = .{ .vec = .{ -123, 0 } };
            const v7: TSelf = .{ .vec = .{ -123, 123 } };
            const v8: TSelf = .{ .vec = .{ -123, -123 } };

            const rn1: TSelf = .{ .vec = .{ -1.0, -1.0 } };
            const rp1: TSelf = .{ .vec = .{ 1.0, 1.0 } };

            // Act
            const m0: TSelf = v0.clamp(rn1, rp1);
            const m1: TSelf = v1.clamp(rn1, rp1);
            const m2: TSelf = v2.clamp(rn1, rp1);
            const m3: TSelf = v3.clamp(rn1, rp1);
            const m4: TSelf = v4.clamp(rn1, rp1);
            const m5: TSelf = v5.clamp(rn1, rp1);
            const m6: TSelf = v6.clamp(rn1, rp1);
            const m7: TSelf = v7.clamp(rn1, rp1);
            const m8: TSelf = v8.clamp(rn1, rp1);

            // Assert
            try std.testing.expectEqual((comptime TVec{ 0, 0 }), m0.vec);
            try std.testing.expectEqual((comptime TVec{ 0, 1 }), m1.vec);
            try std.testing.expectEqual((comptime TVec{ 0, -1 }), m2.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 0 }), m3.vec);
            try std.testing.expectEqual((comptime TVec{ 1, 1 }), m4.vec);
            try std.testing.expectEqual((comptime TVec{ 1, -1 }), m5.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 0 }), m6.vec);
            try std.testing.expectEqual((comptime TVec{ -1, 1 }), m7.vec);
            try std.testing.expectEqual((comptime TVec{ -1, -1 }), m8.vec);

            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 0 }), m0.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = 1 }), m1.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 0, .y = -1 }), m2.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 0 }), m3.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = 1 }), m4.obj);
            try std.testing.expectEqual((comptime TObj{ .x = 1, .y = -1 }), m5.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 0 }), m6.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = 1 }), m7.obj);
            try std.testing.expectEqual((comptime TObj{ .x = -1, .y = -1 }), m8.obj);
        }
        test "magnitude" {
            @setFloatMode(.optimized);
            const v: TSelf = .{ .vec = .{ 3.0, 4.0 } };
            const m: T = v.magnitude();
            try std.testing.expectEqual(5.0, m);
        }
        test "normalize" {
            @setFloatMode(.optimized);
            // Arrange
            const v0: TSelf = .{ .vec = .{ 5, 5 } };
            const v1: TSelf = .{ .vec = .{ 5, -5 } };
            const v2: TSelf = .{ .vec = .{ -5, 5 } };
            const v3: TSelf = .{ .vec = .{ -5, -5 } };

            // Act
            const n0: TSelf = v0.normalize();
            const n1: TSelf = v1.normalize();
            const n2: TSelf = v2.normalize();
            const n3: TSelf = v3.normalize();

            // Assert
            // TODO Find a proper way to round this to a number of decimal places
            try std.testing.expectEqual(1.0, @round(n0.magnitude()));
            try std.testing.expectEqual(1.0, @round(n1.magnitude()));
            try std.testing.expectEqual(1.0, @round(n2.magnitude()));
            try std.testing.expectEqual(1.0, @round(n3.magnitude()));
        }
        test "lerp" {
            @setFloatMode(.optimized);
            // Arrange
            const len: comptime_int = 10;
            const v0: TSelf = .{ .vec = .{ 11.0, 19.0 } };
            const v1: TSelf = .{ .vec = .{ 89.0, 97.0 } };
            // Act
            var testVals: [len]TSelf = undefined;
            var trueVals: [len]TVec = undefined;
            for (0..len) |i| {
                const t_f: T = @as(T, @floatFromInt(i)) / @as(T, @floatFromInt(len));
                const t_v: TSelf = .{ .vec = .{ t_f, t_f } };
                testVals[i] = lerp(v0, v1, t_v);
                trueVals[i] = std.math.lerp(v0.vec, v1.vec, t_v.vec);
            }

            // Assert
            for (0..len) |i| {
                try std.testing.expectEqual(trueVals[i], testVals[i].vec);
            }
        }
        test "distanceSquared" {
            @setFloatMode(.optimized);
            // Arrange
            const v0: TSelf = .{ .vec = .{ 0, 0 } };
            const v1: TSelf = .{ .vec = .{ 3, 4 } };

            // Act
            const d: T = v0.distanceSquared(v1);

            // Assert
            try std.testing.expectEqual(25.0, d);
        }
        test "distance" {
            @setFloatMode(.optimized);

            // Arrange
            const v0: TSelf = .{ .vec = .{ 0, 0 } };
            const v1: TSelf = .{ .vec = .{ 3, 4 } };

            // Act
            const d: f32 = v0.distance(v1);

            // Assert
            try std.testing.expectEqual(5.0, d);
        }
        test "direction" {
            @setFloatMode(.optimized);

            // Arrange
            const v0: TSelf = .{ .vec = .{ 0.0, 0.0 } };
            const v1: TSelf = .{ .vec = .{ 3.0, 4.0 } };
            const v2: TSelf = .{ .vec = .{ -3.0, 4.0 } };
            const v3: TSelf = .{ .vec = .{ -3.0, -4.0 } };
            const v4: TSelf = .{ .vec = .{ 3.0, -4.0 } };

            // Act
            const a01: TSelf = v0.direction(v1);
            const a02: TSelf = v0.direction(v2);
            const a03: TSelf = v0.direction(v3);
            const a04: TSelf = v0.direction(v4);
            const s01: TSelf = a01.sign();
            const s02: TSelf = a02.sign();
            const s03: TSelf = a03.sign();
            const s04: TSelf = a04.sign();

            // Assert
            try std.testing.expectEqual(TVec{ 1, 1 }, s01.vec);
            try std.testing.expectEqual(TVec{ -1, 1 }, s02.vec);
            try std.testing.expectEqual(TVec{ -1, -1 }, s03.vec);
            try std.testing.expectEqual(TVec{ 1, -1 }, s04.vec);

            try std.testing.expectEqual(TObj{ .x = 1, .y = 1 }, s01.obj);
            try std.testing.expectEqual(TObj{ .x = -1, .y = 1 }, s02.obj);
            try std.testing.expectEqual(TObj{ .x = -1, .y = -1 }, s03.obj);
            try std.testing.expectEqual(TObj{ .x = 1, .y = -1 }, s04.obj);

            try std.testing.expectEqual(1.0, a01.magnitude());
            try std.testing.expectEqual(1.0, a02.magnitude());
            try std.testing.expectEqual(1.0, a03.magnitude());
            try std.testing.expectEqual(1.0, a04.magnitude());
        }
    };
}

test "Vec2D.f16" {
    _ = Vec2D(f16);
}
test "Vec2D.f32" {
    _ = Vec2D(f32);
}
test "Vec2D.f64" {
    _ = Vec2D(f64);
}
test "Vec2D.f80" {
    _ = Vec2D(f80);
}
test "Vec2D.f128" {
    _ = Vec2D(f128);
}
test "Vec2D.c_longdouble" {
    _ = Vec2D(c_longdouble);
}

pub fn Plane2D(comptime T: type) type {
    comptime types.assertIsFloatType(T);
    return packed union {
        const TSelf = @This();
        /// Position of the top left corner
        pos: Vec2D(T),
        /// Width of the plane
        width: T,
        /// Height of the plane
        height: T,

        /// Returns the top left corner of the plane
        pub inline fn cornerTL(plane: *const TSelf) Vec2D(T) {
            return @bitCast(plane.obj.pos);
        }
        /// Returns the top right corner of the plane
        pub inline fn cornerTR(plane: *const TSelf) Vec2D(T) {
            var r: Vec2D(T) = plane.obj.pos;
            r.obj.x += plane.obj.width;
            return r;
        }
        /// Returns the bottom left corner of the plane
        pub inline fn cornerBL(plane: *const TSelf) Vec2D(T) {
            var r: Vec2D(T) = plane.obj.pos;
            r.obj.x += plane.obj.width;
            return r;
        }
        /// Returns the bottom right corner of the plane
        pub inline fn cornerBR(plane: *const TSelf) Vec2D(T) {
            return Vec2D(T){ .vec = plane.obj.pos + Vec2D(T).TVec{ plane.width, plane.height } };
        }

        /// Returns wether the given point is inside or outside the plane
        pub fn contains(plane: *const TSelf, point: Vec2D(T)) bool {
            const p: Vec2D(T).TVec = point.vec;
            const tl: Vec2D(T).TVec = plane.cornerTL().vec;
            const br: Vec2D(T).TVec = plane.cornerBR().vec;

            const cmp_tl: @Vector(2, bool) = p >= tl;
            const cmp_br: @Vector(2, bool) = p <= br;
            const cmp: @Vector(2, bool) = cmp_tl and cmp_br;
            return @reduce(.And, cmp);
        }
    };
}
