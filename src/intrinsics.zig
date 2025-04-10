const builtin = @import("builtin");
const std = @import("std");

pub const x86 = struct {
    pub const CPUID = struct {
        const CPUIDLog = std.log.scoped(.CPUID);
        // Leaf 0. https://en.wikipedia.org/wiki/CPUID#EAX=0:_Highest_Function_Parameter_and_Manufacturer_ID
        highestBasicLeaf: u32 = 0,
        manufacturerId: [12]u8 = undefined,

        // Leaf 1. https://en.wikipedia.org/wiki/CPUID#EAX=1:_Processor_Info_and_Feature_Bits
        steppingId: u4 = undefined,
        model: u4 = undefined,
        familyId: u4 = undefined,
        processorType: u2 = undefined, // TODO Should be an enum
        extendedModelId: u4 = undefined,
        extendedFamilyId: u8 = undefined,
        brandIndex: u8 = undefined,
        clflushLineSize: u8 = undefined,
        featureFlags: FeatureFlags = undefined,

        /// Features from Leaf 1 edx and ecx
        pub const FeatureFlags = packed struct {
            // edx
            fpu: u1 = undefined,
            vme: u1 = undefined,
            de: u1 = undefined,
            pse: u1 = undefined,
            tsc: u1 = undefined,
            msr: u1 = undefined,
            pae: u1 = undefined,
            mce: u1 = undefined,
            cx8: u1 = undefined,
            apic: u1 = undefined,
            mtrr_reserved: u1 = undefined, // NOT USED
            sep: u1 = undefined,
            mtrr: u1 = undefined,
            pge: u1 = undefined,
            mca: u1 = undefined,
            cmov: u1 = undefined,
            pat: u1 = undefined,
            pse_36: u1 = undefined,
            psn: u1 = undefined,
            clfsh: u1 = undefined,
            nx_reserved: u1 = undefined, // Only used on Itanium CPUs
            ds: u1 = undefined,
            acpi: u1 = undefined,
            mmx: u1 = undefined,
            fxsr: u1 = undefined,
            sse: u1 = undefined,
            sse2: u1 = undefined,
            // ecx
            sse3: u1 = undefined,
            pclmulqdq: u1 = undefined,
            dtes64: u1 = undefined,
            monitor: u1 = undefined,
            ds_cpl: u1 = undefined,
            vmx: u1 = undefined,
            smx: u1 = undefined,
            est: u1 = undefined,
            tm2: u1 = undefined,
            ssse3: u1 = undefined,
            cnxt_id: u1 = undefined,
            sdbg: u1 = undefined,
            fma: u1 = undefined,
            cx16: u1 = undefined,
            xtpr: u1 = undefined,
            pdcm: u1 = undefined,
            nop_reserved: u1 = undefined,
            pcid: u1 = undefined,
            dca: u1 = undefined,
            sse4_1: u1 = undefined,
            sse4_2: u1 = undefined,
            x2apic: u1 = undefined,
            movbe: u1 = undefined,
            tsc_deadline: u1 = undefined,
            aes_ni: u1 = undefined,
            xsave: u1 = undefined,
            osxsave: u1 = undefined,
            avx: u1 = undefined,
            rdrnd: u1 = undefined,
            hypervisor: u1 = undefined,
        };
        pub const RegisterResult = packed struct {
            eax: u32 = 0,
            ebx: u32 = 0,
            ecx: u32 = 0,
            edx: u32 = 0,
        };

        /// leaf is the value moved into eax before cpuid is called.
        /// ext is the value moved into ecx before cpuid is called
        pub noinline fn readLeafExt(leaf: u32, ext: u32) RegisterResult {
            var r: RegisterResult = .{};
            nosuspend {
                _ = asm volatile ( // NO FOLD
                        "cpuid"
                        :
                        : [a] "{eax}" (leaf),
                          [b] "{ebx}" (0),
                          [c] "{ecx}" (ext),
                          [d] "{edx}" (0),
                    );
                r.eax = asm volatile ("nop"
                    : [ret] "={eax}" (-> u32),
                );
                r.ebx = asm volatile ("nop"
                    : [ret] "={ebx}" (-> u32),
                );
                r.ecx = asm volatile ("nop"
                    : [ret] "={ecx}" (-> u32),
                );
                r.edx = asm volatile ("nop"
                    : [ret] "={edx}" (-> u32),
                );
            }
            return r;
        }
        /// leaf is the value moved into eax before cpuid is called
        pub noinline fn readLeaf(leaf: u32) RegisterResult {
            return readLeafExt(leaf, 0);
        }

        pub noinline fn parseLeaf(self: *CPUID, leaf: u32, registers: *RegisterResult) void {
            const defs = struct {
                fn parseLeaf0(s: *CPUID, r: *RegisterResult) void {
                    s.highestBasicLeaf = r.eax;
                    @memcpy(s.manufacturerId[0..4], @as([4]u8, @bitCast(r.ebx))[0..]);
                    @memcpy(s.manufacturerId[4..8], @as([4]u8, @bitCast(r.edx))[0..]);
                    @memcpy(s.manufacturerId[8..12], @as([4]u8, @bitCast(r.ecx))[0..]);
                }

                fn parseLeaf1(s: *CPUID, r: *RegisterResult) void {
                    var temp: u32 = r.eax;
                    // eax
                    s.steppingId = @truncate(temp);
                    temp = temp >> 4;
                    s.model = @truncate(temp);
                    temp = temp >> 4;
                    s.familyId = @truncate(temp);
                    temp = temp >> 4;
                    s.processorType = @truncate(temp);
                    temp = temp >> 4;
                    s.extendedModelId = @truncate(temp);
                    temp = temp >> 4;
                    s.extendedFamilyId = @truncate(temp);

                    // ebx
                    CPUIDLog.warn("parsing leaf 1 is not fully implemented yet", .{});
                }
            };

            switch (leaf) {
                0 => defs.parseLeaf0(self, registers),
                1 => defs.parseLeaf1(self, registers),
                else => CPUIDLog.warn("Leaf {d} not implemented", .{leaf}),
            }
        }
        /// Reads all possible information from CPUID
        pub fn readParseAll() CPUID {
            var result: CPUID = undefined;

            var leaf = readLeaf(0);
            result.parseLeaf(0, &leaf);

            var i: u32 = 1;
            while (i < result.highestBasicLeaf) : (i += 1) {
                leaf = readLeaf(i);
                result.parseLeaf(i, &leaf);
            }

            return result;
        }
        pub fn readAllBasicLeaves(allocator: std.mem.Allocator) ![]const RegisterResult {
            const r0 = CPUID.readLeaf(0);
            const leaf_count = r0.eax;

            const result = try allocator.alloc(RegisterResult, leaf_count);
            result[0] = r0;
            var i: u32 = 1;
            while (i < leaf_count) : (i += 1) {
                result[i] = readLeaf(i);
            }
            return result;
        }
    };
};
pub const x86_x64 = struct {
    pub usingnamespace x86;

    /// Returns current TSC
    pub fn rdtsc() u64 {
        return asm volatile ( // NO FOLD
            "rdtsc\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
            : [ret] "={rax}" (-> u64),
            :
            : "eax", "rdx", "edx"
        );
    }
    test "rdtsc" {
        for (0..1000) |i| {
            const tsc0 = rdtsc();
            std.time.sleep(i);
            const tsc1 = rdtsc();
            try std.testing.expect(tsc0 < tsc1);
        }
    }

    /// Returns current TSC. Syncronizes before and after by using mfence and lfence
    pub fn rdtsc_fenced() u64 {
        return asm volatile ( // NO FOLD
            "mfence\n" ++ "lfence\n" ++ "rdtsc\n" ++ "lfence\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
            : [ret] "={rax}" (-> u64),
            :
            : "rax", "eax", "rdx", "edx"
        );
    }
    test "rdtsc_fenced" {
        for (0..1000) |i| {
            const tsc0 = rdtsc_fenced();
            std.time.sleep(i);
            const tsc1 = rdtsc_fenced();
            try std.testing.expect(tsc0 < tsc1);
        }
    }

    pub const rdtscp_result = struct { tsc: u64, aux: u32 };
    pub fn rdtscp() rdtscp_result {
        var result: rdtscp_result = .{ .tsc = 0, .aux = comptime std.math.maxInt(u32) };
        nosuspend {
            result.tsc = asm volatile ("rdtscp\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
                : [ret] "={rax}" (-> u64),
                :
                : "eax", "rdx", "edx"
            );
            result.aux = asm volatile ("nop"
                : [ret] "={ecx}" (-> u32),
            );
        }
        return result;
    }
    test "rdtscp" {
        for (0..1000) |i| {
            const tscp0 = rdtscp();
            std.time.sleep(i);
            const tscp1 = rdtscp();
            try std.testing.expect(tscp0.tsc < tscp1.tsc);
        }
    }

    /// Returns current TSC. Syncronizes before and after by using lfence
    pub fn rdtscp_fenced() rdtscp_result {
        var result: rdtscp_result = .{ .tsc = 0, .aux = comptime std.math.maxInt(u32) };
        nosuspend {
            result.tsc = asm volatile ("mfence\n" ++ "lfence\n" ++ "rdtscp\n" ++ "lfence\n" ++ "shl $32, %rdx\n" ++ "or %rax, %rdx"
                : [ret] "={rax}" (-> u64),
                :
                : "eax", "rdx", "edx"
            );
            result.aux = asm volatile ("nop"
                : [ret] "={ecx}" (-> u32),
            );
        }
        return result;
    }
    test "rdtscp_fenced" {
        for (0..1000) |i| {
            const tscp0 = rdtscp_fenced();
            std.time.sleep(i);
            const tscp1 = rdtscp_fenced();
            try std.testing.expect(tscp0.tsc < tscp1.tsc);
        }
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
    pub noinline fn repmovsb(noalias dst: *anyopaque, noalias src: *const anyopaque, len: usize) void {
        // https://www.felixcloutier.com/x86/rep:repe:repz:repne:repnz
        asm volatile ( // NO FOLD
            "rep movsb"
            :
            : [src] "{rsi}" (src),
              [dst] "{rdi}" (dst),
              [len] "{rcx}" (len),
        );
    }
    test "repmovsb" {
        const prng: type = std.Random.DefaultPrng;
        const allocator = std.heap.page_allocator;
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
