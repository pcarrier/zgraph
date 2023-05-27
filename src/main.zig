const std = @import("std");
const fs = std.fs;
const process = std.process;
const io = std.io;
const mem = std.mem;
const parse = @import("parse.zig");
const print = @import("print.zig");
const scan = @import("scan.zig");
const ph = @import("perfectHash.zig");

fn usage(writer: fs.File.Writer) !void {
    try writer.writeAll("Usage: zig [tokens|type]\n");
    process.exit(1);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const in = io.getStdIn();
    const out = io.getStdOut();
    const writer = out.writer();

    const args = try process.argsAlloc(alloc);
    if (args.len < 2) {
        try usage(writer);
    }

    var printer = try print.Printer.init(alloc);

    if (mem.eql(u8, args[1], "tokens")) {
        const src = try in.readToEndAlloc(alloc, 1 << 30);
        defer alloc.free(src);
        try printTokens(alloc, src, &printer, writer);
    } else if (mem.eql(u8, args[1], "type")) {
        const src = try in.readToEndAlloc(alloc, 1 << 30);
        defer alloc.free(src);
        try printType(alloc, src, &printer, writer);
    } else {
        try usage(writer);
    }
}

fn printTokens(alloc: std.mem.Allocator, src: []const u8, printer: *print.Printer, writer: fs.File.Writer) !void {
    var scanner = try scan.Scanner.initStr(alloc, src);

    while (true) {
        var tok = try scanner.next();
        try printer.printToken(&tok);
        if (tok.kind == .eof) {
            break;
        }
    }

    try writer.writeAll(printer.output());
}

fn printType(alloc: std.mem.Allocator, src: []const u8, printer: *print.Printer, writer: fs.File.Writer) !void {
    var parser = try parse.Parser.init(alloc, src);
    defer parser.deinit();

    var typ = try parser.parseType();
    try printer.printType(typ.*);
    try writer.writeAll(printer.output());
}
