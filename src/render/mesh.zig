const c = @import("../c.zig");
const std = @import("std");
const vk = @import("vulkan.zig");
const Allocator = std.mem.Allocator;

pub const Vertex = struct {
    position: [3]f32,

    pub fn create(x: f32, y: f32, z: f32) Vertex {
        return Vertex{
            .position = .{ x, y, z },
        };
    }

    pub fn bindingDescription() c.VkVertexInputBindingDescription {
        const binding_description: c.VkVertexInputBindingDescription = .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
        };

        return binding_description;
    }

    pub fn attributeDescription() c.VkVertexInputAttributeDescription {
        const attribute_description: c.VkVertexInputAttributeDescription = .{
            .location = 0,
            .binding = 0,
            .format = c.VK_FORMAT_R32G32B32_SFLOAT,
            .offset = 0,
        };

        return attribute_description;
    }
};

pub const Mesh = struct {
    buffer: vk.Buffer,

    pub fn create(device: vk.Device) !Mesh {
        const vertices = [_]Vertex{
            Vertex.create(0.0, -0.5, 0.0),
            Vertex.create(0.5, 0.5, 0.0),
            Vertex.create(-0.5, 0.5, 0.0),
        };

        var data: [*c]?*anyopaque = null;

        const buffer = try device.createBuffer(vk.BufferUsage.transfer_src, vk.BufferFlags.host_visible | vk.BufferFlags.host_coherent, @sizeOf(Vertex) * 3);

        try vk.mapError(c.vkMapMemory(
            device.handle,
            buffer.memory,
            0,
            buffer.size,
            0,
            @ptrCast(&data),
        ));

        if (data) |ptr| {
            const gpu_vertices: [*]Vertex = @ptrCast(@alignCast(ptr));

            @memcpy(gpu_vertices, vertices[0..]);
        }

        c.vkUnmapMemory(device.handle, buffer.memory);

        const vertex_buffer = try device.createBuffer(vk.BufferUsage.vertex_buffer | vk.BufferUsage.transfer_dst, vk.BufferFlags.device_local, @sizeOf(Vertex) * 3);

        try buffer.copyTo(device, vertex_buffer);
        buffer.destroy(device);

        return Mesh{
            .buffer = vertex_buffer,
        };
    }
};
