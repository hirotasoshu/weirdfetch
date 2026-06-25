const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const mem = std.mem;

pub fn getInit(alloc: mem.Allocator) ![]const u8 {
    if (builtin.os.tag == .macos) return try alloc.dupe(u8, "launchd");

    var init_buf: [std.fs.max_path_bytes]u8 = undefined;
    // this was true for my case, I don't think it's ultimate solution for all distros
    var init: []const u8 = fs.readLinkAbsolute("/sbin/init", &init_buf) catch return "sysvinit";
    init = cleanInit(init);
    return try alloc.dupe(u8, init);
}

fn cleanInit(init: []const u8) []const u8 {
    var cleaned_init: []const u8 = init;
    var it = mem.splitSequence(u8, cleaned_init, fs.path.sep_str);
    while (it.next()) |slice| {
        cleaned_init = slice;
    }
    it = mem.splitSequence(u8, cleaned_init, "-");
    cleaned_init = it.next() orelse cleaned_init;
    return cleaned_init;
}
