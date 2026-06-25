const std = @import("std");
const builtin = @import("builtin");

const XDisplay = opaque {};
const XWindow = c_ulong;
const XAtom = c_ulong;
const XBool = c_int;
const XSuccess = 0;
const XFalse = 0;
const XAnyPropertyType = 0;
const ProcAllPids = 1;
const ProcNameLen = 256;

const XOpenDisplayFn = *const fn (?[*:0]const u8) callconv(.c) ?*XDisplay;
const XCloseDisplayFn = *const fn (*XDisplay) callconv(.c) c_int;
const XDefaultRootWindowFn = *const fn (*XDisplay) callconv(.c) XWindow;
const XInternAtomFn = *const fn (*XDisplay, [*:0]const u8, XBool) callconv(.c) XAtom;
const XGetWindowPropertyFn = *const fn (*XDisplay, XWindow, XAtom, c_long, c_long, XBool, XAtom, *XAtom, *c_int, *c_ulong, *c_ulong, *?[*]u8) callconv(.c) c_int;
const XFreeFn = *const fn (?*anyopaque) callconv(.c) c_int;

extern "c" fn proc_listpids(proc_type: u32, typeinfo: u32, buffer: ?*anyopaque, buffersize: c_int) c_int;
extern "c" fn proc_name(pid: c_int, buffer: ?*anyopaque, buffersize: u32) c_int;

const X11 = struct {
    lib: std.DynLib,
    open_display: XOpenDisplayFn,
    close_display: XCloseDisplayFn,
    default_root_window: XDefaultRootWindowFn,
    intern_atom: XInternAtomFn,
    get_window_property: XGetWindowPropertyFn,
    free: XFreeFn,

    fn close(self: *X11) void {
        self.lib.close();
    }
};

test "Wayland desktop value is normalized" {
    try std.testing.expectEqualStrings("sway", normalizeDesktopName("sway"));
    try std.testing.expectEqualStrings("GNOME", normalizeDesktopName("GNOME:GNOME-Classic"));
}

test "Wayland desktop is preferred when Wayland display is present" {
    try std.testing.expectEqualStrings("Hyprland", detectWaylandWm("wayland-1", "Hyprland", null).?);
    try std.testing.expectEqualStrings("river", detectWaylandWm("wayland-1", null, "river").?);
    try std.testing.expect(detectWaylandWm(null, "Hyprland", null) == null);
}

test "X11 name selection prefers EWMH name over legacy name" {
    try std.testing.expectEqualStrings("awesome", selectX11WmName("awesome", "fallback").?);
    try std.testing.expectEqualStrings("fallback", selectX11WmName(null, "fallback").?);
}

test "X11 name selection trims trailing null bytes" {
    try std.testing.expectEqualStrings("i3", selectX11WmName("i3\x00\x00", null).?);
    try std.testing.expect(selectX11WmName("\x00", null) == null);
}

test "macOS WM selection detects known tiling tools" {
    const processes = [_][]const u8{ "launchd", "Dock", "yabai" };
    try std.testing.expectEqualStrings("yabai", selectMacWm(&processes));
}

test "macOS WM selection uses priority when multiple tools are running" {
    const processes = [_][]const u8{ "Amethyst", "AeroSpace", "yabai" };
    try std.testing.expectEqualStrings("AeroSpace", selectMacWm(&processes));
}

test "macOS WM selection falls back to Aqua" {
    const processes = [_][]const u8{ "launchd", "Dock", "Finder" };
    try std.testing.expectEqualStrings("Aqua", selectMacWm(&processes));
}

pub fn getWm() ![]const u8 {
    if (detectWaylandWm(
        std.posix.getenv("WAYLAND_DISPLAY"),
        std.posix.getenv("XDG_CURRENT_DESKTOP"),
        std.posix.getenv("DESKTOP_SESSION"),
    )) |wayland_wm| return wayland_wm;

    if (builtin.os.tag == .macos) return try getMacWm(std.heap.page_allocator);

    return getX11Wm(std.heap.page_allocator) catch "unknown";
}

fn getMacWm(alloc: std.mem.Allocator) ![]const u8 {
    if (builtin.os.tag != .macos) return "unknown";

    var pids: [4096]c_int = undefined;
    const bytes = proc_listpids(ProcAllPids, 0, &pids, @sizeOf(@TypeOf(pids)));
    if (bytes <= 0) return "Aqua";

    const pid_count = @as(usize, @intCast(bytes)) / @sizeOf(c_int);
    var process_names = std.ArrayList([]const u8).empty;
    defer {
        for (process_names.items) |name| alloc.free(name);
        process_names.deinit(alloc);
    }

    for (pids[0..pid_count]) |pid| {
        if (pid <= 0) continue;
        var name_buf: [ProcNameLen]u8 = undefined;
        const name_len = proc_name(pid, &name_buf, name_buf.len);
        if (name_len <= 0) continue;
        try process_names.append(alloc, try alloc.dupe(u8, name_buf[0..@intCast(name_len)]));
    }

    return try alloc.dupe(u8, selectMacWm(process_names.items));
}

