const std = @import("std");
const expect = std.testing.expect;

const strings = @import("./strings.zig");

const help_strings = [_][]const u8{ "--help", "-h", "help" };

/// Determines if a given option name matches a request for help.
pub fn requested_help(option_name: []const u8) bool {
    for (help_strings) |h| {
        if (strings.starts_with(h, option_name)) {
            return true;
        }
    }

    return false;
}

test requested_help {
    for (help_strings) |str| {
        try expect(requested_help(str) == true);
    }

    try expect(requested_help("bad") == false);
}

/// If a container contains a help message, will print.
pub fn try_print_help(comptime T: type) void {
    if (@hasDecl(T, "help")) {
        std.io.getStdOut().writeAll(T.help) catch std.posix.exit(1);
        std.posix.exit(0);
    }
}
