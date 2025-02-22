const std = @import("std");
const wasm = @import("wasm.zig");
const Allocator = std.mem.Allocator;

pub const Module = struct {
    types: []FunctionType,
    imports: []Import,
    exports: []Export,
    functions: []u8,
    memory: Memory,
    contents: []u8,
    code: []FunctionBody,

    pub fn deinit(self: Module, allocator: Allocator) void {
        allocator.free(self.code);
        allocator.free(self.types);
        allocator.free(self.exports);
        allocator.free(self.imports);
        allocator.free(self.contents);
    }
};

pub const Local = struct {
    types: []u8,
};

pub const FunctionBody = struct {
    locals: []Local,
    code: []u8,
};

pub const Memory = struct {
    initial: u8,
    max: u8,
};

pub const FunctionType = struct {
    parameters: []u8,
    results: []u8,
};

pub const Export = struct {
    name: []u8,
    index: u8,
};

pub const Import = struct {
    module: []u8,
    name: []u8,
    signature: u8,
};

pub fn parseType(t: u8) wasm.Type {
    return @enumFromInt(t);
}

// TODO: parse Global Section
pub fn parseWasm(allocator: Allocator) !Module {
    const file = try std.fs.cwd().openFile("assets/core.wasm", .{});
    const size = (try file.metadata()).size();

    const contents = try file.reader().readAllAlloc(
        allocator,
        size,
    );

    var types: []FunctionType = undefined;
    var imports: []Import = undefined;
    var exports: []Export = undefined;
    var functions: []u8 = undefined;
    var memory: Memory = undefined;
    var code: []FunctionBody = undefined;

    var index = @as(usize, 8);
    var byte = contents[index];
    loop: while (index < (size - 1)) {
        const sec_size = contents[index + 1];
        switch (byte) {
            0x0 => break :loop,
            // Type section
            0x1 => {
                index += 2;
                const type_count = contents[index];
                types = try allocator.alloc(FunctionType, type_count);
                index += 1;
                for (0..type_count) |t| {
                    index += 1;
                    const params = contents[index];
                    index += 1;
                    types[t].parameters = contents[index..(index + params)];
                    index += params;

                    const results = contents[index];
                    index += 1;
                    types[t].results = contents[index..(index + results)];
                    index += results;
                }
            },
            // Import section
            0x2 => {
                index += 2;
                const import_count = contents[index];
                imports = try allocator.alloc(Import, import_count);
                index += 1;
                for (0..import_count) |i| {
                    var string_length = contents[index];
                    index += 1;
                    imports[i].module = contents[index..(index + string_length)];
                    index += string_length;
                    string_length = contents[index];
                    index += 1;
                    imports[i].name = contents[index..(index + string_length)];
                    index += string_length;

                    // kind (skip for now)
                    index += 1;
                    imports[i].signature = contents[index];
                    index += 1;
                }
            },
            // Function section
            0x3 => {
                index += 2;
                const function_count = contents[index];
                index += 1;
                functions = contents[index..(index + function_count)];
                index += function_count;
            },
            // Memory section
            0x5 => {
                index += 3;
                const flags = contents[index];
                index += 1;
                const initial = contents[index];
                var max = @as(u8, 0);
                index += 1;
                if (flags == 1) {
                    max = contents[index];
                    index += 1;
                }

                memory = .{
                    .initial = initial,
                    .max = max,
                };
            },
            // Export section
            0x7 => {
                index += 2;
                const export_count = contents[index];
                exports = try allocator.alloc(Export, export_count);
                index += 1;
                for (0..export_count) |i| {
                    const string_length = contents[index];
                    index += 1;
                    exports[i].name = contents[index..(index + string_length)];
                    index += string_length;
                    // kind (skip for now)
                    index += 1;
                    exports[i].index = contents[index];
                    index += 1;
                }
            },
            // Code section
            0x0a => {
                index += 2;
                const function_count = contents[index];
                code = try allocator.alloc(FunctionBody, function_count);
                index += 1;
                for (0..function_count) |i| {
                    const function_size = contents[index];
                    index += 1;
                    const local_count = contents[index];
                    index += 1;
                    var locals: []Local = undefined;
                    locals = try allocator.alloc(Local, local_count);
                    if (local_count > 0) {
                        for (0..local_count) |l| {
                            const type_count = contents[index];
                            index += 1;
                            locals[l].types = contents[index..(index + type_count)];
                            index += type_count;
                        }
                    } else {
                        locals = &[_]Local{};
                    }

                    code[i].locals = locals;

                    code[i].code = contents[index..(index + (function_size - local_count))];
                    index += function_size - local_count;
                }
            },
            else => index += sec_size + 2,
        }

        byte = contents[index];
    }

    return Module{
        .types = types,
        .imports = imports,
        .contents = contents,
        .functions = functions,
        .memory = memory,
        .exports = exports,
        .code = code,
    };
}
