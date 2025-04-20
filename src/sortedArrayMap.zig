const builtin = @import("builtin");
const std = @import("std");
const compare = @import("compare.zig");
const CompareResult = compare.CompareResult;

const math = @import("math.zig");
const mem = @import("mem.zig");
const debug = @import("debug.zig");
const types = @import("types.zig");

const log = std.log.scoped(.SortedArrayMap);

fn calc_default_initial_capacity(comptime Tkey: type) comptime_int {
    const size_cacheline: comptime_int = comptime std.atomic.cache_line;
    const size_key: comptime_int = comptime @sizeOf(Tkey);
    return @max(2, size_cacheline / size_key);
}

pub fn SortedArrayMapR(comptime Tkey: type, comptime Tval: type, comptime comparison: compare.ComparisonR(Tkey)) type {
    return struct {
        const TSelf = @This();
        allocator: std.mem.Allocator,
        /// The actual amount of items. Do NOT modify
        count: usize,
        /// Backing array for keys slice. Do NOT modify
        key_buffer: []Tkey,
        /// Backing array for values slice. Do NOT modify
        val_buffer: []Tval,
        keys: []Tkey,
        values: []Tval,

        // === PUBLIC ===
        pub fn init(allocator: std.mem.Allocator) !TSelf {
            const default_initial_capacity: comptime_int = comptime calc_default_initial_capacity(Tkey, Tval);
            const result: TSelf = try initWithCapacity(allocator, default_initial_capacity);
            return result;
        }
        pub fn initWithCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !TSelf {
            std.debug.assert(initial_capacity > 0);
            var r = SortedArrayMapR(Tkey, Tval, comparison){
                .allocator = allocator,
                .count = 0,
                .key_buffer = try allocator.alloc(Tkey, initial_capacity),
                .val_buffer = try allocator.alloc(Tval, initial_capacity),
                .values = undefined,
                .keys = undefined,
            };
            r.keys = r.key_buffer[0..];
            r.keys.len = 0;
            r.values = r.val_buffer[0..];
            r.values.len = 0;
            return r;
        }
        pub fn deinit(self: *TSelf) void {
            self.allocator.free(self.key_buffer);
            self.allocator.free(self.val_buffer);
        }

        /// Returns the number of values that can be contained before the backing arrays will be resized
        pub inline fn capacity(self: *TSelf) usize {
            std.debug.assert(self.key_buffer.len == self.val_buffer.len);
            return self.key_buffer.len;
        }
        /// Finds the index of the key. Returns -1 if not found
        pub fn indexOf(self: *TSelf, k: *const Tkey) isize {
            if (mem.binarySearchR(Tkey, comparison, self.keys, k)) |i| return @intCast(i);
            return -1;
        }

        /// Returns true if k is found in self.keys. Otherwise false
        pub inline fn contains(self: *TSelf, k: *const Tkey) bool {
            const idx: isize = self.indexOf(k);
            log.debug("indexOf({any}) = {d}", .{ k, idx });
            return idx >= 0 and idx < self.keys.len;
        }
        /// Adds an item to the set.
        /// Returns true if the key could be added, otherwise false.
        pub fn add(self: *TSelf, k: *const Tkey, v: *const Tval) bool {
            const idx: isize = self.indexOf(k);
            if (idx >= 0) {
                return false;
            } else {
                self.update(k, v);
                return true;
            }
        }
        /// Overwrites the value at k, regardless of it's already contained
        pub fn update(self: *TSelf, k: *const Tkey, v: *const Tval) void {
            const insertionIndex = self.getInsertIndex(k);
            if (insertionIndex < self.count) {
                self.keys[insertionIndex] = k.*;
                self.values[insertionIndex] = v.*;
            } else {
                self.insertAt(insertionIndex, k, v);
            }
        }
        /// If k is in the map, updates the value at k using updateFn.
        /// otherwise add the value from addFn to the map
        pub fn addOrUpdate(self: *TSelf, k: *const Tkey, v: *const Tval, comptime updateFn: fn (*Tval, *const Tval) void) void {
            const s: u32 = self.getInsertOrUpdateIndex(k);
            const e: bool = (s & 0b10000000000000000000000000000000) > 0;
            const i: u32 = s & 0b01111111111111111111111111111111;
            if (e) {
                updateFn(&self.values[i], v);
            } else {
                self.insertAt(i, k, v);
            }
        }

        /// Reduces capacity to exactly fit count
        pub fn shrinkToFit(self: *TSelf) !void {
            // TODO shrinkToFit
            _ = &self;
        }

        pub fn join(self: *TSelf, other: *const TSelf, comptime updateFn: fn (*Tval, *const Tval) void) void {
            for (0..other.count) |i| {
                self.addOrUpdate(&other.keys[i], &other.values[i], updateFn);
            }
        }

        // === PRIVATE ===
        /// Rezises capacity to newsize
        fn resize(self: *TSelf, new_capacity: usize) void {
            std.debug.assert(new_capacity > 1);

            if (!self.allocator.resize(self.key_buffer, new_capacity)) {
                self.key_buffer = self.allocator.realloc(self.key_buffer, new_capacity) catch {
                    @panic("could not resize");
                };
                self.keys = self.key_buffer[0..self.count];
            }

            if (!self.allocator.resize(self.val_buffer, new_capacity)) {
                self.val_buffer = self.allocator.realloc(self.val_buffer, new_capacity) catch {
                    @panic("could not resize");
                };
                self.values = self.val_buffer[0..self.count];
            }
        }
        fn incrementCount(self: *TSelf) void {
            std.debug.assert(self.count < self.key_buffer.len);
            std.debug.assert(self.count < self.val_buffer.len);
            self.count += 1;
            // self.keys = self.key_buffer[0..self.count];
            // self.values = self.val_buffer[0..self.count];
            self.keys.len = self.count;
            self.values.len = self.count;
            std.debug.assert(self.keys.len == self.count);
            std.debug.assert(self.values.len == self.count);
        }
        fn shiftRight(self: *TSelf, start_at: usize) void {
            std.debug.assert(start_at >= 0);
            std.debug.assert(start_at < self.count);
            std.debug.assert(self.count - start_at >= 1);
            var key_slice: []Tkey = self.keys[start_at..];
            var val_slice: []Tval = self.values[start_at..];
            var i: usize = key_slice.len;
            while (i > 1) {
                i -= 1;
                key_slice[i] = key_slice[i - 1];
                val_slice[i] = val_slice[i - 1];
            }
        }
        /// The ONLY function that's allowed to update values in the buffers!
        /// Caller asserts that the index is valid.
        /// Inserts an item and a key at the specified index.
        fn insertAt(self: *TSelf, index: usize, k: *const Tkey, v: *const Tval) void {
            if (self.count == self.key_buffer.len) {
                const new_capacity: usize = self.capacity() * 2;
                self.resize(new_capacity);
            }
            std.debug.assert(index <= self.count); // Does not get compiled in ReleaseFast and ReleaseSmall modes
            std.debug.assert(self.keys.len < self.key_buffer.len); // Does not get compiled in ReleaseFast and ReleaseSmall modes

            self.incrementCount();
            if (index == self.count - 1) {
                // No need to shift if inserting at the end
                self.keys[index] = k.*;
                self.values[index] = v.*;
                return;
            } else {
                self.shiftRight(index);
                self.keys[index] = k.*;
                self.values[index] = v.*;
            }
        }

        /// Returns the index this key would have if present in the map.
        fn getInsertIndex(self: *TSelf, k: *const Tkey) usize {
            switch (self.count) {
                0 => return 0,
                1 => return switch (comparison(k, &self.keys[0])) {
                    .LessThan => 0,
                    else => 1,
                },
                else => {
                    if (comparison(k, &self.keys[self.count - 1]) == .GreaterThan) {
                        return self.count;
                    }
                },
            }

            var low: isize = 1;
            var high: isize = @intCast(self.count - 2);
            var mid: isize = low + @divTrunc(high - low, 2);
            var midu: usize = @as(usize, @intCast(mid));
            while (low <= high and mid >= 0 and mid < self.keys.len) {
                const comp_left = comparison(k, &self.keys[midu - 1]);
                const comp_right = comparison(k, &self.keys[midu + 1]);
                if (comp_left == .LessThan and comp_right == .GreaterThan) {
                    return midu;
                }
                switch (comparison(&self.keys[midu], k)) {
                    .Equal => {
                        return midu;
                    },
                    .LessThan => {
                        low = mid + 1;
                    },
                    .GreaterThan => {
                        high = mid - 1;
                    },
                }
                mid = low + @divTrunc(high - low, 2);
                midu = @as(usize, @intCast(mid));
            }
            return midu;
        }

        inline fn makeInsertOrUpdateResult(equal: bool, index: u31) u32 {
            return index | (@as(u32, @intFromBool(equal)) << 31);
        }

        inline fn getInsertOrUpdateIndex(self: *TSelf, k: *const Tkey) u32 {
            // Testing for edge cases
            if (self.count == 0) {
                // this is the first key
                return 0;
            }

            var L: isize = 0;
            var R: isize = @bitCast(self.count);
            var i: isize = undefined;
            var u: u31 = undefined;
            var cmp: CompareResult = undefined;
            R -= 1;
            while (L <= R) {
                i = @divFloor(L + R, 2);
                u = @as(u31, @intCast(i));
                cmp = comparison(k, &self.keys[u]);
                log.info("L: {d}, R: {d}, i: {d}, cmp: {s}", .{ L, R, i, @tagName(cmp) });
                switch (cmp) {
                    .LessThan => R = i - 1,
                    .GreaterThan => L = i + 1,
                    .Equal => return makeInsertOrUpdateResult(true, u),
                }
            }

            return u + @intFromBool(cmp == .GreaterThan);
        }
    };
}

