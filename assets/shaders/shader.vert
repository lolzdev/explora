#version 450

layout(location = 0) in vec3 vertPos;

layout(binding = 0) uniform UniformObject {
    mat4 view;
};

void main() {
    gl_Position = view * vec4(vertPos, 1.0);
}
