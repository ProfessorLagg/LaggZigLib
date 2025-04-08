const builtin = @import("builtin");
const std = @import("std");

pub const x86_x64 = struct {
    /// Returns current TSC
    pub fn rdtsc() u64 {
        return asm volatile ( // NO FOLD
            "rdtsc\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
            : [ret] "={rax}" (-> u64),
            :
            : "rax", "eax", "rdx", "edx"
        );
    }

    /// Returns current TSC. Syncronizes before and after by using lfence
    pub fn rdtsc_fenced() u64 {
        return asm volatile ( // NO FOLD
            "mfence\n" ++ "lfence\n" ++ "rdtsc\n" ++ "lfence\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
            : [ret] "={rax}" (-> u64),
            :
            : "rax", "eax", "rdx", "edx"
        );
    }

    pub fn rdtscp() void {
        @compileError("Not possible due to missing support for multiple outputs");
    }

    /// Read a hardware generated 16-bit random value. Returns null if failed
    pub fn rdrand16() ?u16 {
        nosuspend {
            const r: u16 = asm volatile ( // NO FOLD
                    "rdrand %ax\n" ++ "pushfq"
                    : [ret] "={ax}" (-> u16),
                );
            const success: u32 = asm volatile ( // NO FOLD
                    "pop %rdx\n" ++ "and $1, %rdx"
                    : [ret] "={rdx}" (-> u32),
                );
            return switch (success) {
                0 => null,
                1 => r,
                else => unreachable,
            };
        }
    }

    /// Read a hardware generated 32-bit random value. Returns null if failed
    pub fn rdrand32() ?u32 {
        nosuspend {
            const r: u32 = asm volatile ( // NO FOLD
                    "rdrand %eax\n" ++ "pushfq"
                    : [ret] "={eax}" (-> u32),
                );
            const success: u32 = asm volatile ( // NO FOLD
                    "pop %rdx\n" ++ "and $1, %rdx"
                    : [ret] "={rdx}" (-> u32),
                );
            return switch (success) {
                0 => null,
                1 => r,
                else => unreachable,
            };
        }
    }

    /// Read a hardware generated 64-bit random value. Returns null if failed
    pub fn rdrand64() ?u64 {
        nosuspend {
            const r: u64 = asm volatile ( // NO FOLD
                    "rdrand %rax\n" ++ "pushfq"
                    : [ret] "={eax}" (-> u64),
                );
            const success: u32 = asm volatile ( // NO FOLD
                    "pop %rdx\n" ++ "and $1, %rdx"
                    : [ret] "={rdx}" (-> u32),
                );
            return switch (success) {
                0 => null,
                1 => r,
                else => unreachable,
            };
        }
    }

    ///  Move len bytes from src to dst
    pub fn repmovsb(noalias dst: *anyopaque, noalias src: *const anyopaque, len: usize) void {
        // https://www.felixcloutier.com/x86/rep:repe:repz:repne:repnz

        return asm volatile ( // NO FOLD
            "rep movsb"
            :
            : [src] "{rsi}" (src),
              [dst] "{rdi}" (dst),
              [len] "{rcx}" (len),
        );
    }

    test "repmovsb" {
        const prng: type = std.Random.DefaultPrng;
        const allocator = std.testing.allocator;
        const page_size = std.heap.pageSize();

        const src_page: []u8 = try allocator.alloc(u8, page_size);
        defer allocator.free(src_page);

        const dst_page: []u8 = try allocator.alloc(u8, page_size);
        defer allocator.free(dst_page);

        var rand: prng = prng.init(std.testing.random_seed);
        rand.fill(src_page);

        repmovsb(dst_page.ptr, src_page.ptr, src_page.len);

        try std.testing.expectEqualSlices(u8, src_page, dst_page);
    }
};
