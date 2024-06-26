struct Uniforms {
    proj: mat4x4<f32>,
    view: mat4x4<f32>,
    atlas_size: u32,
    atlas_tile_size: u32,
}

@group(0) @binding(0)
var<uniform> uniforms: Uniforms;

@group(1) @binding(0)
var<uniform> offset: vec2<f32>;


struct VertexIn {
    @location(0) vertex_data: u32,
    @builtin(vertex_index) v_index: u32
}

struct VertexOut {
    @builtin(position) vertex_pos: vec4<f32>,
    @location(0) tex_coords: vec2<f32>
}

fn calculate_vertex_coordinates(data: u32) -> vec3<f32> {
	return vec3<f32>(f32(((data >> 28) & 0xf) | ((((data >> 12) >> 3) & 0x1) << 4)), f32(((data >> 20) & 0xff) | ((((data >> 12) >> 2) & 0x1) << 8)), f32(((data >> 16) & 0xf) | ((((data >> 12) >> 1) & 0x1) << 4)));
}

fn calculate_vertex_texture(data: u32) -> u32 {
	return (data & 0xfff);
}

fn calculate_texture_coordinates(v_index: u32, texture_id: u32) -> vec2<f32> {
    let tile_width = uniforms.atlas_tile_size;
    let tile_height = uniforms.atlas_tile_size;
    let tiles_per_row = uniforms.atlas_size / tile_width; 
    let pixel_x = f32((texture_id % tiles_per_row) * tile_width);
    let pixel_y = f32((texture_id / tiles_per_row) * tile_height);
    switch (v_index % 4u) {
          case 0u: {
            // top left
            return vec2<f32>(pixel_x / f32(uniforms.atlas_size), pixel_y / f32(uniforms.atlas_size));
          }
          case 1u: {
            // bottom left
            return vec2<f32>(pixel_x / f32(uniforms.atlas_size), (pixel_y + f32(tile_height)) / f32(uniforms.atlas_size));
          }
          case 2u: {
            // bottom right
            return vec2<f32>((pixel_x + f32(tile_width)) / f32(uniforms.atlas_size), (pixel_y + f32(tile_height)) / f32(uniforms.atlas_size));
          }
          case 3u: {
            // top right
            return vec2<f32>((pixel_x + f32(tile_width)) / f32(uniforms.atlas_size), pixel_y / f32(uniforms.atlas_size));
          }
          default: {
              return vec2<f32>(0.0, 0.0);
          }
      }

}

@vertex
fn vs_main(in: VertexIn) -> VertexOut{
    var out: VertexOut;
    var pos = calculate_vertex_coordinates(in.vertex_data);
    pos.x += offset.x * 16;
    pos.z += offset.y * 16;
    out.vertex_pos = uniforms.proj * uniforms.view * vec4<f32>(pos, 1.0);
    out.tex_coords = calculate_texture_coordinates(in.v_index, calculate_vertex_texture(in.vertex_data));
    return out;
}

@group(0) @binding(1)
var texture: texture_2d<f32>;
@group(0) @binding(2)
var texture_sampler: sampler;

@fragment
fn fs_main(in: VertexOut) -> @location(0) vec4<f32> {
    return textureSample(texture, texture_sampler, in.tex_coords);
}
