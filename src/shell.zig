const std = @import("std");
const mem = std.mem;

pub fn getShell() []const u8 {
    const shell_env = std.posix.getenv("SHELL");
    var shell_bin: []const u8 = "unknown";
    if (shell_env) |shell_path| {
        var shell_path_iterator = mem.tokenizeAny(u8, shell_path, std.fs.path.sep_str);
        while (shell_path_iterator.next()) |shell_path_part| {
            shell_bin = shell_path_part;
        }
    }
    return shell_bin;
}
