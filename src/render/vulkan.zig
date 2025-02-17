const std = @import("std");
const c = @import("../c.zig");
const Allocator = std.mem.Allocator;

pub const Error = error{
    out_of_host_memory,
    out_of_device_memory,
    initialization_failed,
    device_lost,
    memory_map_failed,
    layer_not_present,
    extension_not_present,
    feature_not_present,
    incompatible_driver,
    too_many_objects,
    format_not_supported,
    fragmented_pool,
    unknown,
    out_of_pool_memory,
    invalid_external_handle,
    fragmentation,
    invalid_opaque_capture_address,
    pipeline_compile_required,
    not_permitted,
    surface_lost,
    native_window_in_use,
    imal,
    out_of_date,
    incompatible_display,
    validation_failed,
};

fn match_result(result: c_int) !void {
    return switch (result) {
        -1 => Error.out_of_host_memory,
        -2 => Error.out_of_device_memory,
        -3 => Error.initialization_failed,
        -4 => Error.device_lost,
        -5 => Error.memory_map_failed,
        -6 => Error.layer_not_present,
        -7 => Error.extension_not_present,
        -8 => Error.feature_not_present,
        -9 => Error.incompatible_driver,
        -10 => Error.too_many_objects,
        -11 => Error.format_not_supported,
        -12 => Error.fragmented_pool,
        -13 => Error.unknown,
        -1000069000 => Error.out_of_pool_memory,
        -1000072003 => Error.invalid_external_handle,
        -1000161000 => Error.fragmentation,
        -1000257000 => Error.invalid_opaque_capture_address,
        -1000174001 => Error.not_permitted,
        -1000000000 => Error.surface_lost,
        -1000000001 => Error.native_window_in_use,
        -1000001004 => Error.out_of_date,
        -1000003001 => Error.incompatible_display,
        -1000011001 => Error.validation_failed,
        else => {},
    };
}

pub fn createInstance() !void {
    const application_info = std.mem.zeroInit(c.VkApplicationInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .apiVersion = c.VK_MAKE_VERSION(1, 3, 0),
        .pApplicationName = "explora",
        .pEngineName = "explora",
    });

    const extensions = std.ArrayListUnmanaged([*c]const u8){};
    const layers = std.ArrayListUnmanaged([*c]const u8){};

    const instance_info = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
        .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application_info,
        .enabledLayerCount = 0,
        .ppEnabledLayerNames = layers.items.ptr,
        .enabledExtensionCount = 0,
        .ppEnabledExtensionNames = extensions.items.ptr,
    });

    var instance: c.VkInstance = undefined;
    const alloc: ?*c.VkAllocationCallbacks = null;

    std.debug.print("info: {*}\n{*}\n", .{ &instance_info, alloc });
    _ = c.vkCreateInstance(&instance_info, alloc, &instance);

    //if (result != 0) {
    //    return Error.out_of_host_memory;
    //}
}

pub const Renderer = struct {
    instance: c.VkInstance,
    allocator: Allocator,

    pub fn init(allocator: Allocator) !Renderer {
        //_ = try createInstance();
        const renderer = Renderer{
            .instance = undefined,
            .allocator = allocator,
        };

        return renderer;
    }

    pub fn destroy(_: *Renderer) void {
        //c.vkDestroyInstance(self.instance, null);
    }
};
