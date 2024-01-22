const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn getInit(alloc: *const mem.Allocator) ![]const u8 {
    var init_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    // this was true for my case, I don't think it's ultimate solution for all distros
    var init: []const u8 = fs.readLinkAbsolute("/sbin/init", &init_buf) catch return "sysvinit";
    init = cleanInit(init);
    return try alloc.dupe(u8, init);
}

fn cleanInit(init: []const u8) []const u8 {
    var cleaned_init: []const u8 = init;
    var it = mem.split(u8, cleaned_init, fs.path.sep_str);
    while (it.next()) |slice| {
        cleaned_init = slice;
    }
    it = mem.split(u8, cleaned_init, "-");
    cleaned_init = it.next() orelse cleaned_init;
    return cleaned_init;
}
