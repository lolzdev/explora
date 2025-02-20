const std = @import("std");
const c = @import("../c.zig");
const window = @import("./window.zig");
const mesh = @import("./mesh.zig");
const Allocator = std.mem.Allocator;

const builtin = @import("builtin");
const debug = (builtin.mode == .Debug);

const validation_layers: []const [*c]const u8 = if (!debug) &[0][*c]const u8{} else &[_][*c]const u8{
    "VK_LAYER_KHRONOS_validation",
};

const device_extensions: []const [*c]const u8 = &[_][*c]const u8{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

pub const Error = error{
    out_of_host_memory,
    out_of_device_memory,
    initialization_failed,
    layer_not_present,
    extension_not_present,
    incompatible_driver,
    unknown_error,
};

pub fn mapError(result: c_int) !void {
    return switch (result) {
        c.VK_SUCCESS => {},
        c.VK_ERROR_OUT_OF_HOST_MEMORY => Error.out_of_host_memory,
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => Error.out_of_device_memory,
        c.VK_ERROR_INITIALIZATION_FAILED => Error.initialization_failed,
        c.VK_ERROR_LAYER_NOT_PRESENT => Error.layer_not_present,
        c.VK_ERROR_EXTENSION_NOT_PRESENT => Error.extension_not_present,
        c.VK_ERROR_INCOMPATIBLE_DRIVER => Error.incompatible_driver,
        else => Error.unknown_error,
    };
}

pub const BufferUsage = packed struct (u32) {
    transfer_src: bool = false,
    transfer_dst: bool = false,
    uniform_texel_buffer: bool = false,
    storage_texel_buffer: bool = false,
    uniform_buffer: bool = false,
    storage_buffer: bool = false,
    index_buffer: bool = false,
    vertex_buffer: bool = false,
    indirect_buffer: bool = false,
    _padding: enum (u23) { unset } = .unset,
};

pub const BufferFlags = packed struct (u32) {
    device_local: bool = false,
    host_visible: bool = false,
    host_coherent: bool = false,
    host_cached: bool = false,
    lazily_allocated: bool = false,
    _padding: enum (u27) { unset } = .unset,
};

pub const Instance = struct {
    handle: c.VkInstance,

    pub fn create() !Instance {
        const extensions = window.getExtensions();

        const app_info: c.VkApplicationInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "explora",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "explora",
            .apiVersion = c.VK_MAKE_VERSION(1, 3, 0),
        };

        const instance_info: c.VkInstanceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = @intCast(extensions.len),
            .ppEnabledExtensionNames = extensions.ptr,
            .enabledLayerCount = @intCast(validation_layers.len),
            .ppEnabledLayerNames = validation_layers.ptr,
        };

        var instance: c.VkInstance = undefined;

        try mapError(c.vkCreateInstance(&instance_info, null, &instance));

        return Instance{
            .handle = instance,
        };
    }

    pub fn destroy(self: Instance) void {
        c.vkDestroyInstance(self.handle, null);
    }
};

pub const Buffer = struct {
    handle: c.VkBuffer,
    memory: c.VkDeviceMemory,
    size: usize,

    pub fn copyTo(self: Buffer, device: Device, dest: Buffer) !void {
        const command_buffer_info: c.VkCommandBufferAllocateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = device.command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };

        var command_buffer: c.VkCommandBuffer = undefined;
        try mapError(c.vkAllocateCommandBuffers(device.handle, &command_buffer_info, @ptrCast(&command_buffer)));

        const begin_info: c.VkCommandBufferBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        try mapError(c.vkBeginCommandBuffer(command_buffer, &begin_info));

        const copy_region: c.VkBufferCopy = .{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = self.size,
        };

        c.vkCmdCopyBuffer(command_buffer, self.handle, dest.handle, 1, &copy_region);
        try mapError(c.vkEndCommandBuffer(command_buffer));

        const submit_info: c.VkSubmitInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
        };

        try mapError(c.vkQueueSubmit(device.graphics_queue, 1, &submit_info, null));
        try mapError(c.vkQueueWaitIdle(device.graphics_queue));
        c.vkFreeCommandBuffers(device.handle, device.command_pool, 1, &command_buffer);
    }

    pub fn destroy(self: Buffer, device: Device) void {
        c.vkDestroyBuffer(device.handle, self.handle, null);
        c.vkFreeMemory(device.handle, self.memory, null);
    }
};

