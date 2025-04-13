const std = @import("std");
const compare = @import("compare.zig");
const mem = @import("mem.zig");

/// Contains sorting algorithms that do not require an allocator to be passed in
pub const inplace = struct {
    pub fn selectionSort(comptime T: type, comptime comparison: compare.Comparison(T), a: []T) void {
        for (0..a.len) |I| {
            const s: []T = a[I..];
            var iMin: usize = 0;
            for (1..s.len) |i| {
                const isLess = comparison(s[i], s[iMin]) == .less;
                const isLessInt: usize = @intFromBool(isLess);
                const notLessInt: usize = @intFromBool(!isLess);
                iMin = (i * isLessInt) + (iMin * notLessInt);
            }
            if (iMin > 0) mem.swap(T, &s[0], &s[iMin]);
        }
    }
    pub fn selectionSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), a: []T) void {
        for (0..a.len) |I| {
            const s: []T = a[I..];
            var iMin: usize = 0;
            for (1..s.len) |i| {
                const isLess = comparison(&s[i], &s[iMin]) == .less;
                const isLessInt: usize = @intFromBool(isLess);
                const notLessInt: usize = @intFromBool(!isLess);
                iMin = (i * isLessInt) + (iMin * notLessInt);
            }
            if (iMin > 0) {
                const tmp: T = s[0];
                s[0] = s[iMin];
                s[iMin] = tmp;
            }
        }
    }

    pub fn insertionSort(comptime T: type, comptime comparison: compare.Comparison(T), a: []T) void {
        var i: usize = 1;
        while (i < a.len) : (i += 1) {
            const x = a[i];
            var j: usize = i;
            while (j > 0 and (comparison(a[j - 1], x)) == .greater) : (j -= 1) {
                a[j] = a[j - 1];
            }
            a[j] = x;
        }
    }
    pub fn insertionSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), a: []T) void {
        var i: usize = 1;
        while (i < a.len) : (i += 1) {
            const x = a[i];
            var j: usize = i;
            while (j > 0 and (comparison(&a[j - 1], &x)) == .greater) : (j -= 1) {
                a[j] = a[j - 1];
            }
            a[j] = x;
        }
    }

    pub fn bubbleSort(comptime T: type, comptime comparison: compare.Comparison(T), a: []T) void {
        var n: usize = a.len;
        while (n > 1) {
            var next_n: usize = 0;
            for (1..n) |i| {
                if (comparison(a[i - 1], a[i]) == .greater) {
                    mem.swap(T, &a[i - 1], &a[i]);
                    next_n = i;
                }
            }
            n = next_n;
        }
    }
    pub fn bubbleSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), a: []T) void {
        var n: usize = a.len;
        while (n > 1) {
            var next_n: usize = 0;
            for (1..n) |i| {
                if (comparison(&a[i - 1], &a[i]) == .greater) {
                    mem.swap(T, &a[i - 1], &a[i]);
                    next_n = i;
                }
            }
            n = next_n;
        }
    }

    pub fn noSort(comptime T: type, comptime comparison: compare.Comparison(T), a: []T) void {
        _ = &comparison;
        _ = &a;
    }
    inline fn testSortFn(comptime sortFn: @TypeOf(noSort)) !void {
        const len: comptime_int = 11; //101;
        const cmpFn: compare.Comparison(u8) = compare.compareNumberFn(u8);
        var nums: [len]u8 = undefined;
        var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
        prng.fill(nums[0..]);

        // std.log.warn("pre-sort:\t{any}", .{nums});
        sortFn(u8, cmpFn, nums[0..]);
        // std.log.warn("post-sort:\t{any}", .{nums});

        for (1..nums.len) |i| {
            const c = cmpFn(nums[i - 1], nums[i]);
            std.testing.expect(c != .greater) catch |err| {
                std.log.err("found non-sorted numbers: a[{d}] ({d}) > a[{d}] ({d})", .{ i - 1, nums[i - 1], i, nums[i] });
                return err;
            };
        }
    }

    test "selection_sort" {
        try testSortFn(selectionSort);
    }
    test "insertion_sort" {
        try testSortFn(insertionSort);
    }
    test "bubble_sort" {
        try testSortFn(bubbleSort);
    }
};

/// Contains sorting algorithms that require an allocator to be passed in
pub const alloc = struct {
    
    
    pub fn noSort(comptime T: type, comptime comparison: compare.Comparison(T), allocator: std.mem.Allocator, a: []T) void {
        _ = &comparison;
        _ = &allocator;
        _ = &a;
    }
    inline fn testSortFn(comptime sortFn: @TypeOf(noSort)) !void {
        const len: comptime_int = 11; //101;
        const cmpFn: compare.Comparison(u8) = compare.compareNumberFn(u8);
        var nums: [len]u8 = undefined;
        var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
        prng.fill(nums[0..]);

        // std.log.warn("pre-sort:\t{any}", .{nums});
        sortFn(u8, cmpFn, std.testing.allocator, nums[0..]);
        // std.log.warn("post-sort:\t{any}", .{nums});

        for (1..nums.len) |i| {
            const c = cmpFn(nums[i - 1], nums[i]);
            std.testing.expect(c != .greater) catch |err| {
                std.log.err("found non-sorted numbers: a[{d}] ({d}) > a[{d}] ({d})", .{ i - 1, nums[i - 1], i, nums[i] });
                return err;
            };
        }
    }
};

test "inplace" {
    _ = inplace;
}
