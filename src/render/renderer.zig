const c = @import("../c.zig");
const std = @import("std");
const vk = @import("vulkan.zig");
const window = @import("window.zig");
const mesh = @import("mesh.zig");
const Allocator = std.mem.Allocator;

pub const Renderer = struct {
    instance: vk.Instance,
    surface: vk.Surface,
    physical_device: vk.PhysicalDevice,
    device: vk.Device,
    render_pass: vk.RenderPass,
    swapchain: vk.Swapchain,
    graphics_pipeline: vk.GraphicsPipeline,
    current_frame: u32,
    vertex_buffer: vk.Buffer,

    pub fn create(allocator: Allocator, w: window.Window) !Renderer {
        const instance = try vk.Instance.create();

        const surface = try vk.Surface.create(instance, w);

        var physical_device = try vk.PhysicalDevice.pick(allocator, instance);
        const device = try physical_device.create_device(surface, allocator);

        var vertex_shader = try vk.Shader.create("shader_vert", device);
        defer vertex_shader.destroy(device);
        var fragment_shader = try vk.Shader.create("shader_frag", device);
        defer fragment_shader.destroy(device);

        const render_pass = try vk.RenderPass.create(allocator, device, surface, physical_device);

        const swapchain = try vk.Swapchain.create(allocator, surface, device, physical_device, w, render_pass);

        const graphics_pipeline = try vk.GraphicsPipeline.create(device, swapchain, render_pass, vertex_shader, fragment_shader);

        const triangle = try mesh.Mesh.create(device);

        return Renderer{
            .instance = instance,
            .surface = surface,
            .physical_device = physical_device,
            .device = device,
            .render_pass = render_pass,
            .swapchain = swapchain,
            .graphics_pipeline = graphics_pipeline,
            .current_frame = 0,
            .vertex_buffer = triangle.buffer,
        };
    }

    pub fn destroy(self: Renderer) void {
        self.graphics_pipeline.destroy(self.device);
        self.swapchain.destroy(self.device);
        self.render_pass.destroy(self.device);
        self.fragment_shader.destroy(self.device);
        self.device.destroy();
        self.surface.destroy(self.instance);
        self.instance.destroy();
    }

    pub fn tick(self: *Renderer) !void {
        try self.device.waitFence(self.current_frame);
        const image = try self.swapchain.nextImage(self.device, self.current_frame);
        try self.device.resetCommand(self.current_frame);
        try self.device.beginCommand(self.current_frame);
        self.render_pass.begin(self.swapchain, self.device, image, self.current_frame);
        self.graphics_pipeline.bind(self.device, self.current_frame);
        self.device.bindVertexBuffer(self.vertex_buffer, self.current_frame);
        self.device.draw(3, self.current_frame);
        self.render_pass.end(self.device, self.current_frame);
        try self.device.endCommand(self.current_frame);

        try self.device.submit(self.swapchain, image, self.current_frame);

        self.current_frame = (self.current_frame + 1) % 2;
    }
};