pub const RenderPass = struct {
    handle: c.VkRenderPass,

    pub fn create(allocator: Allocator, device: Device, surface: Surface, physical_device: PhysicalDevice) !RenderPass {
        const color_attachment: c.VkAttachmentDescription = .{
            .format = (try Swapchain.pickFormat(allocator, surface, physical_device)).format,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        };

        const color_attachment_reference: c.VkAttachmentReference = .{
            .attachment = 0,
            .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        const subpass: c.VkSubpassDescription = .{
            .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = &color_attachment_reference,
        };

        const dependency: c.VkSubpassDependency = .{
            .srcSubpass = c.VK_SUBPASS_EXTERNAL,
            .dstSubpass = 0,
            .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .srcAccessMask = 0,
            .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        };

        const render_pass_info: c.VkRenderPassCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &color_attachment,
            .subpassCount = 1,
            .pSubpasses = &subpass,
            .dependencyCount = 1,
            .pDependencies = &dependency,
        };

        var render_pass: c.VkRenderPass = undefined;

        try mapError(c.vkCreateRenderPass(device.handle, &render_pass_info, null, @ptrCast(&render_pass)));

        return RenderPass{
            .handle = render_pass,
        };
    }

    pub fn begin(self: RenderPass, swapchain: Swapchain, device: Device, image: usize, frame: usize) void {
        const clear_color: c.VkClearValue = .{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } };

        const begin_info: c.VkRenderPassBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = self.handle,
            .framebuffer = swapchain.framebuffers[image],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = swapchain.extent,
            },
            .clearValueCount = 1,
            .pClearValues = &clear_color,
        };

        c.vkCmdBeginRenderPass(device.command_buffers[frame], &begin_info, c.VK_SUBPASS_CONTENTS_INLINE);
    }

    pub fn end(self: RenderPass, device: Device, frame: usize) void {
        _ = self;
        c.vkCmdEndRenderPass(device.command_buffers[frame]);
    }

    pub fn destroy(self: RenderPass, device: Device) void {
        c.vkDestroyRenderPass(device.handle, self.handle, null);
    }
};

