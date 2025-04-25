const builtin = @import("builtin");
const std = @import("std");

pub const windows = switch (builtin.os.tag) {
    .windows => _windows,
    else => struct {},
};

const _windows = struct {
    const W = std.unicode.utf8ToUtf16LeStringLiteral;
    const DWORD = std.os.windows.DWORD;
    const LPCWSTR = std.os.windows.LPCWSTR;

    pub const registry = struct {
        const HKEY = std.os.windows.HKEY;
        const KeyHandle = enum(usize) {
            HKEY_CLASSES_ROOT = @intFromPtr(std.os.windows.HKEY_CLASSES_ROOT),
            HKEY_CURRENT_USER = @intFromPtr(std.os.windows.HKEY_CURRENT_USER),
            HKEY_LOCAL_MACHINE = @intFromPtr(std.os.windows.HKEY_LOCAL_MACHINE),
            HKEY_USERS = @intFromPtr(std.os.windows.HKEY_USERS),
            HKEY_PERFORMANCE_DATA = @intFromPtr(std.os.windows.HKEY_PERFORMANCE_DATA),
            HKEY_PERFORMANCE_TEXT = @intFromPtr(std.os.windows.HKEY_PERFORMANCE_TEXT),
            HKEY_PERFORMANCE_NLSTEXT = @intFromPtr(std.os.windows.HKEY_PERFORMANCE_NLSTEXT),
            HKEY_CURRENT_CONFIG = @intFromPtr(std.os.windows.HKEY_CURRENT_CONFIG),
            HKEY_DYN_DATA = @intFromPtr(std.os.windows.HKEY_DYN_DATA),
            HKEY_CURRENT_USER_LOCAL_SETTINGS = @intFromPtr(std.os.windows.HKEY_CURRENT_USER_LOCAL_SETTINGS),

            pub fn asHKEY(self: KeyHandle) HKEY {
                return @ptrFromInt(self);
            }
        };
        /// Flag values for readValue
        const readValueFlag = enum(DWORD) {
            /// No type restriction
            RRF_RT_ANY = 0x0000ffff,
            /// Restrict type to 32-bit RRF_RT_REG_BINARY | RRF_RT_REG_DWORD
            RRF_RT_DWORD = 0x00000018,
            /// Restrict type to 64-bit RRF_RT_REG_BINARY | RRF_RT_REG_QWORD
            RRF_RT_QWORD = 0x00000048,
            /// Restrict type to REG_BINARY
            RRF_RT_REG_BINARY = 0x00000008,
            /// Restrict type to REG_DWORD
            RRF_RT_REG_DWORD = 0x00000010,
            /// Restrict type to REG_EXPAND_SZ
            RRF_RT_REG_EXPAND_SZ = 0x00000004,
            /// Restrict type to REG_MULTI_SZ
            RRF_RT_REG_MULTI_SZ = 0x00000020,
            /// Restrict type to REG_NONE
            RRF_RT_REG_NONE = 0x00000001,
            /// Restrict type to REG_QWORD.
            RRF_RT_REG_QWORD = 0x00000040,
            /// Restrict type to REG_SZ
            RRF_RT_REG_SZ = 0x00000002,
        };

        pub const RegistryPath = struct {
            hkey: HKEY,
            subKey: LPCWSTR = "",
            valueName: LPCWSTR = "",

            pub fn init(hkey: KeyHandle, subKey: []const u8, valueName: []const u8) RegistryPath {
                return RegistryPath{ .hkey = hkey.asHKEY(), .subKey = W(subKey), .valueName = W(valueName) };
            }
        };
        pub fn readValueDWORD(path: RegistryPath) !DWORD {
            _ = &path;
        }
    };
};
