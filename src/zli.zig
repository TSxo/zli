//! This library is a friendly refactor of TigerBeetle's `flags` module that adds
//! support for:
//!
//! -   subcommand specific help messages; and
//! -   short options (`-k=v`).
//!
//! ============================================================================
//!
//! To call this project anything other than a friendly refactor would be
//! disingenuous.
//!
//! Full credit belongs to TigerBeetle for the inspiration and most of the logic
//! used throughout this library. This library has adopted the same license as
//! the original. Thank you, and please see the links below to show your support
//! for TigerBeetle.
//!
//! -   Tigerbeetle:        https://tigerbeetle.com
//! -   Tigerbeetle Github: https://github.com/tigerbeetle/tigerbeetle
//! -   Tigerbeetle Flags:  https://github.com/tigerbeetle/tigerbeetle/blob/main/src/flags.zig
//! -   Tiger Style:        https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md
//!
//! ============================================================================
//!
//! Motivation:
//!
//! The principles advocated for in TigerBeetle's `Tiger Style` resonated strongly.
//! The interface that was defined for parsing CLI arguments in TigerBeetle's
//! `flags` module was exactly the API that I had been looking for. I greatly
//! appreciated their use of comptime and the design of their CLI guidelines.
//! However, I had a need for both subcommand specific help messages and short
//! options - this library aims to fill that need. In the spirit of the original
//! code, I have made this project public in case it may help others.
//!
//! Support:
//!
//! Like the original, this library aims to be an 80% solution. It supports:
//! -   Subcommands;
//! -   Manual help messages for each subcommand and a global help message;
//! -   Long (`--key=value`) and short (`-k=v`) options; and
//! -   Positional arguments.
//!
//! It does not auto-generate help messages, allow for `--key value` syntax, nor
//! support chaining short arguments or delimiter separated values.
//!
//! It retains the original source's reliance on asserts / fatal errors.
//!
//! Please note that while much of the core logic of this library has been taken
//! from TigerBeetle's `flag` module, the testing and snapshots have not. This
//! library was created to solve a problem I was having for side projects, so
//! please use with this in mind.

const std = @import("std");
const ArgIterator = std.process.ArgIterator;
const StructField = std.builtin.Type.StructField;
const UnionField = std.builtin.Type.UnionField;
const assert = std.debug.assert;

const fatal = @import("./fatal.zig").fatal;
const structs = @import("./structs.zig");
const argx = @import("./arg.zig");
const strings = @import("./strings.zig");
const help = @import("./help.zig");

/// Parse CLI arguments for subcommands specified as Zig `struct` or `union(enum)`.
///
/// ```zig
/// const App = union(enum) {
///     view: struct {
///         number: usize = 5,
///
///         pub const aliases = .{ .number = "n" };
///         pub const help =
///             \\ Command: view
///             \\
///             \\ Usage:
///             \\
///             \\ app view [-n, --number=<amount>]
///             \\
///             \\ Options:
///             \\
///             \\ -h, --help   Displays this help message then exits
///             \\ -n, --number The number of items to view. Default: 5.
///         ;
///     },
///     add: struct {
///         positional: struct { item: []const u8 },
///
///         pub const help =
///             \\ Command: add
///             \\
///             \\ Usage:
///             \\
///             \\ app add <item>
///             \\
///             \\ Options:
///             \\
///             \\ -h, --help   Displays this help message then exits
///         ;
///     },
///
///     pub const help =
///         \\ Usage: app [command] [optins]
///         \\
///         \\ Commands:
///         \\  view            View the last n items.
///         \\  add             Add a new item.
///         \\
///         \\ General Options:
///         \\  -h, --help      Displays this help message then exits
///     ;
/// };
/// ```
pub fn parse(args: *ArgIterator, comptime CLIArgs: type) CLIArgs {
    assert(args.skip()); // Discard executable name.

    return switch (@typeInfo(CLIArgs)) {
        .Union => parse_commands(args, CLIArgs),
        .Struct => parse_args(args, CLIArgs),
        else => unreachable,
    };
}