pub const GraphicsPipeline = struct {
    layout: c.VkPipelineLayout,
    handle: c.VkPipeline,

    pub fn create(device: Device, swapchain: Swapchain, render_pass: RenderPass, vertex_shader: Shader, fragment_shader: Shader) !GraphicsPipeline {
        const vertex_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
            .module = vertex_shader.handle,
            .pName = "main",
        };

        const fragment_shader_stage_info: c.VkPipelineShaderStageCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = fragment_shader.handle,
            .pName = "main",
        };

        const shader_stage_infos: [2]c.VkPipelineShaderStageCreateInfo = .{ vertex_shader_stage_info, fragment_shader_stage_info };

        const vertex_attributes: [1]c.VkVertexInputAttributeDescription = .{mesh.Vertex.attributeDescription()};
        const vertex_bindings: [1]c.VkVertexInputBindingDescription = .{mesh.Vertex.bindingDescription()};

        const vertex_input_info: c.VkPipelineVertexInputStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = 1,
            .pVertexBindingDescriptions = vertex_bindings[0..1].ptr,
            .vertexAttributeDescriptionCount = 1,
            .pVertexAttributeDescriptions = vertex_attributes[0..1].ptr,
        };

        const input_assembly_info: c.VkPipelineInputAssemblyStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = c.VK_FALSE,
        };

        const viewport: c.VkViewport = .{
            .x = 0.0,
            .y = 0.0,
            .width = @floatFromInt(swapchain.extent.width),
            .height = @floatFromInt(swapchain.extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        const scissor: c.VkRect2D = .{
            .offset = .{
                .x = 0.0,
                .y = 0.0,
            },
            .extent = swapchain.extent,
        };

        const viewport_state_info: c.VkPipelineViewportStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .pViewports = &viewport,
            .scissorCount = 1,
            .pScissors = &scissor,
        };

        const rasterizer_info: c.VkPipelineRasterizationStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = c.VK_FALSE,
            .rasterizerDiscardEnable = c.VK_FALSE,
            .polygonMode = c.VK_POLYGON_MODE_FILL,
            .lineWidth = 1.0,
            .cullMode = c.VK_CULL_MODE_BACK_BIT,
            .frontFace = c.VK_FRONT_FACE_CLOCKWISE,
            .depthBiasEnable = c.VK_FALSE,
        };

        const multisampling_info: c.VkPipelineMultisampleStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .sampleShadingEnable = c.VK_FALSE,
            .rasterizationSamples = c.VK_SAMPLE_COUNT_1_BIT,
        };

        const color_blend_attachment: c.VkPipelineColorBlendAttachmentState = .{
            .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
            .blendEnable = c.VK_TRUE,
            .srcColorBlendFactor = c.VK_BLEND_FACTOR_SRC_ALPHA,
            .dstColorBlendFactor = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
            .colorBlendOp = c.VK_BLEND_OP_ADD,
            .srcAlphaBlendFactor = c.VK_BLEND_FACTOR_ONE,
            .dstAlphaBlendFactor = c.VK_BLEND_FACTOR_ZERO,
            .alphaBlendOp = c.VK_BLEND_OP_ADD,
        };

        const color_blend_info: c.VkPipelineColorBlendStateCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .logicOpEnable = c.VK_FALSE,
            .logicOp = c.VK_LOGIC_OP_COPY,
            .attachmentCount = 1,
            .pAttachments = &color_blend_attachment,
            .blendConstants = .{ 0.0, 0.0, 0.0, 0.0 },
        };

        const layout_info: c.VkPipelineLayoutCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = 0,
            .pSetLayouts = null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        var layout: c.VkPipelineLayout = undefined;

        try mapError(c.vkCreatePipelineLayout(device.handle, &layout_info, null, @ptrCast(&layout)));

        const pipeline_info: c.VkGraphicsPipelineCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .stageCount = 2,
            .pStages = shader_stage_infos[0..2].ptr,
            .pVertexInputState = &vertex_input_info,
            .pInputAssemblyState = &input_assembly_info,
            .pViewportState = &viewport_state_info,
            .pRasterizationState = &rasterizer_info,
            .pMultisampleState = &multisampling_info,
            .pDepthStencilState = null,
            .pColorBlendState = &color_blend_info,
            .pDynamicState = null,
            .layout = layout,
            .renderPass = render_pass.handle,
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: c.VkPipeline = undefined;

        try mapError(c.vkCreateGraphicsPipelines(device.handle, null, 1, &pipeline_info, null, @ptrCast(&pipeline)));

        return GraphicsPipeline{
            .layout = layout,
            .handle = pipeline,
        };
    }

    pub fn bind(self: GraphicsPipeline, device: Device, frame: usize) void {
        c.vkCmdBindPipeline(device.command_buffers[frame], c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.handle);
    }

    pub fn destroy(self: GraphicsPipeline, device: Device) void {
        c.vkDestroyPipeline(device.handle, self.handle, null);
        c.vkDestroyPipelineLayout(device.handle, self.layout, null);
    }
};

pub const Shader = struct {
    handle: c.VkShaderModule,

    pub fn create(comptime name: []const u8, device: Device) !Shader {
        const code = @embedFile(name);

        const create_info: c.VkShaderModuleCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = code.len,
            .pCode = @ptrCast(@alignCast(code)),
        };

        var shader_module: c.VkShaderModule = undefined;

        try mapError(c.vkCreateShaderModule(device.handle, &create_info, null, @ptrCast(&shader_module)));

        return Shader{
            .handle = shader_module,
        };
    }

    pub fn destroy(self: Shader, device: Device) void {
        c.vkDestroyShaderModule(device.handle, self.handle, null);
    }
};

