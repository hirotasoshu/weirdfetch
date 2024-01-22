const std = @import("std");
const ChildProcess = std.ChildProcess;

pub fn getWm() ![]const u8 {
    // #TODO: ADD WAYLAND SUPPORT
    // #TODO: rewrite it in pure zig
    const result = try ChildProcess.exec(.{
        .allocator = std.heap.page_allocator,
        .argv = &[_][]const u8{
            "bash",
            "-c",
            \\id=$(xprop -root -notype _NET_SUPPORTING_WM_CHECK) && id=${id##* } && wm=$(xprop -id "$id" -notype -len 100 -f _NET_WM_NAME 8t) && wm=${wm/*WM_NAME = } && wm=${wm/\"} && wm=${wm/\"*} && printf $wm
        },
    });
    const wm = result.stdout;
    if (wm.len == 0) return "unknown";
    return wm;
}
