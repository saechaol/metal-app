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

struct VertexUniforms {
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3
}

struct FragmentUniforms {
    var cameraWorldPosition = SIMD3<Float>(0, 0, 0)
    var ambientLightColor = SIMD3<Float>(0, 0, 0)
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var light0 = Light()
    var light1 = Light()
    var light2 = Light()
}

class Renderer: NSObject, MTKViewDelegate {
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let depthStencilState: MTLDepthStencilState
    let samplerState: MTLSamplerState
    let scene: Scene
    var renderPipeline: MTLRenderPipelineState // create render pipeline state
    var vertexDescriptor: MDLVertexDescriptor
    var time: Float = 0 // called when view changes size
    var cameraWorldPosition = SIMD3<Float>(0, 0, 2)
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4
    var baseColorTexture: MTLTexture?
    
    static let fishCount = 12
    
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
        samplerState = Renderer.buildSamplerState(device: device)
        scene = Renderer.buildScene(device: device, vertexDescriptor: vertexDescriptor)
        super.init()
    }
    
    static func buildScene(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) -> Scene {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.generateMipmaps: true, .SRGB: true]
        
        let scene = Scene()
        
        scene.ambientLightColor = SIMD3<Float>(0.1, 0.1, 0.1)
        
        let light0 = Light(worldPosition: SIMD3<Float>(5, 5, 0), color: SIMD3<Float>(0.3, 0.3, 0.3))
        let light1 = Light(worldPosition: SIMD3<Float>(-5, 5, 0), color: SIMD3<Float>(0.3, 0.3, 0.3))
        let light2 = Light(worldPosition: SIMD3<Float>(0, -5, 0), color: SIMD3<Float>(0.3, 0.3, 0.3))
        
        scene.lights = [light0, light1, light2]
        
        let bob = Node(name: "Bob")
        let bobMaterial = Material()
        let bobBaseColorTexture = try? textureLoader.newTexture(name: "bob_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        
        bobMaterial.baseColorTexture = bobBaseColorTexture
        bobMaterial.specularPower = 100
        bobMaterial.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        bob.material = bobMaterial
        
        let bobURL = Bundle.main.url(forResource: "bob", withExtension: "obj")!
        let bobAsset = MDLAsset(url: bobURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        bob.mesh = try! MTKMesh.newMeshes(asset: bobAsset, device: device).metalKitMeshes.first!
        
        scene.rootNode.children.append(bob)
        
        let blubMaterial = Material()
        let blubBaseColorTexture = try? textureLoader.newTexture(name: "blub_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        
        blubMaterial.baseColorTexture = blubBaseColorTexture
        blubMaterial.specularPower = 40
        blubMaterial.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        
        let blubURL = Bundle.main.url(forResource: "blub", withExtension: "obj")!
        let blubAsset = MDLAsset(url: blubURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        let blubMesh = try! MTKMesh.newMeshes(asset: blubAsset, device: device).metalKitMeshes.first!
        
        for i in 1...fishCount {
            let blub = Node(name: "Blub \(i)")
            blub.material = blubMaterial
            blub.mesh = blubMesh
            bob.children.append(blub)
        }
        
        return scene
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
    
    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        update(view)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.63, 0.81, 1.0, 1.0)
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setFrontFacing(.counterClockwise)
            commandEncoder.setCullMode(.back)
            commandEncoder.setDepthStencilState(depthStencilState)
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            drawNodeRecursive(scene.rootNode, parentTransform: matrix_identity_float4x4, commandEncoder: commandEncoder)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func drawNodeRecursive(_ node: Node, parentTransform: float4x4, commandEncoder: MTLRenderCommandEncoder) {
        let modelMatrix = parentTransform * node.modelMatrix
        
        if let mesh = node.mesh, let baseColorTexture = node.material.baseColorTexture {
            let viewProjectionMatrix = projectionMatrix * viewMatrix
            var vertexUniforms = VertexUniforms(modelMatrix: modelMatrix, viewProjectionMatrix: viewProjectionMatrix, normalMatrix: modelMatrix.normalMatrix)
            commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
            
            var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition,
                                                    ambientLightColor: scene.ambientLightColor,
                                                    specularColor: node.material.specularColor,
                                                    specularPower: node.material.specularPower,
                                                    light0: scene.lights[0],
                                                    light1: scene.lights[1],
                                                    light2: scene.lights[2])
            commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
            commandEncoder.setFragmentTexture(baseColorTexture, index: 0)
            
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
        
        for child in node.children {
            drawNodeRecursive(child, parentTransform: modelMatrix, commandEncoder: commandEncoder)
        }
    }
    
    func update(_ view: MTKView) {
        time += 1 / Float(view.preferredFramesPerSecond)
        cameraWorldPosition = SIMD3<Float>(0, 0, 2)
        viewMatrix = float4x4(translateBy: -cameraWorldPosition) * float4x4(rotateAbout: SIMD3<Float>(1, 0, 0), by: .pi / 6)
        
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        projectionMatrix = float4x4(perspectiveProjectionMatrix: Float.pi / 6, aspectRatio: aspectRatio, nearZ: 0.01, farZ: 100)
        
        let angle = -time
        scene.rootNode.modelMatrix = float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), by: angle) * float4x4(scaleBy: 0.5)
        
        if let bob = scene.nodeNamed("Bob") {
            bob.modelMatrix = float4x4(translateBy: SIMD3<Float>(0, 0.015 * sin(time * 5), 0))
        }
        
        let blubBaseTransform = float4x4(rotateAbout: SIMD3<Float>(0, 0, 1), by: -.pi / 2) * float4x4(scaleBy: 0.25) * float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), by: -.pi / 2)
        
        let fishCount = Renderer.fishCount
        for i in 1...fishCount {
            if let blub = scene.nodeNamed("Blub \(i)") {
                let pivotPosition = SIMD3<Float>(0.4, 0, 0)
                let rotationOffset = SIMD3<Float>(0.4, 0, 0)
                let rotationSpeed = Float(0.3)
                let rotationAngle = 2 * Float.pi * Float(rotationSpeed * time) + (2 * Float.pi / Float(fishCount) * Float(i - 1))
                let horizontalAngle = 2 * .pi / Float(fishCount) * Float(i - 1)
                blub.modelMatrix =  float4x4(rotateAbout: SIMD3<Float>(0, 1, 0), by: horizontalAngle) *
                                    float4x4(translateBy: rotationOffset) *
                                    float4x4(rotateAbout: SIMD3<Float>(0, 0, 1), by: rotationAngle) *
                                    float4x4(translateBy: pivotPosition) *
                                    blubBaseTransform
            }
        }
    }
}
