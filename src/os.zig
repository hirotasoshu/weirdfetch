const std = @import("std");
const builtin = @import("builtin");
const ascii = std.ascii;
const mem = std.mem;
const fs = std.fs;

test "OS release ID parser removes quotes" {
    try std.testing.expectEqualStrings("gentoo", parseOSReleaseID("NAME=Gentoo\nID='gentoo'\n").?);
    try std.testing.expectEqualStrings("arch", parseOSReleaseID("ID=\"arch\"\n").?);
}

pub fn getOSReleaseID(alloc: mem.Allocator) ![]const u8 {
    if (builtin.os.tag == .macos) return try alloc.dupe(u8, "macos");

    const osrelease = try fs.openFileAbsolute("/etc/os-release", .{ .mode = .read_only });
    defer osrelease.close();

    const contents = try osrelease.readToEndAlloc(alloc, 4096);
    if (parseOSReleaseID(contents)) |id| {
        return try alloc.dupe(u8, id);
    }
    return "generic linux distro";
}

fn parseOSReleaseID(contents: []const u8) ?[]const u8 {
    const id_key = "ID";
    var lines = mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        const splitidx = ascii.indexOfIgnoreCase(line, "=") orelse continue;
        const linekey = line[0..splitidx];
        const value = line[(splitidx + 1)..line.len];
        if (mem.eql(u8, linekey, id_key)) return trimOSReleaseQuotes(value);
    }
    return null;
}

fn trimOSReleaseQuotes(value: []const u8) []const u8 {
    if (value.len >= 2 and ((value[0] == '\'' and value[value.len - 1] == '\'') or (value[0] == '"' and value[value.len - 1] == '"'))) {
        return value[1 .. value.len - 1];
    }
    return value;
}
