const std = @import("std");
const mem = std.mem;
const fs = std.fs;

pub fn getKernelVersion(alloc: *const mem.Allocator) ![]const u8 {
    const version = try fs.openFileAbsolute("/proc/version", .{ .mode = .read_only });
    defer version.close();

    var buf_reader = std.io.bufferedReader(version.reader());
    const reader = buf_reader.reader();
    var kernel_ver: []const u8 = "unknown";

    var buf: [1024]u8 = undefined;
    var info_line = try reader.readUntilDelimiterOrEof(&buf, '\n') orelse undefined;
    var info_iterator = mem.tokenize(u8, info_line, " ");
    while (info_iterator.next()) |word| {
        if (mem.eql(u8, word, "version")) {
            kernel_ver = info_iterator.next().?;
            break;
        }
    }

    return try alloc.dupe(u8, kernel_ver);
}
