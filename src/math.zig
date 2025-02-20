const std = @import("std");
const tan = std.math.tan;
const cos = std.math.cos;
const sin = std.math.sin;
const rad = std.math.rad;

pub const Matrix = struct {
    rows: @Vector(4, @Vector(4, f64)),

    pub fn lookAt(eye: @Vector(3, f64), target: @Vector(3, f64), arbitrary_up: @Vector(3, f64)) Matrix {
        const forward = normalize(eye - target);
        const right = normalize(cross(arbitrary_up, forward));
        const up = cross(forward, right);

        const view = @Vector(4, @Vector(4, f64)){
            @Vector(4, f64){ right[0], right[1], right[2], 0.0 },
            @Vector(4, f64){ up[0], up[1], up[2], 0.0 },
            @Vector(4, f64){ forward[0], forward[1], forward[2], 0.0 },
            @Vector(4, f64){ eye[0], eye[1], eye[2], 1.0 },
        };

        return Matrix{
            .rows = view,
        };
    }

    pub fn perspective(fov: f64, aspect: f64, near: f64, far: f64) Matrix {
        const projection = @Vector(4, @Vector(4, f64)){
            @Vector(4, f64){ 1.0 / (aspect * tan(fov / 2.0)), 0.0, 0.0, 0.0 },
            @Vector(4, f64){ 0.0, 1.0 / tan(fov / 2.0), 0.0, 0.0 },
            @Vector(4, f64){ 0.0, 0.0, -((far + near) / (far - near)), -((2 * far * near) / (far - near)) },
            @Vector(4, f64){ 0.0, 0.0, -1.0, 0.0 },
        };

        return Matrix{
            .rows = projection,
        };
    }
};

pub fn dot(a: @Vector(3, f64), b: @Vector(3, f64)) f64 {
    return @reduce(.Add, a * b);
}

pub fn cross(a: @Vector(3, f64), b: @Vector(3, f64)) @Vector(3, f64) {
    return @Vector(3, f64){ a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0] };
}

pub fn normalize(a: @Vector(3, f64)) @Vector(3, f64) {
    return a / @as(@Vector(3, f64), @splat(@sqrt(dot(a, a))));
}
