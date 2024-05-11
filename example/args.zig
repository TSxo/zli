const std = @import("std");
const assert = std.debug.assert;
const zli = @import("zli");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const LogLevel = enum {
        trace,
        debug,
        info,
        warn,
        err,
    };
    const App = struct {
        port: []const u8 = "3000",
        log_level: LogLevel = .info,
        db_uri: []const u8,

        pub const aliases = .{
            .port = "p",
            .log_level = "l",
            .db_uri = "d",
        };

        pub const help =
            \\ Usage:
            \\
            \\ app [options]
            \\
            \\ Options:
            \\
            \\ -h, --help                   Displays this help message then exits
            \\ -l, --log-level=<LogLevel>   The log level threshold. Default: info
            \\ -d, --db-uri                 The database URI. Required.
        ;
    };

    const result = zli.parse(&args, App);
    const writer = std.io.getStdOut().writer();

    try writer.print("Port: {s}\n", .{result.port});
    try writer.print("Log Level: {s}\n", .{@tagName(result.log_level)});
    try writer.print("DB URI: {s}\n", .{result.db_uri});
}
