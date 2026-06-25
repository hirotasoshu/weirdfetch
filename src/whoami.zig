const std = @import("std");
const mem = std.mem;

pub fn getUsername() []const u8 {
    return std.posix.getenv("USER") orelse "unknown_user";
}

pub fn getHostname(alloc: mem.Allocator) ![]const u8 {
    var username_buf: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&username_buf);
    return try alloc.dupe(u8, hostname);
}
