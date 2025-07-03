const builtin = @import("builtin");
const std = @import("std");

const structSize: comptime_int = @sizeOf(usize) + @sizeOf([*]u8);
const structBitSize: comptime_int = @bitSizeOf(usize) + @bitSizeOf([*]u8);
const maxStackLen: comptime_int = structSize - @sizeOf(u8);
const maxStackBitLen: comptime_int = structBitSize - @bitSizeOf(u8);

const StackString = packed struct {
    const TVec: type = @Vector(maxStackLen, u8);
    const TUInt: type = std.meta.Int(.unsigned, maxStackBitLen);
    len: u8 = 0,
    // val: TVec = @splat(0),
    val: TUInt = 0,

    pub fn toSliceC(self: *const StackString) []const u8 {
        //return @as([maxStackLen]u8, self.val)[0..self.len];
        return b: {
            var r: []const u8 = undefined;
            r.len = self.len;
            // r.ptr = @ptrFromInt(@intFromPtr(&self.val));
            r.ptr = @ptrFromInt(@intFromPtr(self) + 1);
            break :b r;
        };
    }

    pub fn toSlice(self: *StackString) []u8 {
        //return @constCast(@as([maxStackLen]u8, self.val)[0..self.len]);
        return b: {
            var r: []u8 = undefined;
            r.len = self.len;
            // r.ptr = @ptrFromInt(@intFromPtr(&self.val));
            r.ptr = @ptrFromInt(@intFromPtr(self) + 1);
            break :b r;
        };
    }

    pub fn initCopy(str: []const u8) StackString {
        std.debug.assert(str.len <= maxStackLen);
        var r: StackString = .{};
        r.len = @truncate(str.len);
        const slice = r.toSlice();
        @memset(slice, 0);
        @memcpy(slice, str);
        r.len = @truncate(str.len);
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
        if (str.len <= maxStackLen) {} else {
            return String{ .heap = HeapString.initCopy(str) };
        }
    }

    pub fn deinit(self: *String) void {
        if (self.isHeapString()) self.heap.deinit();
    }

    pub fn toSlice(self: *String) []const u8 {
        switch (self.isStackString()) {
            .true => self.stack.toSlice(),
            .false => self.heap.toSlice(),
        }
    }
};

test "Sizing" {
    try std.testing.expectEqual(structSize, @sizeOf(StackString));
    try std.testing.expectEqual(structSize, @sizeOf(HeapString));
}

test "Length" {
    var str: String = .{ .heap = .{} };

    str.heap.len = 2;
    try std.testing.expectEqual(2, str.stack.len);

    str.stack.len = 3;
    try std.testing.expectEqual(3, str.heap.len);
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
