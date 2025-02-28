const std = @import("std");
const c = @import("c.zig");
const window = @import("render/window.zig");
<<<<<<< HEAD
const config = @import("config");
const vk = @import("render/vulkan.zig");
const gl = @import("render/opengl.zig");
const Renderer = @import("render/renderer.zig");
=======

const config = @import("config");
const Renderer = if (config.opengl) @import("render/renderer_opengl.zig") else @import("render/renderer_vulkan.zig");

>>>>>>> 3d5b53f1857026fc4cab4e14a11dfdfc0d565abe
const math = @import("math.zig");
const Parser = @import("vm/parse.zig");
const vm = @import("vm/vm.zig");
const wasm = @import("vm/wasm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    {
        var global_runtime = wasm.GlobalRuntime.init(allocator);
        defer global_runtime.deinit();
        try global_runtime.addFunction("debug", wasm.debug);

        const file = try std.fs.cwd().openFile("assets/core.wasm", .{});
        const module = try Parser.parseWasm(allocator, file.reader());
        var runtime = try vm.Runtime.init(allocator, module, &global_runtime);
        defer runtime.deinit(allocator);

        var parameters = [_]usize{};
        try runtime.callExternal(allocator, "fibonacci", &parameters);

        const w = try window.Window.create(800, 600, "explora");
        defer w.destroy();

<<<<<<< HEAD
        var r = try Renderer.create(allocator, w);
        defer r.destroy();
=======
        // TODO: Renderer.destroy should not return an error?
        var r = try Renderer.create(allocator, w);
        defer r.destroy() catch {};
>>>>>>> 3d5b53f1857026fc4cab4e14a11dfdfc0d565abe

        while (!w.shouldClose()) {
            c.glfwPollEvents();
            try r.tick();
        }
<<<<<<< HEAD

        try r.device.waitIdle();
=======
>>>>>>> 3d5b53f1857026fc4cab4e14a11dfdfc0d565abe
    }

    if (gpa.detectLeaks()) {
        return error.leaked_memory;
    }
}