pub fn SortedArrayMap(comptime Tkey: type, comptime Tval: type, comptime comparison: compare.Comparison(Tkey)) type {
    return struct {
        const TSelf: type = @This();
        const Tidx: type = std.meta.Int(.unsigned, @bitSizeOf(usize) - @bitSizeOf(compare.CompareResult));

        allocator: std.mem.Allocator,
        /// Backing array for keys
        key_buffer: []Tkey,
        /// Backing array for values
        val_buffer: []Tval,
        /// Contained Keys
        keys: []Tkey,
        /// Contained Values
        values: []Tval,

        pub fn init(allocator: std.mem.Allocator) !TSelf {
            const default_initial_capacity: comptime_int = comptime calc_default_initial_capacity(Tkey);
            const result: TSelf = try initWithCapacity(allocator, default_initial_capacity);
            return result;
        }
        pub fn initWithCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !TSelf {
            const C: usize = @min(@max(2, initial_capacity), comptime (@as(usize, @intCast(std.math.maxInt(Tidx)))));
            const kbuf: []Tkey = try allocator.alloc(Tkey, C);
            const vbuf: []Tval = try allocator.alloc(Tval, C);
            return TSelf{
                .allocator = allocator,
                .key_buffer = kbuf,
                .val_buffer = vbuf,
                .keys = kbuf[0..0],
                .values = kbuf[0..0],
            };
        }
        pub fn deinit(self: *TSelf) void {
            self.allocator.free(self.key_buffer);
            self.allocator.free(self.val_buffer);
        }
        /// Returns the total capacity of the buffers
        pub fn capacity(self: *const TSelf) usize {
            debug.assert(self.key_buffer.len == self.val_buffer.len);
            const r: usize = self.key_buffer.len;
            debug.assert(math.isEven(usize, r));
            debug.assert(r >= 2);
            return r;
        }
        /// Returns the number of key/value pairs stored in the set
        pub fn count(self: *const TSelf) usize {
            debug.assert(self.keys.len == self.values.len);
            return self.keys.len;
        }
        /// Returns the total unused capacity of the buffers
        pub fn unusedCapacity(self: *const TSelf) usize {
            const C: usize = @call(.always_inline, capacity, .{self});
            const c: usize = @call(.always_inline, count, .{self});
            debug.assert(c <= C);
            return C - c;
        }

        pub fn indexOf(self: *const TSelf, key: Tkey) ?usize {
            return mem.binarySearch(Tkey, comparison, self.keys, key);
        }

        /// Find the value associated with a key
        pub fn get(self: *const TSelf, key: Tkey) ?Tval {
            const idx: usize = self.indexOf(key) orelse return null;
            return self.values[idx];
        }
        /// Find a pointer to the value associated with a key.
        /// Calling add, put or remove on the set invalidates the pointer
        pub fn getPtr(self: *const TSelf, key: Tkey) ?*Tval {
            const idx: usize = self.indexOf(key) orelse return null;
            return &self.values[idx];
        }
        /// Add the key/value pair to the set if the key is not already present.
        /// Returns true if the key/value pair was added
        pub fn add(self: *TSelf, key: Tkey, val: *const Tval) bool {
            const insertIdx: InsertionIndex = self.getInsertionIndex(key);
            switch (insertIdx.compareResult) {
                .equal => return false,
                .less => {
                    self.insertAt(key, val, insertIdx.index) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
                .greater => {
                    self.insertAt(key, val, insertIdx.index + 1) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
            }
        }
        /// Add or overwrites the key/value pair
        pub fn put(self: *TSelf, key: Tkey, val: *const Tval) void {
            const insertIdx: InsertionIndex = self.getInsertionIndex(key);
            switch (insertIdx.compareResult) {
                .equal => self.values[insertIdx.index] = val,
                .less => {
                    self.insertAt(key, val, insertIdx.index) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
                .greater => {
                    self.insertAt(key, val, insertIdx.index + 1) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
            }
        }

        /// Removes the key/value pair from the set, and returns the value
        pub fn remove(self: *TSelf, key: Tkey) ?Tval {
            const idx: usize = self.indexOf(key) orelse return null;
            const result: Tval = self.values[idx];
            self.removeAt(idx) catch |err| {
                log.err("Error when trying to remove key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, result, idx, err, @errorReturnTrace() });
                return false;
            };
            return result;
        }

        const InsertionIndex = packed struct {
            compareResult: compare.CompareResult,
            index: Tidx,
        };
        /// Returns either the index at which the key was found.
        /// Or the index where the key should be inserted
        fn getInsertionIndex(self: *TSelf, key: Tkey) InsertionIndex {
            var L: isize = 0;
            var R: isize = @as(isize, @intCast(self.keys.len)) - 1;
            var m: isize = 0;
            var r: Tidx = @intCast(std.math.clamp(m, 0, comptime (std.math.maxInt(Tidx))));
            var cmp: compare.CompareResult = .less;

            binarySearch: while (L <= R) {
                m = @divFloor((L + R), 2);
                r = @intCast(m);
                cmp = comparison(key, self.keys[r]);
                // std.debug.print("R: {d}, L: {d}, m: {d}, cmp: {s}\n", .{ R, L, m, @tagName(cmp) });
                switch (cmp) {
                    .less => R = m - 1,
                    .greater => L = m + 1,
                    .equal => break :binarySearch,
                }
            }

            return InsertionIndex{
                .compareResult = cmp,
                .index = r,
            };
        }

        fn resizeBuffers(self: *TSelf, newsize: usize) !void {
            debug.assert(newsize >= 2);
            try mem.resize(Tkey, self.allocator, &self.key_buffer, newsize);
            try mem.resize(Tkey, self.allocator, &self.val_buffer, newsize);

            debug.assert(self.key_buffer.len == self.val_buffer.len);
        }
        /// Grows the buffers by a factor of 2.
        /// This is the only function allowed to increase the size of the buffers
        fn growBuffers(self: *TSelf) !void {
            try self.resizeBuffers(self.capacity() * 2);
        }
        /// Shrinks the buffers by a factor of 2.
        /// This is the only function allowed to increase the size of the buffers
        fn shrinkBuffers(self: *TSelf) !void {
            const isUnevenInt: usize = @intFromBool(math.isUneven(self.capacity()));
            const newsize: usize = (self.capacity() / 2) + isUnevenInt;
            if (newsize >= 2 and newsize < self.capacity()) try self.resizeBuffers(newsize);
        }
        /// Inserts the key/value pair at the specified index.
        fn insertAt(self: *TSelf, key: Tkey, val: *const Tval, index: usize) !void {
            debug.assert(index <= self.keys.len);
            if (self.unusedCapacity() == 0) try self.growBuffers();

            self.keys.len += 1;
            self.values.len += 1;
            if (index < self.keys.len - 1) {
                var i: usize = self.keys.len - 1;
                while (i > index) : (i -= 1) {
                    self.keys[i] = self.keys[i - 1];
                    self.values[i] = self.values[i - 1];
                }
            }

            debug.assert(self.keys.len == self.values.len);
            self.keys[index] = key;
            self.values[index] = val.*;
        }
        /// Removes the key/value pair at the specified index
        fn removeAt(self: *TSelf, index: usize) !void {
            debug.assert(index < self.keys.len);

            switch (index) {
                self.keys.len - 1 => {},
                else => {
                    mem.copy(Tkey, self.keys[index..], self.keys[index + 1 ..]);
                    mem.copy(Tval, self.values[index..], self.values[index + 1 ..]);
                },
            }

            self.keys.len -= 1;
            self.values.len -= 1;

            if (self.unusedCapacity() < self.count()) self.shrinkBuffers();
        }
    };
}

fn testFn_SortedArrayInt(comptime T: type) !void {
    // Arrange
    const len: comptime_int = 11;
    comptime types.assertIsIntegerType(T);
    const comparison: compare.Comparison(T) = compare.compareNumberFn(T);
    const TMap: type = SortedArrayMap(T, T, comparison);
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    var rand = prng.random();

    var arr: [len]T = undefined;
    for (0..arr.len) |i| {
        var v: T = rand.int(T);
        while (std.mem.indexOfScalar(T, arr[0..i], v) != null) : (v = rand.int(T)) {}
        arr[i] = v;
    }
    var arr_sorted: [len]T = undefined;
    mem.copy(T, arr_sorted[0..], arr[0..]);
    @import("sorting.zig").insertionSort(T, comparison, arr_sorted[0..]);

    var map: TMap = try TMap.init(std.testing.allocator);

    // Act & Assert
    for (arr) |v| {
        try std.testing.expect(map.add(v, &v));
    }
    try std.testing.expectEqual(arr_sorted.len, map.keys.len);
    try std.testing.expectEqual(arr_sorted.len, map.values.len);
    for (0..arr_sorted.len) |i| {
        try std.testing.expectEqual(arr_sorted[i], map.keys[i]);
        try std.testing.expectEqual(arr_sorted[i], map.values[i]);
    }
}

test "SortedArray.int" {
    try testFn_SortedArrayInt(u4);
    try testFn_SortedArrayInt(u5);
    try testFn_SortedArrayInt(u6);
    try testFn_SortedArrayInt(u7);
    try testFn_SortedArrayInt(u8);
    try testFn_SortedArrayInt(u9);
    try testFn_SortedArrayInt(u10);
    try testFn_SortedArrayInt(u11);
    try testFn_SortedArrayInt(u12);
    try testFn_SortedArrayInt(u13);
    try testFn_SortedArrayInt(u14);
    try testFn_SortedArrayInt(u15);
    try testFn_SortedArrayInt(u16);
    try testFn_SortedArrayInt(u17);
    try testFn_SortedArrayInt(u18);
    try testFn_SortedArrayInt(u19);
    try testFn_SortedArrayInt(u20);
    try testFn_SortedArrayInt(u21);
    try testFn_SortedArrayInt(u22);
    try testFn_SortedArrayInt(u23);
    try testFn_SortedArrayInt(u24);
    try testFn_SortedArrayInt(u25);
    try testFn_SortedArrayInt(u26);
    try testFn_SortedArrayInt(u27);
    try testFn_SortedArrayInt(u28);
    try testFn_SortedArrayInt(u29);
    try testFn_SortedArrayInt(u30);
    try testFn_SortedArrayInt(u31);
    try testFn_SortedArrayInt(u32);
    try testFn_SortedArrayInt(u33);
    try testFn_SortedArrayInt(u34);
    try testFn_SortedArrayInt(u35);
    try testFn_SortedArrayInt(u36);
    try testFn_SortedArrayInt(u37);
    try testFn_SortedArrayInt(u38);
    try testFn_SortedArrayInt(u39);
    try testFn_SortedArrayInt(u40);
    try testFn_SortedArrayInt(u41);
    try testFn_SortedArrayInt(u42);
    try testFn_SortedArrayInt(u43);
    try testFn_SortedArrayInt(u44);
    try testFn_SortedArrayInt(u45);
    try testFn_SortedArrayInt(u46);
    try testFn_SortedArrayInt(u47);
    try testFn_SortedArrayInt(u48);
    try testFn_SortedArrayInt(u49);
    try testFn_SortedArrayInt(u50);
    try testFn_SortedArrayInt(u51);
    try testFn_SortedArrayInt(u52);
    try testFn_SortedArrayInt(u53);
    try testFn_SortedArrayInt(u54);
    try testFn_SortedArrayInt(u55);
    try testFn_SortedArrayInt(u56);
    try testFn_SortedArrayInt(u57);
    try testFn_SortedArrayInt(u58);
    try testFn_SortedArrayInt(u59);
    try testFn_SortedArrayInt(u60);
    try testFn_SortedArrayInt(u61);
    try testFn_SortedArrayInt(u62);
    try testFn_SortedArrayInt(u63);
    try testFn_SortedArrayInt(u64);
    try testFn_SortedArrayInt(u65);
    try testFn_SortedArrayInt(u66);
    try testFn_SortedArrayInt(u67);
    try testFn_SortedArrayInt(i4);
    try testFn_SortedArrayInt(i5);
    try testFn_SortedArrayInt(i6);
    try testFn_SortedArrayInt(i7);
    try testFn_SortedArrayInt(i8);
    try testFn_SortedArrayInt(i9);
    try testFn_SortedArrayInt(i10);
    try testFn_SortedArrayInt(i11);
    try testFn_SortedArrayInt(i12);
    try testFn_SortedArrayInt(i13);
    try testFn_SortedArrayInt(i14);
    try testFn_SortedArrayInt(i15);
    try testFn_SortedArrayInt(i16);
    try testFn_SortedArrayInt(i17);
    try testFn_SortedArrayInt(i18);
    try testFn_SortedArrayInt(i19);
    try testFn_SortedArrayInt(i20);
    try testFn_SortedArrayInt(i21);
    try testFn_SortedArrayInt(i22);
    try testFn_SortedArrayInt(i23);
    try testFn_SortedArrayInt(i24);
    try testFn_SortedArrayInt(i25);
    try testFn_SortedArrayInt(i26);
    try testFn_SortedArrayInt(i27);
    try testFn_SortedArrayInt(i28);
    try testFn_SortedArrayInt(i29);
    try testFn_SortedArrayInt(i30);
    try testFn_SortedArrayInt(i31);
    try testFn_SortedArrayInt(i32);
    try testFn_SortedArrayInt(i33);
    try testFn_SortedArrayInt(i34);
    try testFn_SortedArrayInt(i35);
    try testFn_SortedArrayInt(i36);
    try testFn_SortedArrayInt(i37);
    try testFn_SortedArrayInt(i38);
    try testFn_SortedArrayInt(i39);
    try testFn_SortedArrayInt(i40);
    try testFn_SortedArrayInt(i41);
    try testFn_SortedArrayInt(i42);
    try testFn_SortedArrayInt(i43);
    try testFn_SortedArrayInt(i44);
    try testFn_SortedArrayInt(i45);
    try testFn_SortedArrayInt(i46);
    try testFn_SortedArrayInt(i47);
    try testFn_SortedArrayInt(i48);
    try testFn_SortedArrayInt(i49);
    try testFn_SortedArrayInt(i50);
    try testFn_SortedArrayInt(i51);
    try testFn_SortedArrayInt(i52);
    try testFn_SortedArrayInt(i53);
    try testFn_SortedArrayInt(i54);
    try testFn_SortedArrayInt(i55);
    try testFn_SortedArrayInt(i56);
    try testFn_SortedArrayInt(i57);
    try testFn_SortedArrayInt(i58);
    try testFn_SortedArrayInt(i59);
    try testFn_SortedArrayInt(i60);
    try testFn_SortedArrayInt(i61);
    try testFn_SortedArrayInt(i62);
    try testFn_SortedArrayInt(i63);
    try testFn_SortedArrayInt(i64);
    try testFn_SortedArrayInt(i65);
    try testFn_SortedArrayInt(i66);
    try testFn_SortedArrayInt(i67);
}
