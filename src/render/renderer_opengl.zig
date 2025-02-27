const c = @import("../c.zig");
const std = @import("std");
const window = @import("window.zig");
const mesh = @import("mesh.zig");
const Allocator = std.mem.Allocator;

const Renderer = @This();


pub fn create(allocator: Allocator, w: window.Window) !Renderer {
    _ = w;
    _ = allocator;

    return Renderer{
    };
}

pub fn destroy(self: Renderer) !void {
    _ = self;
}

// TODO: tick is maybe a bad name? something like present() or submit() is better?
pub fn tick(self: *Renderer) !void {
    _ = self;
}
