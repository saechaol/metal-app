//
//  Renderer.swift
//  metalapp
//
//  Created by 세차오 루카스 on 1/18/23.
//

import Foundation
import MetalKit
import ModelIO // loads 3d data
import simd

struct Uniforms {
    var modelViewMatrix: float4x4
    var projectionMatrix: float4x4
}

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let mtkView: MTKView
    var vertexDescriptor: MTLVertexDescriptor!
    var meshes: [MTKMesh] = []
    // create render pipeline state
    var renderPipeline: MTLRenderPipelineState!
    
    let commandQueue: MTLCommandQueue
    var time: Float = 0
    // called when view changes size
    // this lets us update resolution dependent properties like projection matrix
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    // redraws contents of view
    func draw(in view: MTKView) {
        // we generate one command buffer per frame
        // when asked to render a frame by MTKView, the following code creates the command buffer in which our rendering commands are encoded into
        // encoding is the process of translating API calls into commands understood by the GPU
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // tells metal which texture we will draw into
        // the render pipeline state is configured with the pixel format of one of these textures
        // drawable is an object that holds the color texture and knows how to present it
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            // when drawing, iterate over meshes created from the imported asset
            time += 1 / Float(mtkView.preferredFramesPerSecond)
            let angle = -time
            
            let modelMatrix = float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), by: angle) * float4x4(scaleBy: 2)
            let viewMatrix = float4x4(translateBy: SIMD3<Float>(0, 0, -2))
            
            let modelViewMatrix = viewMatrix * modelMatrix
            
            let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            let projectionMatrix = float4x4(perspectiveProjectionMatrix: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
            
            var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
            commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            
            commandEncoder.setRenderPipelineState(renderPipeline)
            
            // iterate over meshes
            for mesh in meshes {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                
                for submesh in mesh.submeshes {
                    let indexBuffer = submesh.indexBuffer
                    commandEncoder.drawIndexedPrimitives(
                        type: submesh.primitiveType,
                        indexCount: submesh.indexCount,
                        indexType: submesh.indexType,
                        indexBuffer: indexBuffer.buffer,
                        indexBufferOffset: indexBuffer.offset
                    )
                }
            }
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
    }
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        
        // to issue commands to GPU, we need to create an object that manages GPU access
        // the command queue stores a sequence of command buffers, which GPU commands are written to
        // commands consist of things such as state setting operations, which describe how things are drawn and what resources to draw them with
        // the command queue also contains draw calls, which tell the GPU to actually draw geometry
        self.commandQueue = device.makeCommandQueue()!
        
        super.init()
        loadResources()
        
        // to maximize performance, Metal prefers vertex and fragment shaders to be compiled into a render pipeline state object
        buildPipeline()
    }
    
    func loadResources() {
        let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj")!
        
        // vertex descriptor
        // name, position and datatype for each attribute of vertices
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8) // provides a vertex buffer with 8 slots
        // slots are:
        // posX, posY, posZ,
        // normX, normY, normZ,
        // texCoordX, texCoordY
        
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        // create MDLAsset
        // an asset can have lights, cameras, and meshes but for now we just care about meshes
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        
        // fetch MTKMesh collection
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        } catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }
    }
    
    func buildPipeline() {
        // to get the shaders, we need MTLFunction getters, and these are retrieved by the library
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        // these correspond to the functions in our Shader.metal file
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        // configure the object that will tell Metal about the pipeline we want to create
        // the render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        // tell metal the format of the textures that will be drawn
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        // set vertex descriptor so pipeline knows how data is laid out into the 8 slot vertex buffer
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not craete render pipeline state object: \(error)")
        }
    }
}
