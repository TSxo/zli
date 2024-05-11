const std = @import("std");
const assert = std.debug.assert;
const expectEqualStrings = std.testing.expectEqualStrings;

/// Light wrapper over `std.mem.indexOf`, specific for string use cases.
pub fn index_of(haystack: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, haystack, needle);
}

/// Light wrapper over `std.mem.eql`, specific for string use cases.
pub fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// Light wrapper over `std.mem.startsWith`, specific for string use cases.
pub fn starts_with(haystack: []const u8, needle: []const u8) bool {
    return std.mem.startsWith(u8, haystack, needle);
}

/// Replaces all occurrences of a given character in a string.
///
/// ```zig
/// assert(std.mem.eql(replace("test-case', "-", "_"), "test_case"));
/// ```
pub fn replace(haystack: []const u8, needle: []const u8, replacement: []const u8) []const u8 {
    var result: []const u8 = "";
    var index: usize = 0;

    while (index_of(haystack[index..], needle)) |i| {
        result = result ++ haystack[index..][0..i] ++ replacement;
        index = index + i + 1;
    }
    result = result ++ haystack[index..];
    return result;
}

test replace {
    comptime try expectEqualStrings("test_case", replace("test-case", "-", "_"));
    comptime try expectEqualStrings("test_case_", replace("test-case-", "-", "_"));
    comptime try expectEqualStrings("test__case", replace("test--case", "-", "_"));
    comptime try expectEqualStrings("test*cas*e", replace("test_cas_e", "_", "*"));
}

/// Takes in a type and returns a comma separated string of field names.
pub fn fields_to_string(comptime T: type) []const u8 {
    comptime {
        const fields = std.meta.fields(T);
        const len = fields.len;
        assert(len > 1);

        var out: []const u8 = "";

        for (fields, 0..) |field, idx| {
            const sep = switch (idx) {
                0 => "",
                len - 1 => " or ",
                else => ", ",
            };

            out = out ++ sep ++ "\"" ++ field.name ++ "\"";
        }

        return out;
    }
}
