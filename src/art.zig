const fmt = @import("std").fmt;
const Colors = @import("colors.zig").Colors;
const SystemInfo = @import("systeminfo.zig").SystemInfo;

pub fn getSystemInfoPrint(comptime sysinfo: SystemInfo, comptime colors: Colors) [6][]const u8 {
    return [6][]const u8{
        fmt.comptimePrint("            {s}whoami{s}  {s}•••   {s}@{s}", .{ colors.pink, colors.reset, colors.red, sysinfo.username, sysinfo.hostname }),
        fmt.comptimePrint("{s} /| ､       {s}os{s}      {s}•••   {s}", .{ colors.green, colors.pink, colors.reset, colors.green, sysinfo.os }),
        fmt.comptimePrint("{s}(°､ ｡ 7     {s}kernel{s}  {s}•••   {s}", .{ colors.green, colors.pink, colors.reset, colors.yellow, sysinfo.kernel }),
        fmt.comptimePrint("{s} |､  ~ヽ    {s}init{s}    {s}•••   {s}", .{ colors.green, colors.pink, colors.reset, colors.blue, sysinfo.init }),
        fmt.comptimePrint("{s} じしf_,)   {s}shell{s}   {s}•••   {s}", .{ colors.green, colors.pink, colors.reset, colors.pink, sysinfo.shell }),
        fmt.comptimePrint("            {s}wm{s}      {s}•••   {s}", .{ colors.pink, colors.reset, colors.turquoise, sysinfo.wm }),
    };
}
