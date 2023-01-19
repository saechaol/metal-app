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
    float3 worldNormal;
    float3 worldPosition;
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelMatrix; // transforms vertices of model into camera coordinates
    float4x4 viewProjectionMatrix; // camera
    float3x3 normalMatrix;
};

// VertexIn - incoming vertex data
// vertexIn is attributed with [[stage_in]] to signify it is built by loading the vertex descriptor
// Uniforms is where the transformation matrices are held
vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vertexOut.worldPosition = worldPosition.xyz;
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

constant float3 ambientIntensity = 0.3;
constant float3 baseColor(1.0, 0, 0);
constant float3 lightPosition(2, 2, 2); // in world space
constant float3 lightColor(1, 1, 1); // white light

// fragment shader
fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]]) {
    // diffuse intensity is the dot product of the surcace normal and light direction
    float3 N = normalize(fragmentIn.worldNormal.xyz);
    float3 L = normalize(lightPosition - fragmentIn.worldPosition.xyz);
    float3 diffuseIntensity = saturate(dot(N, L));
    float3 finalColor = saturate(ambientIntensity + diffuseIntensity) * lightColor * baseColor;
    return float4(finalColor, 1);
}
