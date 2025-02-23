const std = @import("std");
const c = @import("c.zig");
const window = @import("render/window.zig");
const vk = @import("render/vulkan.zig");
const Renderer = @import("render/renderer.zig");
const math = @import("math.zig");
const Parser = @import("vm/parse.zig");
const vm = @import("vm/vm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    {
        const module = try Parser.parseWasm(allocator);
        var runtime = try vm.Runtime.init(allocator, module);
        defer runtime.deinit(allocator);

        const w = try window.Window.create(800, 600, "explora");
        defer w.destroy();

        var r = try Renderer.create(allocator, w);
        defer r.destroy();

        while (!w.shouldClose()) {
            c.glfwPollEvents();
            try r.tick();
        }

        try r.device.waitIdle();
    }

    if (gpa.detectLeaks()) {
        return error.leaked_memory;
    }
}
