const std = @import("std");
const mem = std.mem;
const ast = @import("ast.zig");
const scan = @import("scan.zig");
const token = @import("token.zig");

pub const Parser = struct {
    alloc: mem.Allocator,
    scanner: scan.Scanner,
    token: token.Token,

    types: std.ArrayList(ast.Type),
    strings: std.ArrayList([]u8),

    const Self = @This();

    inline fn advance(self: *Self) !void {
        self.token = try self.scanner.next();
    }

    pub inline fn init(alloc: mem.Allocator, src: []const u8) !Self {
        var scanner = try scan.Scanner.initStr(alloc, src);
        const tok = try scanner.next();
        return Self{
            .alloc = alloc,
            .scanner = scanner,
            .token = tok,
            .types = std.ArrayList(ast.Type).init(alloc),
            .strings = std.ArrayList([]u8).init(alloc),
        };
    }

    pub inline fn deinit(self: *Self) void {
        self.token.deinit(self.alloc);
        self.types.deinit();
        self.strings.deinit();
    }

    pub inline fn parseDocument(self: *Self) !ast.Document {
        var definitions = std.ArrayList(ast.TopLevelDefinition).init(self.alloc);
        var doc = ast.Document{ .definitions = definitions };
        return doc;
    }

    pub fn parseType(self: *Self) !*ast.Type {
        var p: *ast.Type = try self.types.addOne();
        switch (self.token.kind) {
            token.Kind.name => {
                defer self.token.deinit(self.alloc);
                const ident = try self.alloc.dupe(u8, self.token.value.str);
                try self.advance();
                p.* = ast.Type{ .named = ident };
            },
            token.Kind.left_bracket => {
                try self.advance();
                var of = try self.parseType();
                if (self.token.kind != token.Kind.right_bracket) {
                    return error.InvalidChar;
                }
                try self.advance();
                p.* = ast.Type{ .list = of };
            },
            else => return error.InvalidChar,
        }
        if (self.token.kind == token.Kind.exclamation_point) {
            try self.advance();
            var nn = try self.types.addOne();
            nn.* = ast.Type{ .nonNull = p };
            return nn;
        }
        return p;
    }
};
