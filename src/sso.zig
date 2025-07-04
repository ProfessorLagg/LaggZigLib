const builtin = @import("builtin");
const std = @import("std");
const Int = std.meta.Int;

const structSize: comptime_int = @sizeOf(usize) + @sizeOf([*]u8);
const structBitSize: comptime_int = @bitSizeOf(usize) + @bitSizeOf([*]u8);
const maxStackLen: comptime_int = structSize - @sizeOf(u8);
const maxStackBitLen: comptime_int = structBitSize - @bitSizeOf(u8);

const StackString = packed struct {
    const TUInt: type = Int(.unsigned, maxStackBitLen);
    len: u8 = 0,
    val: TUInt = 0,

    inline fn toSliceC(self: *const StackString) []const u8 {
        return b: {
            var r: []const u8 = undefined;
            r.len = self.len;
            r.ptr = @ptrFromInt(@intFromPtr(self) + 1);
            break :b r;
        };
    }

    inline fn toSlice(self: *StackString) []u8 {
        return b: {
            var r: []u8 = undefined;
            r.len = self.len;
            r.ptr = @ptrFromInt(@intFromPtr(self) + 1);
            break :b r;
        };
    }

    fn initCopy(str: []const u8) StackString {
        std.debug.assert(str.len <= maxStackLen);
        var r: StackString = .{};
        r.len = @truncate(str.len);
        const slice = r.toSlice();
        @memcpy(slice, str);
        return r;
    }
};

const HeapString = packed struct {
    const staticAllocator: std.mem.Allocator = b: {
        if (builtin.is_test) break :b std.testing.allocator;
        if (!builtin.single_threaded) break :b std.heap.smp_allocator;
        if (builtin.link_libc) break :b std.heap.c_allocator;
        @compileError("Requires either single-threading to be disabled or lib-c to be linked");
    };
    len: usize = 0,
    ptr: [*]u8 = undefined,

    inline fn toSliceC(self: *const HeapString) []const u8 {
        return self.ptr[0..self.len];
    }

    inline fn toSlice(self: *HeapString) []u8 {
        return self.ptr[0..self.len];
    }

    fn init(size: usize) !HeapString {
        std.debug.assert(size > maxStackLen);
        const s: []u8 = try staticAllocator.alloc(u8, size);
        return HeapString{
            .len = s.len,
            .ptr = s.ptr,
        };
    }

    fn initCopy(str: []const u8) !HeapString {
        const s: []u8 = try staticAllocator.alloc(u8, str.len);
        @memcpy(s[0..], str);

        return HeapString{
            .len = s.len,
            .ptr = s.ptr,
        };
    }

    fn deinit(self: *HeapString) void {
        staticAllocator.free(self.toSliceC());
        self.len = 0;
        self.ptr = undefined;
    }
};

