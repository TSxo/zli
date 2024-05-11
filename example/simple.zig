const std = @import("std");
const assert = std.debug.assert;
const zli = @import("zli");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const App = union(enum) {
        empty,
        example: struct {
            foo: u8 = 0,
            foo_bar: u32 = 100,
            foo_bar_baz: []const u8 = "foo",
            opt: bool = false,

            pub const aliases = .{
                .foo = "f",
                .foo_bar = "b",
                .foo_bar_baz = "z",
                .opt = "o",
            };

            pub const help =
                \\ Command: example
                \\
                \\ Usage:
                \\
                \\ app example [options]
                \\
                \\ Options:
                \\
                \\ -h, --help               Displays this help message then exits
                \\ -f, --foo=<n>            Help for foo. Default: 0
                \\ -b, --foo-bar=<n>        Help for foo-bar. Default: 100
                \\ -z, --foo-bar-baz=<n>    Help for foo-bar-baz. Default: foo
                \\ -o, --opt                Help for opt. Default: false
            ;
        },
        pos: struct {
            verbose: bool = false,
            positional: struct {
                p1: []const u8,
                p2: []const u8,
            },

            pub const aliases = .{
                .verbose = "v",
            };
        },
        required: struct {
            foo: u8,
            bar: u8,
        },
        values: struct {
            int: u32 = 0,
            boolean: bool = false,
            path: []const u8 = "not-set",
            optional: ?[]const u8 = null,
            choice: enum { marlowe, shakespeare } = .marlowe,
        },

        pub const help =
            \\ Usage: app [command] [options]
            \\
            \\ Commands:
            \\  empty           Runs the empty command.
            \\  example         Runs the example command.
            \\  ...             ...
            \\
            \\ General Options:
            \\  -h, --help      Displays this help message then exits
        ;
    };

    const result = zli.parse(&args, App);
    const writer = std.io.getStdOut().writer();

    switch (result) {
        .empty => try writer.print("Running command with no args", .{}),
        .example => |values| {
            try writer.print("Example:\n", .{});
            try writer.print("\tFoo: {d}\n", .{values.foo});
            try writer.print("\tFooBar: {d}\n", .{values.foo_bar});
            try writer.print("\tFooBarBaz: {s}\n", .{values.foo_bar_baz});
            try writer.print("\tOpt: {}\n", .{values.opt});
        },
        .pos => |values| {
            try writer.print("Positional:\n", .{});
            try writer.print("\tVerbose: {}\n", .{values.verbose});
            try writer.print("\tPos 1: {s}\n", .{values.positional.p1});
            try writer.print("\tPos 2: {s}\n", .{values.positional.p2});
        },
        .required => |values| {
            try writer.print("Required:\n", .{});
            try writer.print("\tFoo: {d}\n", .{values.foo});
            try writer.print("\tBar: {d}\n", .{values.bar});
        },
        .values => |values| {
            try writer.print("Values:\n", .{});
            try writer.print("\tInt: {d}\n", .{values.int});
            try writer.print("\tBool: {}\n", .{values.boolean});
            try writer.print("\tString: {s}\n", .{values.path});
            try writer.print("\tOptional: {?s}\n", .{values.optional});
            try writer.print("\tEnum: {s}\n", .{@tagName(values.choice)});
        },
    }
}
