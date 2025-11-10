const std = @import("std");
const compare = @import("compare.zig");
const math = @import("math.zig");
const mem = @import("mem.zig");


pub fn selectionSort(comptime T: type, comptime comparison: compare.Comparison(T), items: []T) void {
    for (0..items.len) |I| {
        const s: []T = items[I..];
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
pub fn selectionSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), items: []T) void {
    for (0..items.len) |I| {
        const s: []T = items[I..];
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
test selectionSort {
    try testSortFn(selectionSort);
}
test selectionSortR {
    try testSortFnR(selectionSortR);
}

pub fn insertionSort(comptime T: type, comptime comparison: compare.Comparison(T), items: []T) void {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        const x = items[i];
        var j: usize = i;
        while (j > 0 and (comparison(items[j - 1], x)) == .greater) : (j -= 1) {
            items[j] = items[j - 1];
        }
        items[j] = x;
    }
}
pub fn insertionSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), items: []T) void {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        const x = items[i];
        var j: usize = i;
        while (j > 0 and (comparison(&items[j - 1], &x)) == .greater) : (j -= 1) {
            items[j] = items[j - 1];
        }
        items[j] = x;
    }
}
test insertionSort {
    try testSortFn(insertionSort);
}
test insertionSortR {
    try testSortFnR(insertionSortR);
}

pub fn bubbleSort(comptime T: type, comptime comparison: compare.Comparison(T), items: []T) void {
    var n: usize = items.len;
    while (n > 1) {
        var next_n: usize = 0;
        for (1..n) |i| {
            if (comparison(items[i - 1], items[i]) == .greater) {
                mem.swap(T, &items[i - 1], &items[i]);
                next_n = i;
            }
        }
        n = next_n;
    }
}
pub fn bubbleSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), items: []T) void {
    var n: usize = items.len;
    while (n > 1) {
        var next_n: usize = 0;
        for (1..n) |i| {
            if (comparison(&items[i - 1], &items[i]) == .greater) {
                mem.swap(T, &items[i - 1], &items[i]);
                next_n = i;
            }
        }
        n = next_n;
    }
}
test bubbleSort {
    try testSortFn(bubbleSort);
}
test bubbleSortR {
    try testSortFnR(bubbleSortR);
}

fn noSort(comptime T: type, comptime comparison: compare.Comparison(T), items: []T) void {
    _ = &comparison;
    _ = &items;
}
fn noSortR(comptime T: type, comptime comparison: compare.ComparisonR(T), items: []T) void {
    _ = &comparison;
    _ = &items;
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

inline fn testSortFnR(comptime sortFn: @TypeOf(noSortR)) !void {
    const len: comptime_int = 11; //101;
    const cmpFnR: compare.ComparisonR(u8) = struct {
        fn f(a: *const u8, b: *const u8) compare.CompareResult {
            const cmpFn = comptime compare.compareNumberFn(u8);
            return cmpFn(a.*, b.*);
        }
    }.f;
    const nums: []u8 = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(nums);
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    prng.fill(nums[0..]);

    const preSum = math.sum(u8, nums[0..]);
    sortFn(u8, cmpFnR, nums[0..]);
    const postSum = math.sum(u8, nums[0..]);

    std.testing.expectEqual(preSum, postSum) catch |err| {
        std.log.err("Sorting algorithm changed the array data", .{});
        return err;
    };

    for (1..nums.len) |i| {
        const c = cmpFnR(&nums[i - 1], &nums[i]);
        std.testing.expect(c != .greater) catch |err| {
            std.log.err("found non-sorted numbers: a[{d}]:{d} > a[{d}]:{d}\nin {any}", .{ i - 1, nums[i - 1], i, nums[i], nums });
            return err;
        };
    }
}