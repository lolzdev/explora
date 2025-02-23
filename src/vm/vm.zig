const std = @import("std");
const wasm = @import("wasm.zig");
const Parser = @import("parse.zig");
const Allocator = std.mem.Allocator;

pub fn leb128Decode(comptime T: type, bytes: []u8) struct { usize, T } {
    var result = @as(T, 0);
    var shift = @as(u3, 0);
    var byte: u8 = undefined;
    var len = @as(usize, 0);
    for (bytes) |b| {
        len += 1;
        result |= (b & 0x7f) << shift;
        if ((b & (0x1 << 7)) == 0) {
            byte = b;
            break;
        }
        shift += 7;
    }
    if (T == i32 or T == i64) {
        const size = @sizeOf(T) * 8;
        if (shift < size and (byte & 0x40) != 0) {
            result |= (~0 << shift);
        }
    } else if (T != u64 and T != u32) {
        @compileError("LEB128 integer decoding only supports 32 or 64 bits integers.");
    }

    return .{ len, result };
}

pub const CallFrame = struct {
    program_counter: usize,
    code: []u8,
    locals: []Value,
};

const ValueType = enum {
    i32,
    i64,
};

pub const Value = union(ValueType) {
    i32: i32,
    i64: i64,
};

pub const Runtime = struct {
    module: Parser.Module,
    stack: std.ArrayList(Value),
    call_stack: std.ArrayList(CallFrame),

    pub fn init(allocator: Allocator, module: Parser.Module) !Runtime {
        return Runtime{
            .module = module,
            .stack = try std.ArrayList(Value).initCapacity(allocator, 10),
            .call_stack = try std.ArrayList(CallFrame).initCapacity(allocator, 5),
        };
    }

    pub fn deinit(self: *Runtime, allocator: Allocator) void {
        self.module.deinit(allocator);
        self.stack.deinit();
        self.call_stack.deinit();
    }

    pub fn executeFrame(self: *Runtime, frame: *CallFrame) !void {
        loop: while (true) {
            const byte: u8 = frame.code[frame.program_counter];
            frame.program_counter += 1;
            switch (byte) {
                0x20 => {
                    const integer = leb128Decode(u32, frame.code[frame.program_counter..]);

                    frame.program_counter += integer.@"0";
                    try self.stack.append(frame.locals[integer.@"1"]);
                },
                0x6a => {
                    const a = self.stack.pop();
                    const b = self.stack.pop();
                    try self.stack.append(.{ .i32 = a.i32 + b.i32 });
                },
                0xb => break :loop,
                else => {},
            }
        }
    }

    pub fn call(self: *Runtime, allocator: Allocator, name: []const u8, parameters: []usize) !void {
        if (self.module.exports.get(name)) |function| {
            const function_type = self.module.types[self.module.functions[function]];
            var frame = CallFrame{
                .code = self.module.code[function].code,
                .program_counter = 0x0,
                .locals = try allocator.alloc(Value, self.module.code[function].locals.len + function_type.parameters.len),
            };

            for (parameters, 0..) |p, i| {
                switch (Parser.parseType(function_type.parameters[i])) {
                    .i32 => {
                        frame.locals[i] = .{ .i32 = @intCast(p) };
                    },
                    .i64 => {
                        frame.locals[i] = .{ .i64 = @intCast(p) };
                    },
                    else => unreachable,
                }
            }

            for (self.module.code[function].locals, function_type.parameters.len..) |local, i| {
                switch (Parser.parseType(local.types[0])) {
                    .i32 => {
                        frame.locals[i] = .{ .i32 = 0 };
                    },
                    .i64 => {
                        frame.locals[i] = .{ .i64 = 0 };
                    },
                    else => unreachable,
                }
            }

            try self.executeFrame(&frame);

            std.debug.print("returned: {}\n", .{self.stack.pop()});
            allocator.free(frame.locals);
        }
    }
};
