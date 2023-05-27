const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;
const ast = @import("ast.zig");
const token = @import("token.zig");
const utf8 = @import("utf8.zig");

const STRSUBS = [_][]const u8{
    "\\u0000", "\\u0001", "\\u0002", "\\u0003", "\\u0004", "\\u0005", "\\u0006", "\\u0007",
    "\\b",     "\\t",     "\\n",     "\\u000B", "\\f",     "\\r",     "\\u000E", "\\u000F",
    "\\u0010", "\\u0011", "\\u0012", "\\u0013", "\\u0014", "\\u0015", "\\u0016", "\\u0017",
    "\\u0018", "\\u0019", "\\u001A", "\\u001B", "\\u001C", "\\u001D", "\\u001E", "\\u001F",
    "",        "",        "\\\"",    "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "\\\\",    "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "",
    "",        "",        "",        "",        "",        "",        "",        "\\u007F",
    "\\u0080", "\\u0081", "\\u0082", "\\u0083", "\\u0084", "\\u0085", "\\u0086", "\\u0087",
    "\\u0088", "\\u0089", "\\u008A", "\\u008B", "\\u008C", "\\u008D", "\\u008E", "\\u008F",
    "\\u0090", "\\u0091", "\\u0092", "\\u0093", "\\u0094", "\\u0095", "\\u0096", "\\u0097",
    "\\u0098", "\\u0099", "\\u009A", "\\u009B", "\\u009C", "\\u009D", "\\u009E", "\\u009F",
};

pub const Printer = struct {
    buf: std.ArrayList(u8),
    last: token.Kind,

    const Self = @This();

    pub inline fn init(alloc: mem.Allocator) !Self {
        const buf = std.ArrayList(u8).init(alloc);
        return Self{ .buf = buf, .last = .invalid };
    }

    pub inline fn deinit(self: *Self) void {
        self.buf.deinit();
    }

    pub fn printToken(self: *Self, tok: *token.Token) !void {
        try switch (tok.kind) {
            .invalid => {
                try fmt.format(self.buf.writer(), "<invalid {}:{}>", .{ tok.start, tok.end });
            },
            .sof => {},
            .eof => {},
            .exclamation_point => self.buf.append('!'),
            .question_mark => self.buf.append('?'),
            .dollar => self.buf.append('$'),
            .ampersand => self.buf.append('&'),
            .left_paren => self.buf.append('('),
            .right_paren => self.buf.append(')'),
            .spread => self.buf.appendSlice("..."),
            .colon => self.buf.append(':'),
            .equals => self.buf.append('='),
            .at => self.buf.append('@'),
            .left_bracket => self.buf.append('['),
            .right_bracket => self.buf.append(']'),
            .left_brace => self.buf.append('{'),
            .right_brace => self.buf.append('}'),
            .pipe => self.buf.append('|'),
            .name => {
                try switch (self.last) {
                    .name, .int, .float => self.buf.append(' '),
                    else => {},
                };
                try self.buf.appendSlice(tok.value.str);
            },
            .int => {
                try switch (self.last) {
                    .name, .int, .float => self.buf.append(' '),
                    else => {},
                };
                try fmt.formatInt(tok.value.int, 10, .lower, .{}, self.buf.writer());
            },
            .float => {
                try switch (self.last) {
                    .name, .int, .float => self.buf.append(' '),
                    else => {},
                };
                // Following https://docs.oracle.com/javase/8/docs/api/java/lang/Double.html#toString-double- to choose between decimal and scientific.
                // TODO: would be nice to output as many digits as necessary to distinguish from nearest floats, like the JVM.
                const val = tok.value.float;
                if (val > 1e-3 and val < 1e7) {
                    try fmt.formatFloatDecimal(val, .{}, self.buf.writer());
                } else {
                    try fmt.formatFloatScientific(val, .{}, self.buf.writer());
                }
            },
            .string => {
                try self.buf.append('"');
                var itr = unicode.Utf8View.initUnchecked(tok.value.str).iterator();
                while (itr.nextCodepoint()) |i| {
                    if (i < STRSUBS.len) {
                        const subst = STRSUBS[i];
                        if (subst.len == 0) {
                            const c = @intCast(u8, i);
                            try self.buf.append(c);
                        } else {
                            try self.buf.appendSlice(subst);
                        }
                    } else {
                        _ = try utf8.append(&self.buf, i);
                    }
                }
                try self.buf.append('"');
            },
        };
        self.last = tok.kind;
    }

    pub inline fn printDocument(self: *Self, doc: ast.Document) !void {
        _ = self;
        const foo = doc.definitions;
        _ = foo;
    }

    pub fn printType(self: *Self, typ: ast.Type) !void {
        switch (typ) {
            .named => |n| try self.buf.appendSlice(n),
            .list => |l| {
                try self.buf.append('[');
                try self.printType(l.*);
                try self.buf.append(']');
            },
            .nonNull => |nn| {
                try self.printType(nn.*);
                try self.buf.append('!');
            },
        }
    }

    pub inline fn output(self: *Self) []const u8 {
        return self.buf.items;
    }
};
