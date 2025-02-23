const c = @cImport({
    @cDefine("GLAD_GL_IMPLEMENTATION", "1"); // Tells glad to implement the functions(believe me idk why)
    @cInclude("glad.h");
});
