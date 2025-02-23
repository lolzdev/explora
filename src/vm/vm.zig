const std = @import("std");
const wasm = @import("wasm.zig");
const Parser = @import("parse.zig");
const Allocator = std.mem.Allocator;

pub fn leb128Decode(comptime T: type, bytes: []u8) T {
    var result = @as(T, 0);
    var shift = @as(T, 0);
    var byte = undefined;
    for (bytes) |b| {
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

    return result;
}

pub const CallFrame = struct {
    program_counter: usize,
    code: []u8,
    locals: []usize,
};

pub const Runtime = struct {
    module: Parser.Module,
    stack: std.ArrayList(usize),
    call_stack: std.ArrayList(CallFrame),

    pub fn init(allocator: Allocator, module: Parser.Module) !Runtime {
        return Runtime{
            .module = module,
            .stack = try std.ArrayList(usize).initCapacity(allocator, 10),
            .call_stack = try std.ArrayList(CallFrame).initCapacity(allocator, 5),
        };
    }

    pub fn deinit(self: *Runtime, allocator: Allocator) void {
        self.module.deinit(allocator);
        self.stack.deinit();
        self.call_stack.deinit();
    }
};