fn parse_commands(args: *ArgIterator, comptime Commands: type) Commands {
    comptime assert(@typeInfo(Commands) == .Union);
    comptime assert(std.meta.fields(Commands).len > 1);

    const command = args.next() orelse fatal(
        "subcommand required: expected {s}",
        .{comptime strings.fields_to_string(Commands)},
    );

    if (help.requested_help(command)) {
        help.try_print_help(Commands);
    }

    inline for (comptime std.meta.fields(Commands)) |field| {
        const parsed_field = comptime strings.replace(field.name, "_", "-");
        if (strings.eql(command, parsed_field)) {
            return @unionInit(Commands, field.name, parse_args(args, field.type));
        }
    }

    fatal("Invalid subcommand: \"{s}\". Expected: {s}.", .{
        command,
        comptime strings.fields_to_string(Commands),
    });
}

fn parse_args(args: *ArgIterator, comptime Args: type) Args {
    if (Args == void) {
        if (args.next()) |arg| {
            fatal("unexpected argument: '{s}'", .{arg});
        }
        return {};
    }

    comptime assert(@typeInfo(Args) == .Struct);

    comptime var fields: [std.meta.fields(Args).len]StructField = undefined;
    comptime var field_count = 0;

    comptime var positional_fields: []const StructField = &.{};

    comptime for (std.meta.fields(Args)) |field| {
        if (strings.eql(field.name, "positional")) {
            assert(@typeInfo(field.type) == .Struct);

            positional_fields = std.meta.fields(field.type);

            for (positional_fields) |positional_field| {
                assert(structs.default_value(positional_field) == null);
                argx.assert_valid_value_type(positional_field.type);
            }
        } else {
            switch (@typeInfo(field.type)) {
                .Bool => {
                    assert(structs.default_value(field).? == false); // boolean flags should have a default
                },
                .Optional => |optional| {
                    assert(structs.default_value(field).? == null); // optional flags should have a default
                    argx.assert_valid_value_type(optional.child);
                },
                else => {
                    argx.assert_valid_value_type(field.type);
                },
            }

            fields[field_count] = field;
            field_count += 1;
        }
    };

    var result: Args = undefined;
    var counts: structs.struct_field_struct(Args, u32, 0) = .{};
    var parsed_positional = false;

    next_arg: while (args.next()) |arg| {
        if (help.requested_help(arg)) {
            help.try_print_help(Args);
        }

        const is_positional = if (arg[0] == '-') false else true;
        if (is_positional and @hasField(Args, "positional")) {
            if (parsed_positional) {
                fatal("Unknown positional argument: {s}", .{arg});
            }

            inline for (positional_fields, 0..) |field, idx| {
                if (counts.positional == idx) {
                    @field(result.positional, field.name) = argx.parse_value(field.type, field.name, arg);

                    counts.positional += 1;

                    if (counts.positional == positional_fields.len) {
                        parsed_positional = true;
                    }

                    continue :next_arg;
                }
            }
        }

        // arg is now known to not be positional, which means it must start
        // with a dash.
        const arg_name_cli = argx.name(arg);

        inline for (fields[0..field_count]) |field| {
            const arg_name_app = comptime strings.replace(field.name, "_", "-");

            if (strings.eql(arg_name_app, arg_name_cli)) {
                @field(counts, field.name) += 1;

                const value = argx.parse_arg(field.type, arg);
                @field(result, field.name) = value;

                continue :next_arg;
            }
        }

        if (@hasDecl(Args, "aliases")) {
            const aliases = comptime Args.aliases;

            inline for (std.meta.fields(@TypeOf(aliases))) |field| {
                const alias = @field(aliases, field.name);

                if (strings.eql(alias, arg_name_cli)) {
                    @field(counts, field.name) += 1;
                    const field_type = @TypeOf(@field(result, field.name));

                    const value = argx.parse_arg(field_type, arg);
                    @field(result, field.name) = value;

                    continue :next_arg;
                }
            }
        }

        // If we are here, then the current CLI argument is unknown.
        fatal("Unknown CLI argument: {s}\n", .{arg});
    }

    inline for (fields[0..field_count]) |field| {
        switch (@field(counts, field.name)) {
            0 => if (structs.default_value(field)) |default| {
                @field(result, field.name) = default;
            } else {
                fatal("{s}: argument is required", .{field.name});
            },
            1 => {},
            else => fatal("{s}: duplicate argument", .{field.name}),
        }
    }

    if (@hasField(Args, "positional")) {
        assert(counts.positional <= positional_fields.len);
        inline for (positional_fields, 0..) |field, idx| {
            if (counts.positional == idx) {
                fatal("{s}: argument is required", .{field.name});
            }
        }
    }

    return result;
}
