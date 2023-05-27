const std = @import("std");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;

const utf8 = @import("utf8.zig");
const token = @import("token.zig");

pub const Scanner = struct {
    alloc: mem.Allocator,
    itr: unicode.Utf8Iterator,
    last_start: token.Pos,
    last: ?u21,

    const Self = @This();

    pub inline fn initItr(alloc: mem.Allocator, itr: unicode.Utf8Iterator) Self {
        var res = Self{ .alloc = alloc, .itr = itr, .last = null, .last_start = 0 };
        res.advance();
        return res;
    }

    pub inline fn initStr(alloc: mem.Allocator, str: []const u8) !Self {
        const itr = (try unicode.Utf8View.init(str)).iterator();
        return initItr(alloc, itr);
    }

    pub inline fn reset(self: *Self) void {
        self.itr.i = 0;
        self.last = null;
        self.last_start = 0;
        self.advance();
    }

    inline fn advance(self: *Self) void {
        self.last_start = self.itr.i;
        self.last = self.itr.nextCodepoint();
    }

    inline fn single(start: token.Pos, kind: token.Kind) token.Token {
        return token.Token{
            .kind = kind,
            .start = start,
            .end = start + 1,
            .value = .{ .empty = {} },
        };
    }

    inline fn skipWsAndComments(self: *Self) void {
        while (true) {
            const c = self.last orelse return;
            switch (c) {
                '\t', '\n', '\r', ' ', ',', 0xfeff => {},
                '#' => while (true) {
                    self.advance();
                    const commented = self.last orelse break;
                    if (commented == '\n') break;
                },
                else => return,
            }
            self.advance();
        }
    }

    inline fn scanName(self: *Self, start: token.Pos) !token.Token {
        var arr = std.ArrayList(u8).init(self.alloc);
        defer arr.deinit();

        while (true) {
            const c = self.last orelse break;
            switch (c) {
                'A'...'Z', 'a'...'z', '0'...'9', '_' => _ = try utf8.append(&arr, c),
                else => break,
            }
            self.advance();
        }
        const str = try arr.toOwnedSlice();
        return token.Token{
            .kind = .name,
            .start = start,
            .end = self.itr.i,
            .value = .{ .str = str },
        };
    }

    inline fn scanNumber(self: *Self, start: token.Pos) !token.Token {
        const c = self.last orelse return single(start, .invalid);
        var isFloat = false;
        var neg = false;
        var number: i64 = 0;
        var nege = false;
        var e: i32 = 0;
        var period: i32 = -1;

        if (c == '-') {
            neg = true;
            self.advance();
        }
        while (true) {
            const n = self.last orelse break;
            switch (n) {
                '0'...'9' => {
                    number = number * 10 + (n - '0');
                    if (period >= 0) period += 1;
                    self.advance();
                },
                '.' => {
                    if (isFloat) return single(start, .invalid);
                    isFloat = true;
                    period = 0;
                    self.advance();
                },
                'e', 'E' => {
                    isFloat = true;
                    self.advance();
                    const es = self.last orelse return single(start, .invalid);
                    switch (es) {
                        '+' => self.advance(),
                        '-' => {
                            nege = true;
                            self.advance();
                        },
                        else => {},
                    }
                    while (true) {
                        const ec = self.last orelse break;
                        switch (ec) {
                            '0'...'9' => {
                                e = e * 10 + (ec - '0');
                                self.advance();
                            },
                            else => break,
                        }
                    }
                },
                '_', 'A'...'D', 'F'...'Z', 'a'...'d', 'f'...'z' => {
                    return single(start, .invalid);
                },
                else => break,
            }
        }

        if (neg) number = -number;
        if (isFloat) {
            var res: f64 = @intToFloat(f64, number);
            if (nege) e = -e;
            if (period >= 0) e -= period;
            res *= math.pow(f64, 10.0, @intToFloat(f64, e));
            return token.Token{ .kind = .float, .start = start, .end = self.itr.i, .value = .{ .float = res } };
        } else {
            return token.Token{ .kind = .int, .start = start, .end = self.itr.i, .value = .{ .int = number } };
        }
    }

    inline fn scanUnicode(self: *Self) !u21 {
        var res: u21 = 0;
        self.advance();
        const n = self.last orelse return error.InvalidChar;
        if (n == '{') {
            var seen: u8 = 0;
            while (true) {
                self.advance();
                const c = self.last orelse return error.InvalidChar;
                switch (c) {
                    '0'...'9' => res = res * 16 + (c - '0'),
                    'A'...'F' => res = res * 16 + (c - 'A' + 10),
                    'a'...'f' => res = res * 16 + (c - 'a' + 10),
                    '}' => {
                        self.advance();
                        if (seen == 0 or seen > 4) return error.InvalidChar;
                        break;
                    },
                    else => return error.InvalidChar,
                }
                seen += 1;
            }
        } else {
            for (0..4) |_| {
                const c = self.last orelse return error.InvalidChar;
                switch (c) {
                    '0'...'9' => res = res * 16 + (c - '0'),
                    'A'...'F' => res = res * 16 + (c - 'A' + 10),
                    'a'...'f' => res = res * 16 + (c - 'a' + 10),
                    else => return error.InvalidChar,
                }
                self.advance();
            }
        }
        return res;
    }

    inline fn scanString(self: *Self, start: token.Pos) !token.Token {
        var buf = std.ArrayList(u8).init(self.alloc);
        defer buf.deinit();
        while (true) {
            const c = self.last orelse return single(self.itr.i, .invalid);
            switch (c) {
                '"' => {
                    self.advance();
                    return token.Token{ .kind = .string, .start = start, .end = self.itr.i, .value = .{ .str = try buf.toOwnedSlice() } };
                },
                '\\' => {
                    self.advance();
                    const e = self.last orelse return single(self.itr.i, .invalid);
                    switch (e) {
                        'b' => try buf.append('\x08'),
                        'f' => try buf.append('\x0c'),
                        'n' => try buf.append('\n'),
                        'r' => try buf.append('\r'),
                        't' => try buf.append('\t'),
                        'u' => _ = try utf8.append(&buf, try self.scanUnicode()),
                        else => _ = try utf8.append(&buf, e),
                    }
                    self.advance();
                },
                '\n' => return {
                    self.advance();
                    return single(self.itr.i, .invalid);
                },
                else => {
                    _ = try utf8.append(&buf, c);
                    self.advance();
                },
            }
        }
    }

    inline fn scanBlockStringForIndent(self: *Self) usize {
        var indent: usize = std.math.maxInt(usize);
        var lindent: usize = 0;
        var left_ws = false;
        // Skip the first line
        while (true) {
            const c = self.last orelse return indent;
            switch (c) {
                '"' => {
                    if (mem.eql(u8, self.itr.peek(2), "\"\"")) {
                        return indent;
                    }
                },
                '\\' => {
                    if (mem.eql(u8, self.itr.peek(3), "\"\"\"")) {
                        self.advance();
                        self.advance();
                    }
                },
                '\n' => break,
                else => {},
            }
            self.advance();
        }
        while (true) {
            const c = self.last orelse return indent;
            switch (c) {
                '"' => {
                    if (mem.eql(u8, self.itr.peek(2), "\"\"")) {
                        if (left_ws and lindent < indent) indent = lindent;
                        return indent;
                    }
                    left_ws = true;
                },
                '\\' => {
                    if (mem.eql(u8, self.itr.peek(3), "\"\"\"")) {
                        left_ws = true;
                        self.advance();
                        self.advance();
                    }
                },
                ' ', '\t' => {
                    if (!left_ws)
                        lindent += 1;
                },
                '\n' => {
                    if (left_ws) {
                        if (lindent < indent) indent = lindent;
                    }
                    lindent = 0;
                    left_ws = false;
                },
                else => {
                    left_ws = true;
                },
            }
            self.advance();
        }
    }

    inline fn scanBlockString(self: *Self, start: token.Pos) !token.Token {
        var buf = std.ArrayList(u8).init(self.alloc);
        defer buf.deinit();

        var cstart = self.itr.i;
        const indent = self.scanBlockStringForIndent();
        self.itr.i = cstart - 1;
        self.advance();

        var lstart = self.itr.i;
        var lproduced: usize = 0;
        var inIndent = true;
        var ws: usize = 0;
        var seenNonWS = false;

        while (true) {
            const c = self.last orelse return single(start, .invalid);
            switch (c) {
                ' ', '\t' => {
                    ws += 1;
                    if (inIndent) {
                        if (indent == ws) {
                            inIndent = false;
                        }
                    } else {
                        lproduced += try utf8.append(&buf, c);
                    }
                },
                '"' => {
                    inIndent = false;
                    seenNonWS = true;
                    if (mem.eql(u8, self.itr.peek(2), "\"\"")) {
                        if (lstart + ws == self.itr.i) {
                            if (seenNonWS) {
                                buf.items = buf.items[0 .. buf.items.len - lproduced];
                            } else {
                                buf.items = buf.items[0..0];
                            }
                        }
                        self.advance();
                        self.advance();
                        self.advance();
                        var i: usize = buf.items.len;
                        while (i > 0) {
                            i -= 1;
                            if (buf.items[i] != '\n') {
                                buf.items = buf.items[0 .. i + 1];
                                break;
                            }
                        }
                        return token.Token{ .kind = .string, .start = start, .end = self.itr.i, .value = .{ .str = try buf.toOwnedSlice() } };
                    } else {
                        lproduced += try utf8.append(&buf, c);
                    }
                },
                '\\' => {
                    inIndent = false;
                    self.advance();
                    const e = self.last orelse return single(self.itr.i, .invalid);
                    switch (e) {
                        'b' => {
                            lproduced += 1;
                            try buf.append('\x08');
                        },
                        'f' => {
                            lproduced += 1;
                            try buf.append('\x0c');
                        },
                        'n' => {
                            lproduced += 1;
                            try buf.append('\n');
                        },
                        'r' => {
                            lproduced += 1;
                            try buf.append('\r');
                        },
                        't' => {
                            lproduced += 1;
                            try buf.append('\t');
                        },
                        'u' => lproduced += try utf8.append(&buf, try self.scanUnicode()),
                        '"' => {
                            if (mem.eql(u8, self.itr.peek(2), "\"\"")) {
                                self.advance();
                                self.advance();
                                lproduced += 3;
                                try buf.appendSlice("\"\"\"");
                            } else {
                                lproduced += try utf8.append(&buf, e);
                            }
                        },
                        else => lproduced += try utf8.append(&buf, e),
                    }
                    self.advance();
                },
                '\r' => {
                    if (!mem.eql(u8, self.itr.peek(1), "\n")) {
                        lproduced += 1;
                        try buf.append('\r');
                    }
                },
                '\n' => {
                    if (ws == self.itr.i - lstart) {
                        if (seenNonWS) {
                            try buf.resize(buf.items.len - lproduced);
                            _ = try buf.append('\n');
                        } else {
                            try buf.resize(0);
                        }
                    } else {
                        _ = try buf.append('\n');
                    }
                    inIndent = true;
                    ws = 0;
                    lstart = self.itr.i + 1;
                    lproduced = 0;
                },
                else => {
                    inIndent = false;
                    seenNonWS = true;
                    _ = try utf8.append(&buf, c);
                },
            }
            self.advance();
        }
    }

    pub fn next(self: *Self) !token.Token {
        return self._next() catch {
            return token.Token{ .kind = .invalid, .start = self.itr.i, .end = self.itr.i + 1, .value = .{ .empty = {} } };
        };
    }

    inline fn _next(self: *Self) !token.Token {
        self.skipWsAndComments();
        const start = self.last_start;
        const c = self.last orelse return single(start, .eof);
        switch (c) {
            '!' => {
                self.advance();
                return single(start, .exclamation_point);
            },
            '?' => {
                self.advance();
                return single(start, .question_mark);
            },
            '$' => {
                self.advance();
                return single(start, .dollar);
            },
            '&' => {
                self.advance();
                return single(start, .ampersand);
            },
            '(' => {
                self.advance();
                return single(start, .left_paren);
            },
            ')' => {
                self.advance();
                return single(start, .right_paren);
            },
            '.' => {
                if (mem.eql(u8, self.itr.peek(2), "..")) {
                    self.advance();
                    self.advance();
                    self.advance();
                    return single(start, .spread);
                }
                return single(start, .invalid);
            },
            ':' => {
                self.advance();
                return single(start, .colon);
            },
            '=' => {
                self.advance();
                return single(start, .equals);
            },
            '@' => {
                self.advance();
                return single(start, .at);
            },
            '[' => {
                self.advance();
                return single(start, .left_bracket);
            },
            ']' => {
                self.advance();
                return single(start, .right_bracket);
            },
            '{' => {
                self.advance();
                return single(start, .left_brace);
            },
            '}' => {
                self.advance();
                return single(start, .right_brace);
            },
            '|' => {
                self.advance();
                return single(start, .pipe);
            },
            'A'...'Z', 'a'...'z', '_' => return try self.scanName(start),
            '-', '0'...'9' => return try self.scanNumber(start),
            '"' => {
                if (mem.eql(u8, self.itr.peek(2), "\"\"")) {
                    self.advance();
                    self.advance();
                    self.advance();
                    return try self.scanBlockString(start);
                } else {
                    self.advance();
                    return try self.scanString(start);
                }
            },
            else => {
                self.advance();
                return single(start, .invalid);
            },
        }
    }
};
