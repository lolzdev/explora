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
    vertex_buffer: vk.Buffer,
    index_buffer: vk.Buffer,

    pub fn createVertexBuffer(device: anytype) !vk.Buffer {
        const vertices = [_]Vertex{
            Vertex.create(0.5, -0.5, -0.5),
            Vertex.create(0.5, 0.5, -0.5),
            Vertex.create(-0.5, 0.5, -0.5),
            Vertex.create(-0.5, -0.5, -0.5),
        };

        var data: [*c]?*anyopaque = null;

        const buffer = try device.createBuffer(vk.BufferUsage{ .transfer_src = true }, vk.BufferFlags{ .host_visible = true, .host_coherent = true }, @sizeOf(Vertex) * vertices.len);

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

        const vertex_buffer = try device.createBuffer(vk.BufferUsage{ .vertex_buffer = true, .transfer_dst = true }, vk.BufferFlags{ .device_local = true }, @sizeOf(Vertex) * vertices.len);

        try buffer.copyTo(device, vertex_buffer);
        buffer.destroy(device.handle);

        return vertex_buffer;
    }

    pub fn createIndexBuffer(device: anytype) !vk.Buffer {
        const indices = [_]u16{ 0, 1, 2, 3, 0, 2 };

        var data: [*c]?*anyopaque = null;

        const buffer = try device.createBuffer(vk.BufferUsage{ .transfer_src = true }, vk.BufferFlags{ .host_visible = true, .host_coherent = true }, @sizeOf(u16) * indices.len);

        try vk.mapError(c.vkMapMemory(
            device.handle,
            buffer.memory,
            0,
            buffer.size,
            0,
            @ptrCast(&data),
        ));

        if (data) |ptr| {
            const gpu_indices: [*]u16 = @ptrCast(@alignCast(ptr));

            @memcpy(gpu_indices, indices[0..]);
        }

        c.vkUnmapMemory(device.handle, buffer.memory);

        const index_buffer = try device.createBuffer(vk.BufferUsage{ .index_buffer = true, .transfer_dst = true }, vk.BufferFlags{ .device_local = true }, @sizeOf(u16) * indices.len);

        try buffer.copyTo(device, index_buffer);
        buffer.destroy(device.handle);

        return index_buffer;
    }

    pub fn create(device: anytype) !Mesh {
        const vertex_buffer = try Mesh.createVertexBuffer(device);
        const index_buffer = try Mesh.createIndexBuffer(device);

        return Mesh{
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
        };
    }
};
