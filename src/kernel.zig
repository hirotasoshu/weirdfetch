const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const fs = std.fs;

pub fn getKernelVersion(alloc: mem.Allocator) ![]const u8 {
    if (builtin.os.tag == .macos) {
        const uts = std.posix.uname();
        return try alloc.dupe(u8, mem.sliceTo(&uts.release, 0));
    }

    const version = try fs.openFileAbsolute("/proc/version", .{ .mode = .read_only });
    defer version.close();

    var kernel_ver: []const u8 = "unknown";

    const contents = try version.readToEndAlloc(alloc, 1024);
    const line_end = mem.indexOfScalar(u8, contents, '\n') orelse contents.len;
    const info_line = contents[0..line_end];
    var info_iterator = mem.tokenizeAny(u8, info_line, " ");
    while (info_iterator.next()) |word| {
        if (mem.eql(u8, word, "version")) {
            kernel_ver = info_iterator.next().?;
            break;
        }
    }

    return try alloc.dupe(u8, kernel_ver);
}
