use std::mem;

use common::{chunk::Chunk, math::Vec2};

use super::{atlas::Atlas, buffer::Buffer, mesh, texture::Texture, Vertex};

pub struct Voxels {
    /// Terrain render pipeline
    render_pipeline: wgpu::RenderPipeline,
    /// Terrain geometry
    chunk_meshes: Vec<(Vec2<i32>, Buffer<Vertex>)>,
    /// Terrain indices
    index_buffer: Buffer<u32>,
    /// Buffer containing the offset of the currently drawn chunk
    offset_buffer: Buffer<[f32; 2]>,
    offset_stride: u32,
    chunk_bg: wgpu::BindGroup,
}

pub fn ceil_to_next_multiple(value: u32, step: u32) -> u32 {
    let divide_and_ceil = value / step + (if value % step == 0 { 0 } else { 1 });
    return step * divide_and_ceil;
}

impl Voxels {
    pub fn new(
        device: &wgpu::Device,
        common_bg_layout: &wgpu::BindGroupLayout,
        config: &wgpu::SurfaceConfiguration,
        atlas: &Atlas,
    ) -> Self {
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: None,
            source: wgpu::ShaderSource::Wgsl(
                include_str!("../../../assets/shaders/voxels.wgsl").into(),
            ),
        });


        let offset_stride = ceil_to_next_multiple(mem::size_of::<f32>() as u32 * 2, 0x100);
        let offset_buffer = Buffer::with_size(
            device,
            wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            offset_stride as u64 * 9,
        );

        let chunk_bg_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Chunk Bind Group Layout"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: true,
                    min_binding_size: None,
                },
                count: None,
            }],
        });

        let chunk_bg = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Chunk Bind Group"),
            layout: &chunk_bg_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::Buffer(wgpu::BufferBinding {
                    buffer: &offset_buffer.buf,
                    offset: 0,
                    size: wgpu::BufferSize::new(mem::size_of::<f32>() as u64 * 2),
                }),
            }],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: None,
            bind_group_layouts: &[&common_bg_layout, &chunk_bg_layout],
            push_constant_ranges: &[],
        });

        let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: None,
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[Vertex::desc()],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState::REPLACE),
                    write_mask: wgpu::ColorWrites::all(),
                })],
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                polygon_mode: wgpu::PolygonMode::Fill,
                unclipped_depth: false,
                conservative: false,
            },
            depth_stencil: Some(wgpu::DepthStencilState {
                format: Texture::DEPTH_FORMAT,
                depth_write_enabled: true,
                depth_compare: wgpu::CompareFunction::Less,
                stencil: wgpu::StencilState::default(),
                bias: wgpu::DepthBiasState::default(),
            }),
            multisample: wgpu::MultisampleState {
                count: 1,
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
        });

        // Test geometry
        let mut chunk_generation = vec![];
        for x in 0..3 {
            for z in 0..3 {
                chunk_generation.push((Vec2::new(x, z), Chunk::flat()));
            }
        }

        let mut chunk_meshes = vec![];
        let mut vertex_count = 0;

        for (pos, chunk) in chunk_generation {
            let mut chunk_mesh = vec![];
            mesh::create_chunk_mesh(&chunk, &mut chunk_mesh, pos, atlas);
            chunk_meshes.push((
                pos,
                Buffer::new(device, wgpu::BufferUsages::VERTEX, &chunk_mesh),
            ));
            vertex_count += chunk_mesh.len() as u32;
        }

        let index_buffer = Buffer::new(
            device,
            wgpu::BufferUsages::INDEX,
            &compute_voxel_indices(vertex_count as usize),
        );

        Self {
            render_pipeline,
            chunk_meshes,
            index_buffer,
            chunk_bg,
            offset_buffer,
            offset_stride
        }
    }

    pub fn draw<'a>(
        &'a mut self,
        frame: &mut wgpu::RenderPass<'a>,
        common_bg: &'a wgpu::BindGroup,
        queue: &'a wgpu::Queue,
    ) {
        frame.set_pipeline(&self.render_pipeline);
        frame.set_bind_group(0, common_bg, &[]);
        frame.set_index_buffer(self.index_buffer.slice(), wgpu::IndexFormat::Uint32);
        let mut stride = 0;
        for chunk_mesh in &self.chunk_meshes {
            queue.write_buffer(
                &self.offset_buffer.buf,
                (stride) as u64,
                bytemuck::cast_slice(&[chunk_mesh.0.x as f32, chunk_mesh.0.y as f32]),
            );
            
            frame.set_bind_group(1, &self.chunk_bg, &[stride]);
            frame.set_vertex_buffer(0, chunk_mesh.1.slice());
            frame.draw_indexed(0..chunk_mesh.1.len() / 4 * 6, 0, 0..1);
            stride += self.offset_stride;
        }
    }
}

fn compute_voxel_indices(number_of_vertices: usize) -> Vec<u32> {
    let mut indices = Vec::with_capacity(number_of_vertices * 6 / 4);
    for i in 0..number_of_vertices / 4 {
        let offset = i as u32 * 4;
        indices.extend_from_slice(&[
            offset,
            offset + 1,
            offset + 2,
            offset + 2,
            offset + 3,
            offset,
        ]);
    }
    indices
}