pub const Swapchain = struct {
    handle: c.VkSwapchainKHR,
    images: []c.VkImage,
    image_views: []c.VkImageView,
    format: c.VkSurfaceFormatKHR,
    extent: c.VkExtent2D,
    framebuffers: []c.VkFramebuffer,

    allocator: Allocator,

    pub fn pickFormat(allocator: Allocator, surface: Surface, physical_device: PhysicalDevice) !c.VkSurfaceFormatKHR {
        const formats = try surface.formats(allocator, physical_device);
        defer allocator.free(formats);
        var format: ?c.VkSurfaceFormatKHR = null;

        for (formats) |fmt| {
            if (fmt.format == c.VK_FORMAT_B8G8R8A8_SRGB and fmt.colorSpace == c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                format = fmt;
            }
        }

        if (format == null) {
            format = formats[0];
        }

        return format.?;
    }

    pub fn create(allocator: Allocator, surface: Surface, device: Device, physical_device: PhysicalDevice, w: window.Window, render_pass: RenderPass) !Swapchain {
        const present_modes = try surface.presentModes(allocator, physical_device);
        defer allocator.free(present_modes);
        const capabilities = try surface.capabilities(physical_device);
        var present_mode: ?c.VkPresentModeKHR = null;
        var extent: c.VkExtent2D = undefined;
        const format = try Swapchain.pickFormat(allocator, surface, physical_device);

        for (present_modes) |mode| {
            if (mode == c.VK_PRESENT_MODE_MAILBOX_KHR) {
                present_mode = mode;
            }
        }

        if (present_mode == null) {
            present_mode = c.VK_PRESENT_MODE_FIFO_KHR;
        }

        if (capabilities.currentExtent.width != std.math.maxInt(u32)) {
            extent = capabilities.currentExtent;
        } else {
            const width, const height = w.size();

            extent = .{
                .width = @intCast(width),
                .height = @intCast(height),
            };

            extent.width = std.math.clamp(extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
            extent.height = std.math.clamp(extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
        }

        var create_info: c.VkSwapchainCreateInfoKHR = .{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface.handle,
            .minImageCount = capabilities.minImageCount + 1,
            .imageFormat = format.format,
            .imageColorSpace = format.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .preTransform = capabilities.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode.?,
            .clipped = c.VK_TRUE,
            .oldSwapchain = null,
        };

        const graphics_family = try physical_device.graphicsQueue(allocator);
        const present_family = try physical_device.presentQueue(surface, allocator);
        const family_indices: [2]u32 = .{ graphics_family, present_family };

        if (graphics_family != present_family) {
            create_info.imageSharingMode = c.VK_SHARING_MODE_CONCURRENT;
            create_info.queueFamilyIndexCount = 2;
            create_info.pQueueFamilyIndices = family_indices[0..2].ptr;
        } else {
            create_info.imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE;
            create_info.queueFamilyIndexCount = 0;
            create_info.pQueueFamilyIndices = null;
        }

        var swapchain: c.VkSwapchainKHR = undefined;

        try mapError(c.vkCreateSwapchainKHR(device.handle, &create_info, null, &swapchain));

        var image_count: u32 = 0;
        try mapError(c.vkGetSwapchainImagesKHR(device.handle, swapchain, &image_count, null));
        const images = try allocator.alloc(c.VkImage, image_count);

        try mapError(c.vkGetSwapchainImagesKHR(device.handle, swapchain, &image_count, @ptrCast(images)));

        const image_views = try allocator.alloc(c.VkImageView, image_count);
        for (images, 0..) |image, index| {
            const view_create_info: c.VkImageViewCreateInfo = .{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = image,
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .format = format.format,
                .components = .{
                    .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = .{
                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };

            try mapError(c.vkCreateImageView(device.handle, &view_create_info, null, &(image_views[index])));
        }

        const framebuffers = try allocator.alloc(c.VkFramebuffer, image_count);
        for (image_views, 0..) |view, index| {
            const framebuffer_info: c.VkFramebufferCreateInfo = .{
                .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = render_pass.handle,
                .attachmentCount = 1,
                .pAttachments = &view,
                .width = extent.width,
                .height = extent.height,
                .layers = 1,
            };

            try mapError(c.vkCreateFramebuffer(device.handle, &framebuffer_info, null, &(framebuffers[index])));
        }

        return Swapchain{
            .handle = swapchain,
            .format = format,
            .extent = extent,
            .images = images[0..image_count],
            .image_views = image_views[0..image_count],
            .framebuffers = framebuffers,
            .allocator = allocator,
        };
    }

    pub fn nextImage(self: Swapchain, device: Device, frame: usize) !usize {
        var index: u32 = undefined;
        try mapError(c.vkAcquireNextImageKHR(device.handle, self.handle, std.math.maxInt(u64), device.image_available[frame], null, &index));

        return @intCast(index);
    }

    pub fn destroy(self: Swapchain, device: Device) void {
        for (self.image_views) |view| {
            c.vkDestroyImageView(device.handle, view, null);
        }

        for (self.framebuffers) |framebuffer| {
            c.vkDestroyFramebuffer(device.handle, framebuffer, null);
        }

        c.vkDestroySwapchainKHR(device.handle, self.handle, null);

        self.allocator.free(self.images);
        self.allocator.free(self.image_views);
        self.allocator.free(self.framebuffers);
    }
};

pub const Surface = struct {
    handle: c.VkSurfaceKHR,

    pub fn create(instance: Instance, w: window.Window) !Surface {
        var handle: c.VkSurfaceKHR = undefined;
        try mapError(c.glfwCreateWindowSurface(instance.handle, w.raw, null, &handle));
        return Surface{
            .handle = handle,
        };
    }

    pub fn presentModes(self: Surface, allocator: Allocator, device: PhysicalDevice) ![]c.VkPresentModeKHR {
        var mode_count: u32 = 0;
        try mapError(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device.handle, self.handle, &mode_count, null));
        const modes = try allocator.alloc(c.VkPresentModeKHR, mode_count);
        try mapError(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device.handle, self.handle, &mode_count, @ptrCast(modes)));

        return modes[0..mode_count];
    }

    pub fn formats(self: Surface, allocator: Allocator, device: PhysicalDevice) ![]c.VkSurfaceFormatKHR {
        var format_count: u32 = 0;
        try mapError(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device.handle, self.handle, &format_count, null));
        const fmts = try allocator.alloc(c.VkSurfaceFormatKHR, format_count);
        try mapError(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device.handle, self.handle, &format_count, @ptrCast(fmts)));

        return fmts[0..format_count];
    }

    pub fn capabilities(self: Surface, device: PhysicalDevice) !c.VkSurfaceCapabilitiesKHR {
        var caps: c.VkSurfaceCapabilitiesKHR = undefined;
        try mapError(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.handle, self.handle, &caps));
        return caps;
    }

    pub fn destroy(self: Surface, instance: Instance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, null);
    }
};

