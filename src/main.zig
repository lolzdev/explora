const std = @import("std");
const c = @import("c.zig");
const window = @import("render/window.zig");
//const vk = @import("render/vulkan.zig");
const gl = @import("render/opengl.zig");
//const Renderer = @import("render/renderer.zig");
const math = @import("math.zig");
const Parser = @import("vm/parse.zig");
const vm = @import("vm/vm.zig");
const wasm = @import("vm/wasm.zig");

// @h3llll : I've temporarly commented vulkan code because im too lazy to figure out how to make the build system chose the library at compiletime and not check for it at runtime because that's just ugly and ugh i hate if statements so yeah

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    {
        var global_runtime = wasm.GlobalRuntime.init(allocator);
        defer global_runtime.deinit();
        try global_runtime.addFunction("debug", wasm.debug);
        const module = try Parser.parseWasm(allocator);
        var runtime = try vm.Runtime.init(allocator, module, &global_runtime);
        defer runtime.deinit(allocator);

        var parameters = [_]usize{ 3, 6 };
        try runtime.callExternal(allocator, "init", &parameters);

        const w = try window.Window.create(800, 600, "explora");
        defer w.destroy();

        //var r = try Renderer.create(allocator, w);
        //defer r.destroy();

        while (!w.shouldClose()) {
            c.glfwPollEvents();
            //try r.tick();
        }

        //try r.device.waitIdle();
    }

    if (gpa.detectLeaks()) {
        return error.leaked_memory;
    }
}
