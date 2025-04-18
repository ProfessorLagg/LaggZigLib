const builtin = @import("builtin");
const std = @import("std");
const compare = @import("compare.zig");
const CompareResult = compare.CompareResult;

const mem = @import("mem.zig");

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
            const default_initial_capacity: comptime_int = comptime calc_default_initial_capacity(Tkey, Tval);
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

        pub fn capacity(self: *TSelf) usize {
            return self.key_buffer.len;
        }

        /// Add the key/value pair to the set if the key is not already present.
        /// Returns true if the key/value pair was added
        pub fn add(self: *TSelf, key: Tkey, val: *const Tval) bool {
            const insertIdx: InsertionIndex = self.getInsertionIndex(key);
            switch (insertIdx.compareResult) {
                .equal => return false,
                .less => {
                    self.insert(key, val, insertIdx.index) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
                .greater => {
                    self.insert(key, val, insertIdx.index + 1) catch |err| {
                        log.err("Error when trying to insert key/value {any}/{any} at index {d}: {any}\n{any}", .{ key, val, insertIdx.index, err, @errorReturnTrace() });
                        return false;
                    };
                    return true;
                },
            }
        }

        const InsertionIndex = packed struct {
            compareResult: compare.CompareResult,
            index: Tidx,
        };

        /// Returns either the index at which the key was found.
        /// Or the index where the key should be inserted
        fn getInsertionIndex(self: *TSelf, key: Tkey) InsertionIndex {
            var L: Tidx = 0;
            var R: Tidx = self.keys.len - 1;
            var m: Tidx = undefined;
            var cmp: compare.CompareResult = undefined;

            binarySearch: while (L <= R) {
                m = @divFloor((L + R), 2);
                cmp = comparison(self.keys[m], key);
                switch (cmp) {
                    .less => L = m + 1,
                    .greater => R = m - 1,
                    .equal => break :binarySearch,
                }
            }

            return InsertionIndex{ .compareResult = cmp, .index = m };
        }

        fn resizeBuffers(self: *TSelf, newsize: usize) !void {
            std.debug.assert(newsize >= 2);
            try mem.resize(Tkey, self.allocator, &self.key_buffer, newsize);
            try mem.resize(Tkey, self.allocator, &self.val_buffer, newsize);

            std.debug.assert(self.key_buffer.len == self.val_buffer.len);
        }
        /// Inserts the key/value pair at the specified index
        fn insert(self: *TSelf, key: Tkey, val: Tval, index: usize) !void {
            _ = &self;
            _ = &key;
            _ = &val;
            _ = &index;
            std.debug.panic("Not yet implemented", .{});

            std.debug.assert(index <= self.keys.len);
            if (self.keys.len >= self.key_buffer.len) try self.resizeBuffers(self.key_buffer.len * 2);

            self.keys.len += 1;
            self.values.len += 1;
            if (index < self.keys.len - 1) {
                var i: usize = self.keys.len - 1;

                // TODO Use a performance optimized mem copy here
                while (i > index) : (i -= 1) {
                    self.keys[i] = self.keys[i - 1];
                    self.values[i] = self.values[i - 1];
                }
            }

            std.debug.assert(self.keys.len == self.values.len);
            self.keys[index] = key;
            self.values[index] = val;
        }
    };
}