// TODO: Maybe device should be parametrized by number of in-flight frames,
//     therefore it would not need an allocator and could be stored directly
//     in memory. Maybe it doesn't even need to be parametrized as the way the
//     code is written right now it can only be 3.

pub const Device = struct {
    handle: c.VkDevice,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    command_pool: c.VkCommandPool,
    command_buffers: []c.VkCommandBuffer,
    image_available: []c.VkSemaphore,
    render_finished: []c.VkSemaphore,
    in_flight_fence: []c.VkFence,
    graphics_family: u32,
    present_family: u32,
    memory_properties: c.VkPhysicalDeviceMemoryProperties,

    allocator: Allocator,

    pub fn resetCommand(self: Device, frame: usize) !void {
        try mapError(c.vkResetCommandBuffer(self.command_buffers[frame], 0));
    }

    pub fn beginCommand(self: Device, frame: usize) !void {
        const begin_info: c.VkCommandBufferBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        try mapError(c.vkBeginCommandBuffer(self.command_buffers[frame], &begin_info));
    }

    pub fn endCommand(self: Device, frame: usize) !void {
        try mapError(c.vkEndCommandBuffer(self.command_buffers[frame]));
    }

    pub fn draw(self: Device, vertices: u32, frame: usize) void {
        c.vkCmdDraw(self.command_buffers[frame], vertices, 1, 0, 0);
    }

    pub fn waitFence(self: Device, frame: usize) !void {
        try mapError(c.vkWaitForFences(self.handle, 1, &self.in_flight_fence[frame], c.VK_TRUE, std.math.maxInt(u64)));
        try mapError(c.vkResetFences(self.handle, 1, &self.in_flight_fence[frame]));
    }

    pub fn waitIdle(self: Device) !void {
        try mapError(c.vkDeviceWaitIdle(self.handle));
    }

    pub fn bindVertexBuffer(self: Device, buffer: Buffer, frame: usize) void {
        const offset: u64 = 0;

        c.vkCmdBindVertexBuffers(self.command_buffers[frame], 0, 1, &buffer.handle, &offset);
    }

    pub fn pick_memory_type(self: Device, type_bits: u32, flags: u32) u32 {
        var memory_type_index: u32 = 0;
        for (0..self.memory_properties.memoryTypeCount) |index| {
            const memory_type = self.memory_properties.memoryTypes[index];

            if (((type_bits & (@as(u64, 1) << @intCast(index))) != 0) and (memory_type.propertyFlags & flags) != 0) {
                memory_type_index = @intCast(index);
            }
        }

        return memory_type_index;
    }

    pub fn createBuffer(self: Device, usage: BufferUsage, flags: BufferFlags, size: usize) !Buffer {
        const family_indices: [1]u32 = .{self.graphics_family};

        const create_info: c.VkBufferCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .size = size,
            .sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .usage = @bitCast(usage),
            .queueFamilyIndexCount = 1,
            .pQueueFamilyIndices = family_indices[0..1].ptr,
        };

        var buffer: c.VkBuffer = undefined;
        try mapError(c.vkCreateBuffer(self.handle, &create_info, null, &buffer));

        var memory_requirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(self.handle, buffer, &memory_requirements);

        const alloc_info: c.VkMemoryAllocateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = memory_requirements.size,
            .memoryTypeIndex = self.pick_memory_type(memory_requirements.memoryTypeBits, @bitCast(flags)),
        };

        var device_memory: c.VkDeviceMemory = undefined;

        try mapError(c.vkAllocateMemory(self.handle, &alloc_info, null, &device_memory));

        try mapError(c.vkBindBufferMemory(self.handle, buffer, device_memory, 0));

        return Buffer{
            .handle = buffer,
            .size = size,
            .memory = device_memory,
        };
    }

    pub fn submit(self: Device, swapchain: Swapchain, image: usize, frame: usize) !void {
        const wait_semaphores: [1]c.VkSemaphore = .{self.image_available[frame]};
        const signal_semaphores: [1]c.VkSemaphore = .{self.render_finished[frame]};
        const swapchains: [1]c.VkSwapchainKHR = .{swapchain.handle};
        const stages = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;

        const submit_info: c.VkSubmitInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = wait_semaphores[0..1].ptr,
            .pWaitDstStageMask = @ptrCast(&stages),
            .commandBufferCount = 1,
            .pCommandBuffers = &self.command_buffers[frame],
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = signal_semaphores[0..1].ptr,
        };

        try mapError(c.vkQueueSubmit(self.graphics_queue, 1, &submit_info, self.in_flight_fence[frame]));

        const present_info: c.VkPresentInfoKHR = .{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = signal_semaphores[0..1].ptr,
            .swapchainCount = 1,
            .pSwapchains = swapchains[0..1].ptr,
            .pImageIndices = @ptrCast(@alignCast(&image)),
            .pResults = null,
        };

        try mapError(c.vkQueuePresentKHR(self.present_queue, &present_info));
    }

    pub fn destroy(self: Device) void {
        for (0..2) |index| {
            c.vkDestroySemaphore(self.handle, self.image_available[index], null);
            c.vkDestroySemaphore(self.handle, self.render_finished[index], null);
            c.vkDestroyFence(self.handle, self.in_flight_fence[index], null);
        }

        c.vkDestroyCommandPool(self.handle, self.command_pool, null);
        c.vkDestroyDevice(self.handle, null);

        self.allocator.free(self.image_available);
        self.allocator.free(self.in_flight_fence);
        self.allocator.free(self.render_finished);
        self.allocator.free(self.command_buffers);
    }
};

