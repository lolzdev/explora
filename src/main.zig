const std = @import("std");
const vulkan = @import("render/vulkan.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    _ = try vulkan.Renderer.init(allocator);
    _ = try vulkan.createInstance();
    //defer renderer.destroy();

    std.debug.print("Hello world\n", .{});
}
