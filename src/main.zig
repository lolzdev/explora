const std = @import("std");
const c = @import("c.zig");
const window = @import("render/window.zig");
const vk = @import("render/vulkan.zig");
const renderer = @import("render/renderer.zig");

pub fn main() !void {
    const w = try window.Window.create(800, 600, "explora");
    defer w.destroy();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var r = try renderer.Renderer.create(allocator, w);

    while (!w.shouldClose()) {
        c.glfwPollEvents();
        try r.tick();
    }

    try r.device.waitIdle();

    if (gpa.detectLeaks()) {
        return error.leaked_memory;
    }
}
