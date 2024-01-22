pub const Colors = struct {
    reset: []const u8,
    red: []const u8,
    green: []const u8,
    yellow: []const u8,
    blue: []const u8,
    pink: []const u8,
    turquoise: []const u8,
};

pub const ansi = Colors{
    .reset = "\x1b[0m",
    .red = "\x1b[31m",
    .green = "\x1b[32m",
    .yellow = "\x1b[33m",
    .blue = "\x1b[34m",
    .pink = "\x1b[35m",
    .turquoise = "\x1b[36m",
};

// # TODO: ADD COMPILE OPTION TO USE THIS COLORS
pub const mono = Colors{
    .reset = "",
    .red = "",
    .green = "",
    .yellow = "",
    .blue = "",
    .pink = "",
    .turquoise = "",
};