pub const String = packed union {
    stack: StackString,
    heap: HeapString,

    pub inline fn isHeapString(self: *const String) bool {
        return self.stack.len > maxStackLen;
    }

    pub inline fn isStackString(self: *const String) bool {
        return self.stack.len <= maxStackLen;
    }

    pub fn initCopy(str: []const u8) String {
        if (str.len <= maxStackLen) {
            return String{ .stack = StackString.initCopy(str) };
        } else {
            return String{ .heap = HeapString.initCopy(str) catch |e| std.debug.panic("{any}{any}", .{ e, @errorReturnTrace() }) };
        }
    }

    pub fn deinit(self: *String) void {
        if (self.isHeapString()) self.heap.deinit();
    }

    pub fn toSlice(self: *String) []u8 {
        if (self.isStackString()) return self.stack.toSlice();
        return self.heap.toSlice();
    }

    pub fn toSliceC(self: *const String) []const u8 {
        if (self.isStackString()) return self.stack.toSliceC();
        return self.heap.toSliceC();
    }

    pub inline fn len(self: *const String) usize {
        const isStack: bool = self.isStackString();
        const s_mul: u8 = @intFromBool(isStack);
        const s_len: u8 = s_mul * self.stack.len;
        const h_mul: usize = @intFromBool(!isStack);
        const h_len: usize = h_mul * self.heap.len;
        return s_len + h_len;
    }

    /// Checks equality of struct data.
    /// For StackString this is equivalent to `a.len == b.len and a.val == b.val`
    /// For HeapString this is equivalent to `a.len == b.len and @intFromPtr(a.ptr) == @intFromPtr(b.ptr)`
    fn eql_struct(a: *const String, b: *const String) bool {
        return a.heap.len == b.heap.len and @intFromPtr(a.heap.ptr) == @intFromPtr(b.heap.ptr);
    }
    /// Checks equality between 2 heap strings
    fn eql_heap(a: *const String, b: *const String) bool {
        std.debug.assert(a.isHeapString());
        std.debug.assert(b.isHeapString());
        // TODO i know thers a faster way to do this, since i already know that the slices are longer than maxStackLen
        return std.mem.eql(u8, a.heap.toSliceC(), b.heap.toSliceC());
    }
    pub fn eql(a: *const String, b: *const String) bool {
        if (@intFromPtr(a) == @intFromPtr(b)) return true;
        const a_isStack: bool = a.isStackString();
        const b_isStack: bool = b.isStackString();
        // since a HeapString is always longer than a StackString, StackStrings and HeapStrings can never be equal
        if (a_isStack != b_isStack) return false;

        const eql_stc: bool = eql_struct(a, b);
        // if HeapStrings has the same struct data, they also have the same content
        // StackString content is the same as StackString struct data.
        if (eql_stc or a_isStack) return eql_stc;

        // To reach here means i have 2 HeapStrings with different struct data
        return eql_heap(a, b);
    }

    fn compare_uint(T: type, a: T, b: T) i8 {
        comptime {
            const ti: std.builtin.Type = @typeInfo(T);
            if (ti != .int) unreachable;
            if (ti.int.signedness != .unsigned) unreachable;
        }

        const lt: i8 = @intFromBool(a < b) * @as(i8, -1); // -1 if true, 0 if false
        const gt: i8 = @intFromBool(a > b); // 1 if true, 0 if false
        return lt + gt;
    }

    /// compare 2 strings for sorting purposes.
    /// returns <0 for a < b, 0 for a == b and >0 for a > b
    pub fn compare(a: *const String, b: *const String) i8 {
        if (@intFromPtr(a) == @intFromPtr(b)) return true;
        const a_len: usize = a.len();
        const b_len: usize = b.len();
        const a_slice = a.toSliceC();
        const b_slice = b.toSliceC();
        var cmp: i8 = compare_uint(usize, a_len, b_len);
        var i: usize = 0;
        while (cmp == 0 and i < a_len) : (i += 1) cmp = compare_uint(u8, a_slice[i], b_slice[i]);
        return cmp;
    }

    test initCopy {
        var arrStr: [maxStackLen * 2]u8 = undefined;
        const slcL: []u8 = arrStr[0..];
        const slcS: []u8 = arrStr[0 .. maxStackLen - 1];
        @memset(slcL, 'A');

        var str_heap = String.initCopy(slcL);
        defer str_heap.deinit();
        try std.testing.expect(str_heap.isHeapString());
        try std.testing.expectEqualStrings(slcL, str_heap.toSliceC());
        try std.testing.expectEqualStrings(slcL, str_heap.toSlice());

        var str_stack = String.initCopy(slcS);
        defer str_stack.deinit();
        try std.testing.expect(str_stack.isStackString());
        try std.testing.expectEqualStrings(slcS, str_stack.toSliceC());
        try std.testing.expectEqualStrings(slcS, str_stack.toSlice());
    }

    test eql {
        var arr_A: [maxStackLen * 2]u8 = undefined;
        const slcL_A: []u8 = arr_A[0..];
        const slcS_A: []u8 = arr_A[0 .. maxStackLen - 1];
        @memset(slcL_A, 'A');

        var arr_B: [maxStackLen * 2]u8 = undefined;
        const slcL_B: []u8 = arr_B[0..];
        const slcS_B: []u8 = arr_B[0 .. maxStackLen - 1];
        @memset(slcL_B, 'B');

        var str_h_1 = String.initCopy(slcL_A);
        var str_s_1 = String.initCopy(slcS_A);
        var str_h_2 = String.initCopy(slcL_B);
        var str_s_2 = String.initCopy(slcS_B);
        var str_h_3 = String.initCopy(slcL_A);
        var str_s_3 = String.initCopy(slcS_A);
        defer str_h_1.deinit();
        defer str_s_1.deinit();
        defer str_h_2.deinit();
        defer str_s_2.deinit();
        defer str_h_3.deinit();
        defer str_s_3.deinit();

        try std.testing.expect(str_h_1.isHeapString());
        try std.testing.expect(str_s_1.isStackString());
        try std.testing.expect(str_h_2.isHeapString());
        try std.testing.expect(str_s_2.isStackString());
        try std.testing.expect(str_h_3.isHeapString());
        try std.testing.expect(str_s_3.isStackString());

        try std.testing.expectEqual(true, str_h_1.eql(&str_h_1));
        try std.testing.expectEqual(false, str_h_1.eql(&str_s_1));
        try std.testing.expectEqual(false, str_h_1.eql(&str_h_2));
        try std.testing.expectEqual(false, str_h_1.eql(&str_s_2));
        try std.testing.expectEqual(true, str_h_1.eql(&str_h_3));
        try std.testing.expectEqual(false, str_h_1.eql(&str_s_3));
        try std.testing.expectEqual(false, str_s_1.eql(&str_h_1));
        try std.testing.expectEqual(true, str_s_1.eql(&str_s_1));
        try std.testing.expectEqual(false, str_s_1.eql(&str_h_2));
        try std.testing.expectEqual(false, str_s_1.eql(&str_s_2));
        try std.testing.expectEqual(false, str_s_1.eql(&str_h_3));
        try std.testing.expectEqual(true, str_s_1.eql(&str_s_3));
        try std.testing.expectEqual(false, str_h_2.eql(&str_h_1));
        try std.testing.expectEqual(false, str_h_2.eql(&str_s_1));
        try std.testing.expectEqual(true, str_h_2.eql(&str_h_2));
        try std.testing.expectEqual(false, str_h_2.eql(&str_s_2));
        try std.testing.expectEqual(false, str_h_2.eql(&str_h_3));
        try std.testing.expectEqual(false, str_h_2.eql(&str_s_3));
        try std.testing.expectEqual(false, str_s_2.eql(&str_h_1));
        try std.testing.expectEqual(false, str_s_2.eql(&str_s_1));
        try std.testing.expectEqual(false, str_s_2.eql(&str_h_2));
        try std.testing.expectEqual(true, str_s_2.eql(&str_s_2));
        try std.testing.expectEqual(false, str_s_2.eql(&str_h_3));
        try std.testing.expectEqual(false, str_s_2.eql(&str_s_3));
        try std.testing.expectEqual(true, str_h_3.eql(&str_h_1));
        try std.testing.expectEqual(false, str_h_3.eql(&str_s_1));
        try std.testing.expectEqual(false, str_h_3.eql(&str_h_2));
        try std.testing.expectEqual(false, str_h_3.eql(&str_s_2));
        try std.testing.expectEqual(true, str_h_3.eql(&str_h_3));
        try std.testing.expectEqual(false, str_h_3.eql(&str_s_3));
        try std.testing.expectEqual(false, str_s_3.eql(&str_h_1));
        try std.testing.expectEqual(true, str_s_3.eql(&str_s_1));
        try std.testing.expectEqual(false, str_s_3.eql(&str_h_2));
        try std.testing.expectEqual(false, str_s_3.eql(&str_s_2));
        try std.testing.expectEqual(false, str_s_3.eql(&str_h_3));
        try std.testing.expectEqual(true, str_s_3.eql(&str_s_3));
    }
};

