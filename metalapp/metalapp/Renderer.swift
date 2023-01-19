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
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3
}

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let depthStencilState: MTLDepthStencilState
    var renderPipeline: MTLRenderPipelineState // create render pipeline state
    var vertexDescriptor: MDLVertexDescriptor
    var meshes: [MTKMesh] = []
    var time: Float = 0 // called when view changes size
    
    init(view: MTKView, device: MTLDevice) {
        self.device = device
        
        /**
         To issue commands to GPU, we need to create an object that manages GPU access
         This object is the command queue:
         - stores a sequence of command buffers, which GPU commands are written to
         - commands consist of state setting operations, whihc describes how things are drawn and what resources to draw them with
         - also contains draw calls which tell the GPU to draw geometry
         */
        commandQueue = device.makeCommandQueue()!
        
        vertexDescriptor = Renderer.buildVertexDescriptor()
        
        /**
         To maximize performance, Metal prefers vertex and fragment shaders to be compiled into a RenderPipelineState object
         */
        renderPipeline = Renderer.buildPipeline(device: device, view: view, vertexDescriptor: vertexDescriptor)
        depthStencilState = Renderer.buildDepthStencilState(device: device)
        super.init()
        loadResources()
    }
    
    func loadResources() {
        let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj")!
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        /**
         Create an MDLAsset.
         - an asset can have lights, cameras, and meshes, but for now we just care about meshes
         */
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        
        /**
         Fetch MTKMesh collection
         */
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        } catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }
    }
    
    static func buildVertexDescriptor() -> MDLVertexDescriptor {
        /**
         Vertex descriptor
         - contains name, position, and datatype for each vertices attributes
         */
        let vertexDescriptor = MDLVertexDescriptor()
        
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: MemoryLayout<Float>.size * 3,
                                                            bufferIndex: 0)
        
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: MemoryLayout<Float>.size * 6,
                                                            bufferIndex: 0)
        /**
         Provides a vertex buffer layout array with 8 elements
         - posX, posY, posZ [0, 1, 2]
         - normX, normY, normZ [3, 4, 5]
         - texCoordX, texCoordY [6, 7]
         */
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        
        return vertexDescriptor
    }
    
    
    static func buildPipeline(device: MTLDevice, view: MTKView, vertexDescriptor: MDLVertexDescriptor) -> MTLRenderPipelineState {
        /**
         Creates a library instance that will contain the functions written for the Shader
         */
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        /**
         Corresponds to shaders in **Shader.metal** file
         */
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        /**
         Configure object that will tell Metal about the pipeline we want to create
         */
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        /**
        Tell Metal the format of the textures that will be drawn
         */
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        /**
         Set vertex descriptor, so the pipeline understands how the data is laid out in the buffer
         */
        let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
        
    }
    
    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        /**
         Determines whether a fragment passes the "depth test"
         - a fragment that is closest to the camera for each pixel is kept, so we use a "less" comparison function
         */
        depthStencilDescriptor.depthCompareFunction = .less
        
        /**
         Allows depth values of passing fragments to be written to depth buffer. Otherwise, no writes to the depth buffer would occur.
         - some situations where this is not desired include particle rendering, but for opaque objects, it is preferred to have it enabled
         */
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        /**
         One command buffer is generated per frame
         - when asked to render a frame by MTKView, a command buffer is created in which rendering commands are encoded to
         - encoding translates API calls into commands understood by the GPU
         */
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        /**
         Tells Metal which texture that will be drawn into
         - configured with pixel format of one of those textures
         - drawable is an object that holds color texture and knows how to present it
         */
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            time += 1 / Float(view.preferredFramesPerSecond)
            let angle = -time
            
            let modelMatrix = float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), by: angle) * float4x4(scaleBy: 2)
            let viewMatrix = float4x4(translateBy: SIMD3<Float>(0, 0, -2))
            
            let modelViewMatrix = viewMatrix * modelMatrix
            let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
            let projectionMatrix = float4x4(perspectiveProjectionMatrix: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
            let viewProjectionMatrix = projectionMatrix * viewMatrix
            
            var uniforms = Uniforms(modelMatrix: modelViewMatrix, viewProjectionMatrix: viewProjectionMatrix, normalMatrix: modelMatrix.normalMatrix)
            
            commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setDepthStencilState(depthStencilState)
            
            for mesh in meshes {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                
                for submesh in mesh.submeshes {
                    let indexBuffer = submesh.indexBuffer
                    commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                         indexCount: submesh.indexCount,
                                                         indexType: submesh.indexType,
                                                         indexBuffer: indexBuffer.buffer,
                                                         indexBufferOffset: indexBuffer.offset)
                }
            }
            
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