pub const PhysicalDevice = struct {
    handle: c.VkPhysicalDevice,

    pub fn pick(allocator: Allocator, instance: Instance) !PhysicalDevice {
        var device_count: u32 = 0;
        try mapError(c.vkEnumeratePhysicalDevices(instance.handle, &device_count, null));
        const devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
        defer allocator.free(devices);
        try mapError(c.vkEnumeratePhysicalDevices(instance.handle, &device_count, @ptrCast(devices)));

        return PhysicalDevice{ .handle = devices[0] };
    }

    pub fn queueFamilyProperties(self: PhysicalDevice, allocator: Allocator) ![]const c.VkQueueFamilyProperties {
        var count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.handle, &count, null);
        const family_properties = try allocator.alloc(c.VkQueueFamilyProperties, count);
        c.vkGetPhysicalDeviceQueueFamilyProperties(self.handle, &count, @ptrCast(family_properties));

        return family_properties;
    }

    pub fn graphicsQueue(self: PhysicalDevice, allocator: Allocator) !u32 {
        const queue_families = try self.queueFamilyProperties(allocator);
        defer allocator.free(queue_families);
        var graphics_queue: ?u32 = null;

        for (queue_families, 0..) |family, index| {
            if (graphics_queue) |_| {
                break;
            }

            if ((family.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0x0) {
                graphics_queue = @intCast(index);
            }
        }

        return graphics_queue.?;
    }

    pub fn presentQueue(self: PhysicalDevice, surface: Surface, allocator: Allocator) !u32 {
        const queue_families = try self.queueFamilyProperties(allocator);
        defer allocator.free(queue_families);
        var present_queue: ?u32 = null;

        for (queue_families, 0..) |_, index| {
            if (present_queue) |_| {
                break;
            }

            var support: u32 = undefined;
            try mapError(c.vkGetPhysicalDeviceSurfaceSupportKHR(self.handle, @intCast(index), surface.handle, &support));

            if (support == c.VK_TRUE) {
                present_queue = @intCast(index);
            }
        }

        return present_queue.?;
    }

    pub fn create_device(self: *PhysicalDevice, surface: Surface, allocator: Allocator) !Device {
        const graphics_queue_index = try self.graphicsQueue(allocator);
        const present_queue_index = try self.presentQueue(surface, allocator);

        const priorities: f32 = 1.0;

        const graphics_queue_info: c.VkDeviceQueueCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = graphics_queue_index,
            .queueCount = 1,
            .pQueuePriorities = &priorities,
        };

        const present_queue_info: c.VkDeviceQueueCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = present_queue_index,
            .queueCount = 1,
            .pQueuePriorities = &priorities,
        };

        const queues: [2]c.VkDeviceQueueCreateInfo = .{ graphics_queue_info, present_queue_info };

        //var coherent_bit_amd: c.VkPhysicalDeviceCoherentMemoryFeaturesAMD = .{
        //    .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_COHERENT_MEMORY_FEATURES_AMD,
        //};
        var device_features: c.VkPhysicalDeviceFeatures2 = .{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            //.pNext = &coherent_bit_amd,
        };

        c.vkGetPhysicalDeviceFeatures2(self.handle, &device_features);

        //const features: [1][*c]const u8 = .{
        //    c.VK_AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME,
        //};

        //var extensions: []const [*c]const u8 = undefined;
        //if (coherent_bit_amd.deviceCoherentMemory == c.VK_TRUE) {
        //    extensions = &(device_extensions ++ features);
        //    std.debug.print("{s}\n", .{extensions[1]});
        //} else {
        //    extensions = &device_extensions;
        //}

        const device_info: c.VkDeviceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = &device_features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = @ptrCast(queues[0..1].ptr),
            .enabledLayerCount = 0,
            .enabledExtensionCount = @intCast(device_extensions.len),
            .ppEnabledExtensionNames = device_extensions.ptr,
        };

        var device: c.VkDevice = undefined;
        try mapError(c.vkCreateDevice(self.handle, &device_info, null, &device));

        var graphics_queue: c.VkQueue = undefined;
        var present_queue: c.VkQueue = undefined;

        c.vkGetDeviceQueue(device, graphics_queue_index, 0, &graphics_queue);
        c.vkGetDeviceQueue(device, present_queue_index, 0, &present_queue);

        const command_pool_info: c.VkCommandPoolCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = graphics_queue_index,
        };

        var command_pool: c.VkCommandPool = undefined;
        try mapError(c.vkCreateCommandPool(device, &command_pool_info, null, &command_pool));

        const command_buffer_info: c.VkCommandBufferAllocateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 2,
        };

        const command_buffers: []c.VkCommandBuffer = try allocator.alloc(c.VkCommandBuffer, 2);
        try mapError(c.vkAllocateCommandBuffers(device, &command_buffer_info, @constCast(command_buffers[0..2].ptr)));

        const semaphore_info: c.VkSemaphoreCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };

        const fence_info: c.VkFenceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        };

        var image_available: []c.VkSemaphore = try allocator.alloc(c.VkSemaphore, 2);
        var render_finished: []c.VkSemaphore = try allocator.alloc(c.VkSemaphore, 2);
        var in_flight_fence: []c.VkFence = try allocator.alloc(c.VkFence, 2);

        for (0..2) |index| {
            try mapError(c.vkCreateSemaphore(device, &semaphore_info, null, &image_available[index]));
            try mapError(c.vkCreateSemaphore(device, &semaphore_info, null, &render_finished[index]));
            try mapError(c.vkCreateFence(device, &fence_info, null, &in_flight_fence[index]));
        }

        var memory_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(self.handle, @constCast(&memory_properties));

        return Device{
            .handle = device,
            .graphics_queue = graphics_queue,
            .present_queue = present_queue,
            .command_pool = command_pool,
            .command_buffers = command_buffers,
            .image_available = image_available,
            .render_finished = render_finished,
            .in_flight_fence = in_flight_fence,
            .graphics_family = graphics_queue_index,
            .present_family = present_queue_index,
            .memory_properties = memory_properties,
            .allocator = allocator,
        };
    }
};
