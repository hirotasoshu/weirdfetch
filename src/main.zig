const std = @import("std");
const options = @import("options");
const ansi = @import("colors.zig").ansi;
const SystemInfo = @import("systeminfo.zig").SystemInfo;
const art = @import("art.zig");
const stdout = std.fs.File.stdout();

pub fn main() !void {
    // Struct are not yet supported as build options
    const sysinfo = SystemInfo{ .username = options.username, .hostname = options.hostname, .os = options.os_name, .kernel = options.kernel_version, .init = options.init, .shell = options.shell_bin, .wm = options.wm };

    const sysinfo_print: [6][]const u8 = comptime art.getSystemInfoPrint(sysinfo, ansi);
    for (sysinfo_print) |print_str| {
        try stdout.writeAll(print_str);
        try stdout.writeAll("\n");
    }
}
