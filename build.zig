const std = @import("std");

const ShaderStage = enum { fragment, vertex };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .name = "explora",
    });

    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("glfw3");
    exe.linkLibC();

    compileAllShaders(b, exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn compileAllShaders(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const shaders_dir = if (@hasDecl(@TypeOf(b.build_root.handle), "openIterableDir"))
        b.build_root.handle.openIterableDir("assets/shaders", .{}) catch @panic("Failed to open shaders directory")
    else
        b.build_root.handle.openDir("assets/shaders", .{ .iterate = true }) catch @panic("Failed to open shaders directory");

    var file_it = shaders_dir.iterate();
    while (file_it.next() catch @panic("Failed to iterate shader directory")) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            const basename = std.fs.path.basename(entry.name);
            const name = basename[0 .. basename.len - ext.len];
            if (std.mem.eql(u8, ext, ".vert")) {
                addShader(b, exe, name, .vertex);
            } else if (std.mem.eql(u8, ext, ".frag")) {
                addShader(b, exe, name, .fragment);
            }
        }
    }
}

fn addShader(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8, stage: ShaderStage) void {
    const mod_name = std.fmt.allocPrint(b.allocator, "{s}_{s}", .{ name, if (stage == .vertex) "vert" else "frag" }) catch @panic("");
    const source = std.fmt.allocPrint(b.allocator, "assets/shaders/{s}.{s}", .{ name, if (stage == .vertex) "vert" else "frag" }) catch @panic("");
    const outpath = std.fmt.allocPrint(b.allocator, "assets/shaders/{s}_{s}.spv", .{ name, if (stage == .vertex) "vert" else "frag" }) catch @panic("");

    const shader_compilation = b.addSystemCommand(&.{"glslc"});
    shader_compilation.addArg("-o");
    const output = shader_compilation.addOutputFileArg(outpath);
    shader_compilation.addFileArg(b.path(source));

    exe.root_module.addAnonymousImport(mod_name, .{ .root_source_file = output });
}
