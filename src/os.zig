const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const fs = std.fs;

pub fn getOSReleaseID(alloc: *const mem.Allocator) ![]const u8 {
    const osrelease = try fs.openFileAbsolute("/etc/os-release", .{ .mode = .read_only });
    const id_key = "ID";
    defer osrelease.close();
    var buf_reader = std.io.bufferedReader(osrelease.reader());
    const reader = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var splitidx = ascii.indexOfIgnoreCase(line, "=").?;
        const linekey = line[0..splitidx];
        const value = line[(splitidx + 1)..line.len];
        if (mem.eql(u8, linekey, id_key)) {
            return try alloc.dupe(u8, value);
        }
    }
    return "generic linux distro";
}
