//
//  Shaders.metal
//  metalapp
//
//  Created by 세차오 루카스 on 1/18/23.
//

// import metal standard library into global namespace
// this is done because the metal lib has many helper math functions for shaders
#include <metal_stdlib>
using namespace metal;

// maps to vertex descriptor
struct VertexIn {
    float3 position     [[attribute(0)]];
    float3 normal       [[attribute(1)]];
    float2 texCoords    [[attribute(2)]];
};

// describes data to be returned from vertex function
// position in clip space, attributed with [[position]] so metal knows what it is
// surface normal in camera "eye" coordinates
// position of vertex in eye coordinates
// texture coordinates
struct VertexOut {
    float4 position [[position]]; // clip space position
    float4 eyeNormal;
    float4 eyePosition;
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelViewMatrix; // transforms vertices of model into camera coordinates
    float4x4 projectionMatrix; // camera
};

// VertexIn - incoming vertex data
// vertexIn is attributed with [[stage_in]] to signify it is built by loading the vertex descriptor
// Uniforms is where the transformation matrices are held
vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    vertexOut.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertexIn.position, 1); // moves vertex position into clip space
    vertexOut.eyeNormal = uniforms.modelViewMatrix * float4(vertexIn.normal, 0); // move normals into eye space
    vertexOut.eyePosition = uniforms.modelViewMatrix * float4(vertexIn.position, 1); // move position into eyespace
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

// fragment shader
fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]]) {
    float3 normal = normalize(fragmentIn.eyeNormal.xyz);
    return float4(abs(normal), 1);
}
