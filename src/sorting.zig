const std = @import("std");
const compare = @import("compare.zig");
const math = @import("math.zig");
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
    test "selectionSort" {
        try testSortFn(selectionSort);
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
    test "insertionSort" {
        try testSortFn(insertionSort);
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
    test "bubbleSort" {
        try testSortFn(bubbleSort);
    }

    pub fn noSort(comptime T: type, comptime comparison: compare.Comparison(T), a: []T) void {
        _ = &comparison;
        _ = &a;
    }
    inline fn testSortFn(comptime sortFn: @TypeOf(noSort)) !void {
        const len: comptime_int = 11; //101;
        const cmpFn: compare.Comparison(u8) = compare.compareNumberFn(u8);
        const nums: []u8 = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(nums);
        var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
        prng.fill(nums[0..]);

        const preSum = math.sum(u8, nums[0..]);
        sortFn(u8, cmpFn, nums[0..]);
        const postSum = math.sum(u8, nums[0..]);

        std.testing.expectEqual(preSum, postSum) catch |err| {
            std.log.err("Sorting algorithm changed the array data", .{});
            return err;
        };

        for (1..nums.len) |i| {
            const c = cmpFn(nums[i - 1], nums[i]);
            std.testing.expect(c != .greater) catch |err| {
                std.log.err("found non-sorted numbers: a[{d}]:{d} > a[{d}]:{d}\nin {any}", .{ i - 1, nums[i - 1], i, nums[i], nums });
                return err;
            };
        }
    }
};

/// Contains sorting algorithms that require an allocator to be passed in
pub const alloc = struct {
    fn MergeSortContext(comptime T: type, comptime comparison: compare.Comparison(T)) type {
        return struct {
            fn _topDownMergeSort(A: []T, B: []T) void {
                std.debug.assert(A.len == B.len);
                mem.copy(T, B, A);
                _topDownSplitMerge(A, 0, A.len, B);
            }
            fn _topDownSplitMerge(B: []T, iBegin: usize, iEnd: usize, A: []T) void {
                if (iEnd - iBegin <= 1) return;

                const iMiddle = (iEnd + iBegin) / 2;
                _topDownSplitMerge(A, iBegin, iMiddle, B);
                _topDownSplitMerge(A, iMiddle, iEnd, B);
                _topDownMerge(B, iBegin, iMiddle, iEnd, A);
            }
            fn _topDownMerge(B: []T, iBegin: usize, iMiddle: usize, iEnd: usize, A: []T) void {
                if (@inComptime()) @panic("Function should not be run in comptime");
                var i: usize = iBegin;
                var j: usize = iMiddle;

                var k: usize = iBegin;
                while (k < iEnd - 1) : (k += 1) {
                    const cmp = comparison(A[i], A[j]);
                    if (i < iMiddle and (j >= iEnd or cmp.lessOrEqualTo())) {
                        B[k] = A[i];
                        i += 1;
                    } else {
                        B[k] = A[j];
                        j += 1;
                    }
                }
            }
        };
    }
    pub fn mergeSort(comptime T: type, comptime comparison: compare.Comparison(T), allocator: std.mem.Allocator, a: []T) void {
        const b: []T = mem.allocPanic(allocator, T, a.len);
        defer allocator.free(b);

        MergeSortContext(T, comparison)._topDownMergeSort(a, b);
    }
    test "mergeSort" {
        try testSortFn(mergeSort);
    }

    pub fn noSort(comptime T: type, comptime comparison: compare.Comparison(T), allocator: std.mem.Allocator, a: []T) void {
        _ = &comparison;
        _ = &allocator;
        _ = &a;
    }
    inline fn testSortFn(comptime sortFn: @TypeOf(noSort)) !void {
        const len: comptime_int = 11; //101;
        const cmpFn: compare.Comparison(u8) = compare.compareNumberFn(u8);
        const nums: []u8 = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(nums);
        var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
        prng.fill(nums[0..]);

        const preClone: []const u8 = try mem.clone(u8, std.testing.allocator, nums);
        const preSum = math.sum(u8, nums[0..]);
        sortFn(u8, cmpFn, std.testing.allocator, nums[0..]);
        const postSum = math.sum(u8, nums[0..]);

        std.testing.expectEqual(preSum, postSum) catch |err| {
            std.log.err("Sorting algorithm changed the array data:\n pre sort:  {any}\n post sort: {any}", .{ preClone, nums });
            return err;
        };

        for (1..nums.len) |i| {
            const c = cmpFn(nums[i - 1], nums[i]);
            std.testing.expect(c != .greater) catch |err| {
                std.log.err("found non-sorted numbers: a[{d}]:{d} > a[{d}]:{d}\nin {any}", .{ i - 1, nums[i - 1], i, nums[i], nums });
                return err;
            };
        }
    }
};

test "inplace" {
    _ = inplace;
}
test "alloc" {
    _ = alloc;
}