fn getX11Wm(alloc: std.mem.Allocator) ![]const u8 {
    if (builtin.os.tag != .linux) return "unknown";

    var x11 = loadX11() orelse return "unknown";
    defer x11.close();

    const display = x11.open_display(null) orelse return "unknown";
    defer _ = x11.close_display(display);

    const root = x11.default_root_window(display);
    const supporting_wm_check = x11.intern_atom(display, "_NET_SUPPORTING_WM_CHECK", XFalse);
    const wm_window = readWindowProperty(&x11, display, root, supporting_wm_check) orelse return "unknown";

    const utf8_string = x11.intern_atom(display, "UTF8_STRING", XFalse);
    const net_wm_name = x11.intern_atom(display, "_NET_WM_NAME", XFalse);
    const wm_name = x11.intern_atom(display, "WM_NAME", XFalse);

    const ewmh_name = try readTextProperty(alloc, &x11, display, wm_window, net_wm_name, utf8_string);
    defer if (ewmh_name) |name| alloc.free(name);
    const legacy_name = try readTextProperty(alloc, &x11, display, wm_window, wm_name, XAnyPropertyType);
    defer if (legacy_name) |name| alloc.free(name);

    return try alloc.dupe(u8, selectX11WmName(ewmh_name, legacy_name) orelse "unknown");
}

fn loadX11() ?X11 {
    var lib = std.DynLib.open("libX11.so.6") catch return null;
    errdefer lib.close();

    return X11{
        .lib = lib,
        .open_display = lib.lookup(XOpenDisplayFn, "XOpenDisplay") orelse return null,
        .close_display = lib.lookup(XCloseDisplayFn, "XCloseDisplay") orelse return null,
        .default_root_window = lib.lookup(XDefaultRootWindowFn, "XDefaultRootWindow") orelse return null,
        .intern_atom = lib.lookup(XInternAtomFn, "XInternAtom") orelse return null,
        .get_window_property = lib.lookup(XGetWindowPropertyFn, "XGetWindowProperty") orelse return null,
        .free = lib.lookup(XFreeFn, "XFree") orelse return null,
    };
}

fn readWindowProperty(x11: *const X11, display: *XDisplay, window: XWindow, property: XAtom) ?XWindow {
    var actual_type: XAtom = 0;
    var actual_format: c_int = 0;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = 0;
    var data: ?[*]u8 = null;
    defer {
        if (data) |ptr| _ = x11.free(ptr);
    }

    if (x11.get_window_property(display, window, property, 0, 1, XFalse, XAnyPropertyType, &actual_type, &actual_format, &nitems, &bytes_after, &data) != XSuccess) return null;
    if (actual_type == 0 or actual_format != 32 or nitems == 0) return null;
    const ptr = data orelse return null;
    return @as([*]const XWindow, @ptrCast(@alignCast(ptr)))[0];
}

fn readTextProperty(alloc: std.mem.Allocator, x11: *const X11, display: *XDisplay, window: XWindow, property: XAtom, requested_type: XAtom) !?[]const u8 {
    var actual_type: XAtom = 0;
    var actual_format: c_int = 0;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = 0;
    var data: ?[*]u8 = null;
    defer {
        if (data) |ptr| _ = x11.free(ptr);
    }

    if (x11.get_window_property(display, window, property, 0, 1024, XFalse, requested_type, &actual_type, &actual_format, &nitems, &bytes_after, &data) != XSuccess) return null;
    if (actual_type == 0 or actual_format != 8 or nitems == 0) return null;
    const ptr = data orelse return null;
    return try alloc.dupe(u8, ptr[0..@intCast(nitems)]);
}

fn detectWaylandWm(wayland_display: ?[]const u8, current_desktop: ?[]const u8, desktop_session: ?[]const u8) ?[]const u8 {
    if (wayland_display == null) return null;
    if (current_desktop) |desktop| {
        if (desktop.len > 0) return normalizeDesktopName(desktop);
    }
    if (desktop_session) |session| {
        if (session.len > 0) return normalizeDesktopName(session);
    }
    return null;
}

fn normalizeDesktopName(name: []const u8) []const u8 {
    const first = std.mem.indexOfScalar(u8, name, ':') orelse name.len;
    return name[0..first];
}

fn selectX11WmName(ewmh_name: ?[]const u8, legacy_name: ?[]const u8) ?[]const u8 {
    if (ewmh_name) |name| {
        const trimmed = trimTrailingNulls(name);
        if (trimmed.len > 0) return trimmed;
    }
    if (legacy_name) |name| {
        const trimmed = trimTrailingNulls(name);
        if (trimmed.len > 0) return trimmed;
    }
    return null;
}

fn trimTrailingNulls(name: []const u8) []const u8 {
    var end = name.len;
    while (end > 0 and name[end - 1] == 0) end -= 1;
    return name[0..end];
}

fn selectMacWm(processes: []const []const u8) []const u8 {
    const known_wms = [_][]const u8{ "AeroSpace", "yabai", "Amethyst", "Rectangle", "Phoenix", "chunkwm" };
    for (known_wms) |wm_name| {
        for (processes) |process| {
            if (std.mem.eql(u8, process, wm_name)) return wm_name;
        }
    }
    return "Aqua";
}
