const builtin = @import("builtin");
const std = @import("std");

const structSize: comptime_int = @sizeOf(usize) + @sizeOf([*]u8);
const structBitSize: comptime_int = @bitSizeOf(usize) + @bitSizeOf([*]u8);
const maxStackLen: comptime_int = structSize - @sizeOf(u8);
const maxStackBitLen: comptime_int = structBitSize - @bitSizeOf(u8);

const StackString = packed struct {
    const TUInt: type = std.meta.Int(.unsigned, maxStackBitLen);
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
        staticAllocator.free(self.toSlice());
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
};

test "Size and Alignment" {
    try std.testing.expectEqual(structSize, @sizeOf(StackString));
    try std.testing.expectEqual(structSize, @sizeOf(HeapString));
    try std.testing.expectEqual(@alignOf(StackString), @alignOf(HeapString));
    std.log.debug("{s} | size: {d}, align: {d}", .{ @typeName(StackString), @sizeOf(StackString), @alignOf(StackString) });
    std.log.debug("{s} | size: {d}, align: {d}", .{ @typeName(HeapString), @sizeOf(HeapString), @alignOf(HeapString) });
}

test "Length" {
    var str: String = .{ .heap = .{} };
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
    defer str_heap.deinit();
    try std.testing.expect(str_stack.isStackString());
    try std.testing.expectEqualStrings(slcS, str_stack.toSliceC());
    try std.testing.expectEqualStrings(slcS, str_stack.toSlice());
}
