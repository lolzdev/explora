const std = @import("std");
const c = @import("../c.zig");
const window = @import("./window.zig");
const Allocator = std.mem.Allocator;

const validation_layers: [1][*c]const u8 = .{
    "VK_LAYER_KHRONOS_validation",
};

const device_extensions: [1][*c]const u8 = .{
    c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
};

pub const Error = error{
    out_of_host_memory,
    out_of_device_memory,
    initialization_failed,
    layer_not_present,
    extension_not_present,
    incompatible_driver,
};

fn mapError(result: c_int) !void {
    return switch (result) {
        c.VK_ERROR_OUT_OF_HOST_MEMORY => Error.out_of_host_memory,
        c.VK_ERROR_OUT_OF_DEVICE_MEMORY => Error.out_of_device_memory,
        c.VK_ERROR_INITIALIZATION_FAILED => Error.initialization_failed,
        c.VK_ERROR_LAYER_NOT_PRESENT => Error.layer_not_present,
        c.VK_ERROR_EXTENSION_NOT_PRESENT => Error.extension_not_present,
        c.VK_ERROR_INCOMPATIBLE_DRIVER => Error.incompatible_driver,
        else => {},
    };
}

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
            .ppEnabledExtensionNames = @ptrCast(extensions),
            .enabledLayerCount = @intCast(validation_layers.len),
            .ppEnabledLayerNames = validation_layers[0..1].ptr,
        };

        var instance: c.VkInstance = undefined;

        try mapError(c.vkCreateInstance(&instance_info, null, &instance));

        return Instance{
            .handle = instance,
        };
    }

    pub fn destroy(self: *Instance) void {
        c.vkDestroyInstance(self.handle, null);
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

    pub fn destroy(self: *Surface, instance: Instance) void {
        c.vkDestroySurfaceKHR(instance.handle, self.handle, null);
    }
};

pub const Device = struct {
    handle: c.VkDevice,
    graphics_queue: c.VkQueue,
    present_queue: c.VkQueue,
    command_pool: c.VkCommandPool,
    command_buffer: c.VkCommandBuffer,

    pub fn beginCommand(self: *Device) !void {
        const begin_info: c.VkCommandBufferBeginInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        try mapError(c.vkBeginCommandBuffer(self.command_buffer, &begin_info));
    }

    pub fn endCommand(self: *Device) !void {
        try mapError(c.vkEndCommandBuffer(self.command_buffer));
    }

    pub fn destroy(self: *Device) void {
        c.vkDestroyCommandPool(self.handle, self.command_pool, null);
        c.vkDestroyDevice(self.handle, null);
    }
};

pub const PhysicalDevice = struct {
    handle: c.VkPhysicalDevice,

    pub fn pick(allocator: Allocator, instance: Instance) !PhysicalDevice {
        var device_count: u32 = 0;
        try mapError(c.vkEnumeratePhysicalDevices(instance.handle, &device_count, null));
        const devices = try allocator.alloc(c.VkPhysicalDevice, device_count);
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

    pub fn graphicsQueue(self: *PhysicalDevice, allocator: Allocator) !u32 {
        const queue_families = try self.queueFamilyProperties(allocator);
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

    pub fn presentQueue(self: *PhysicalDevice, surface: Surface, allocator: Allocator) !u32 {
        const queue_families = try self.queueFamilyProperties(allocator);
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

        const device_info: c.VkDeviceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = @ptrCast(queues[0..1].ptr),
            .enabledLayerCount = 0,
            .enabledExtensionCount = 1,
            .ppEnabledExtensionNames = device_extensions[0..1].ptr,
        };

        var device: c.VkDevice = undefined;
        try mapError(c.vkCreateDevice(self.handle, &device_info, null, &device));

        var graphics_queue: c.VkQueue = undefined;
        var present_queue: c.VkQueue = undefined;

        c.vkGetDeviceQueue(device, graphics_queue_index, 0, &graphics_queue);
        c.vkGetDeviceQueue(device, present_queue_index, 0, &present_queue);

        const command_pool_info: c.VkCommandPoolCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = graphics_queue_index,
        };

        var command_pool: c.VkCommandPool = undefined;
        try mapError(c.vkCreateCommandPool(device, &command_pool_info, null, &command_pool));

        const command_buffer_info: c.VkCommandBufferAllocateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = command_pool,
            .commandBufferCount = 1,
        };

        var command_buffer: c.VkCommandBuffer = undefined;
        try mapError(c.vkAllocateCommandBuffers(device, &command_buffer_info, &command_buffer));

        return Device{
            .handle = device,
            .graphics_queue = graphics_queue,
            .present_queue = present_queue,
            .command_pool = command_pool,
            .command_buffer = command_buffer,
        };
    }
};
