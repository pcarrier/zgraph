const std = @import("std");
const unicode = std.unicode;

pub inline fn append(arr: *std.ArrayList(u8), cp: u21) !u3 {
    var buf: [4]u8 = undefined;
    const len = try unicode.utf8Encode(cp, &buf);
    try arr.appendSlice(buf[0..len]);
    return len;
}
