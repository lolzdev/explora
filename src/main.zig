const std = @import("std");
const window = @import("render/window.zig");
const vk = @import("render/vulkan.zig");

pub fn main() !void {
    _ = try window.Window.create(800, 600, "explora");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var instance = try vk.Instance.create();
    defer instance.destroy();

    var physical_device = try vk.PhysicalDevice.pick(allocator, instance);
    var device = try physical_device.create_device();
    defer device.destroy();

    //while (!w.shouldClose()) {}
}
