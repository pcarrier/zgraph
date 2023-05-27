const std = @import("std");
const mem = std.mem;

pub const Pos = usize;

pub const Kind = enum {
    invalid,
    sof,
    eof,
    exclamation_point,
    question_mark,
    dollar,
    ampersand,
    left_paren,
    right_paren,
    spread,
    colon,
    equals,
    at,
    left_bracket,
    right_bracket,
    left_brace,
    right_brace,
    pipe,
    name,
    int,
    float,
    string,
};

pub const Token = struct {
    kind: Kind,
    start: Pos,
    end: Pos,
    value: union {
        empty: void,
        str: []u8,
        int: i64,
        float: f64,
    },

    pub inline fn deinit(self: *Token, alloc: mem.Allocator) void {
        switch (self.kind) {
            .name, .string => alloc.free(self.value.str),
            else => {},
        }
    }
};
