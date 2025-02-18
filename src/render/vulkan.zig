const std = @import("std");
const c = @import("../c.zig");
const window = @import("./window.zig");
const Allocator = std.mem.Allocator;

const validation_layers: [1][*c]const u8 = .{
    "VK_LAYER_KHRONOS_validation",
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

pub const Device = struct {
    handle: c.VkDevice,

    pub fn destroy(self: *Device) void {
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

    pub fn create_device(self: *PhysicalDevice) !Device {
        const device_info: c.VkDeviceCreateInfo = .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = 0,
            .enabledLayerCount = 0,
            .enabledExtensionCount = 0,
        };

        var device: c.VkDevice = undefined;
        try mapError(c.vkCreateDevice(self.handle, &device_info, null, &device));

        return Device{
            .handle = device,
        };
    }
};
