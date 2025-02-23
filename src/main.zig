const std = @import("std");
const c = @import("c.zig");
const window = @import("render/window.zig");
//const vk = @import("render/vulkan.zig");
const gl = @import("render/opengl.zig");
//const Renderer = @import("render/renderer.zig");
const math = @import("math.zig");
const Parser = @import("vm/parse.zig");

// @h3llll : I've temporarly commented vulkan code because im too lazy to figure out how to make the build system chose the library at compiletime and not check for it at runtime because that's just ugly and ugh i hate if statements so yeah

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    {
        const module = try Parser.parseWasm(allocator);
        defer module.deinit(allocator);
        for (module.types) |p| {
            for (p.parameters) |par| {
                std.debug.print("{}\n", .{par});
            }
        }

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