test "Size and Alignment" {
    try std.testing.expectEqual(structSize, @sizeOf(StackString));
    try std.testing.expectEqual(structSize, @sizeOf(HeapString));
    try std.testing.expectEqual(@alignOf(StackString), @alignOf(HeapString));
    std.log.debug("{s} | size: {d}, align: {d}", .{ @typeName(StackString), @sizeOf(StackString), @alignOf(StackString) });
    std.log.debug("{s} | size: {d}, align: {d}", .{ @typeName(HeapString), @sizeOf(HeapString), @alignOf(HeapString) });
    std.log.debug("{s} | size: {d}, align: {d}", .{ @typeName(String), @sizeOf(String), @alignOf(String) });
}

test "Length" {
    var str: String = .{ .stack = .{} };
    for (0..256) |i| {
        str.stack.len = 0;
        str.heap.len = i;
        try std.testing.expectEqual(i, str.stack.len);

        str.heap.len = 0;
        str.stack.len = @truncate(i);
        try std.testing.expectEqual(i, str.heap.len);
    }

    for (256..512) |i| {
        str.stack.len = 0;
        str.heap.len = i;
        try std.testing.expect(str.heap.len != @as(@TypeOf(str.heap.len), @intCast(str.stack.len)));
    }
}

test StackString {
    const arrStr = "test";
    const slcStr: []const u8 = arrStr[0..];

    var str: StackString = StackString.initCopy(slcStr);
    try std.testing.expectEqualStrings(slcStr, str.toSliceC());
    try std.testing.expectEqualStrings(slcStr, str.toSlice());
}

test HeapString {
    const arrStr = "TestTestTest";
    const slcStr: []const u8 = arrStr[0..];

    var str: HeapString = try HeapString.initCopy(slcStr);
    defer str.deinit();
    try std.testing.expectEqualStrings(slcStr, str.toSliceC());
    try std.testing.expectEqualStrings(slcStr, str.toSlice());
}

test String {
    _ = String;
}
