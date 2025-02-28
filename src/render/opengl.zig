const c = @cImport({
    @cDefine("GLAD_GL_IMPLEMENTATION", "1"); // Tells glad to implement the functions, this is standard in single header libraries (check out STB for a good example)
    @cInclude("glad.h");
});

pub const Device = struct {
    // device stuff
};
