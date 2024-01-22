const std = @import("std");
const mem = std.mem;

pub fn getUsername() []const u8 {
    return std.os.getenv("USER") orelse "unknown_user";
}

pub fn getHostname(alloc: *const mem.Allocator) ![]const u8 {
    var username_buf: [std.os.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.os.gethostname(&username_buf);
    return try alloc.dupe(u8, hostname);
}
