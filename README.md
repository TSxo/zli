# ZLI

This library is a friendly refactor of TigerBeetle's `flags` module that adds
support for:

-   subcommand specific help messages; and
-   short options (`-k=v`).

## TigerBeetle

To call this project anything other than a friendly refactor would be
disingenuous.

Full credit belongs to TigerBeetle for the inspiration and most of the logic
used throughout this library. This library has adopted the same license as the
original. Thank you to the original authors, and please see the links below to
show your support for TigerBeetle.

-   [Tigerbeetle](https://tigerbeetle.com)
-   [Tigerbeetle Github](https://github.com/tigerbeetle/tigerbeetle)
-   [Tigerbeetle Flags](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/flags.zig)
-   [Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md)

## Motivation

The principles advocated for in TigerBeetle's `Tiger Style` resonated strongly.
The interface that was defined for parsing CLI arguments in TigerBeetle's `flags`
module was exactly the API that I had been looking for. I greatly appreciated
their use of comptime and the design of their CLI guidelines. However, I had a
need for both subcommand specific help messages and short options - this library
aims to fill that need. In the spirit of the original code, I have made this
project public in case it may help others.

## Support and Limitations

Like the original, this library aims to be an 80% solution. It supports:

-   Subcommands;
-   Manual help messages for each subcommand and a global help message;
-   Long (`--key=value`) and short (`-k=v`) options; and
-   Positional arguments.

It does not auto-generate help messages, allow for `--key value` syntax, nor
support chaining short arguments or delimiter separated values.

It retains the original source's reliance on asserts / fatal errors.

Please note that while much of the core logic of this library has been taken from
[Tigerbeetle](https://github.com/tigerbeetle/tigerbeetle/blob/main/src/flags.zig),
the testing and snapshots have not. This library was created to solve a problem
I was having for side projects, so please use with this in mind.

If you need a more comprehensive CLI parsing solution, please see any of these
fantastic projects from the Zig community:
-   [Hejsil/zig-clap](https://github.com/Hejsil/zig-clap) - Simple command line argument parsing library
-   [prajwalch/yazap](https://github.com/prajwalch/yazap) - The ultimate Zig library for seamless command line parsing. Effortlessly handles options, subcommands, and custom arguments with ease.
-   [MasterQ32/zig-args](https://github.com/MasterQ32/zig-args) - Simple-to-use argument parser with struct-based config

## Installing

Requires [zig v0.12.x](https://ziglang.org).
1.  Initialize your project repository:
    ```bash
    git init
    ```
2.  Create a `libs` directory inside the root of your project:
    ```bash
    mkdir libs
    ```
3.  Add this library as a submodule of your project:
    ```bash
    git submodule add https://github.com/TSxo/zli libs/zli
    ```
4.  Inside your `build.zig`, bring in the `zli` module and add it as an import
    to your exe:
    ```zig
    const module = b.addModule("zli", .{
        .root_source_file = .{
            .path = "libs/zli/src/zli.zig",
        },
    });

    const exe = b.addExecutable(.{
        .name = "project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zli", module);
    ```
5.  `zli` is now usable in your project:
    ```zig
    const zli = @import("zli");
    ```

## Examples
### Simple

```zig
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
```

### Args Only

```zig
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
```

### Subcommands
```zig

const std = @import("std");
const assert = std.debug.assert;
const writer = std.io.getStdOut().writer();

const zli = @import("zli");

const View = struct {
    number: usize = 5,
    data_path: []const u8 = "./data/data.json",
    pub const aliases = .{
        .number = "n",
        .data_path = "p",
    };

    pub const help =
        \\ Command: view
        \\
        \\ Usage:
        \\
        \\ app view [-n, --number=<amount>] [-p, --data-path=<path>]
        \\
        \\ Options:
        \\
        \\ -h, --help               Displays this help message then exits.
        \\
        \\ -n, --number             The number of items to view.
        \\                          Default: 5.
        \\
        \\ -p, --data-path=<path>   The relative path to the data file.
        \\                          Default: ./data/data.json
    ;
};

const ViewAll = struct {
    data_path: []const u8 = "./data/data.json",
    pub const aliases = .{
        .data_path = "p",
    };

    pub const help =
        \\ Command: view-all
        \\
        \\ Usage:
        \\
        \\ app view-all -p, [--data-path=<path>]
        \\
        \\ Options:
        \\
        \\ -h, --help               Displays this help message then exits.
        \\
        \\ -p, --data-path=<path>   The relative path to the data file.
        \\                          Default: ./data/data.json
    ;
};

const Add = struct {
    data_path: []const u8 = "./data/data.json",
    positional: struct {
        item: []const u8,
    },

    pub const aliases = .{
        .data_path = "p",
    };

    pub const help =
        \\ Command: add
        \\
        \\ Usage:
        \\
        \\ app add [-p, --data-path=<path>] <item>
        \\
        \\ Options:
        \\
        \\ -h, --help               Displays this help message then exits
        \\
        \\ -p, --data-path=<path>   The relative path to the data file.
        \\                          Default: ./data/data.json
    ;
};

const Delete = struct {
    data_path: []const u8 = "./data/data.json",
    positional: struct {
        item: []const u8,
    },

    pub const aliases = .{
        .data_path = "p",
    };

    pub const help =
        \\ Command: delete
        \\
        \\ Usage:
        \\
        \\ app delete [-p, --data-path=<path>] <item>
        \\
        \\ Options:
        \\
        \\ -h, --help               Displays this help message then exits
        \\
        \\ -p, --data-path=<path>   The relative path to the data file.
        \\                          Default: ./data/data.json
    ;
};

const App = union(enum) {
    view: View,
    view_all: ViewAll,
    add: Add,
    delete: Delete,

    pub const help =
        \\ Usage: app [command] [options]
        \\
        \\ Commands:
        \\  view            View the last n items.
        \\  view-all        View all items.
        \\  add             Add a new item.
        \\  delete          Delete an item.
        \\
        \\ General Options:
        \\  -h, --help      Displays this help message then exits
    ;
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const result = zli.parse(&args, App);

    switch (result) {
        .view => |values| {
            try view(values);
        },
        .view_all => |values| {
            try view_all(values);
        },
        .add => |values| {
            try add(values);
        },
        .delete => |values| {
            try delete(values);
        },
    }
}

fn view(values: View) !void {
    try writer.print("View", .{});
    try writer.print("\tPath: {s}\n", .{values.data_path});
    try writer.print("\tNumber: {d}\n", .{values.number});
}

fn view_all(values: ViewAll) !void {
    try writer.print("View All", .{});
    try writer.print("\tPath: {s}\n", .{values.data_path});
}

fn add(values: Add) !void {
    try writer.print("Add Command:\n", .{});
    try writer.print("\tPath: {s}\n", .{values.data_path});
    try writer.print("\tPositional: {s}\n", .{values.positional.item});
}

fn delete(values: Delete) !void {
    try writer.print("Delete Command:\n", .{});
    try writer.print("\tPath: {s}\n", .{values.data_path});
    try writer.print("\tPositional: {s}\n", .{values.positional.item});
}

```
