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

struct VertexUniforms {
    float4x4 modelMatrix; // transforms vertices of model into camera coordinates
    float4x4 viewProjectionMatrix; // camera
    float3x3 normalMatrix;
};

struct Light {
    float3 worldPosition;
    float3 color;
};

#define LightCount 3
struct FragmentUniforms {
    float3 cameraWorldPosition;
    float3 ambientLightColor;
    float3 specularColor;
    float specularPower;
    Light lights[LightCount];
};

// VertexIn - incoming vertex data
// vertexIn is attributed with [[stage_in]] to signify it is built by loading the vertex descriptor
// Uniforms is where the transformation matrices are held
vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant VertexUniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition;
    vertexOut.worldPosition = worldPosition.xyz;
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal;
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

// fragment shader
fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]], constant FragmentUniforms &uniforms [[buffer(0)]], texture2d<float, access::sample> baseColorTexture [[texture(0)]], sampler baseColorSampler [[sampler(0)]]) {
    // import texture as basecolor
    float3 baseColor = baseColorTexture.sample(baseColorSampler, fragmentIn.texCoords).rgb;
    float3 specularColor = uniforms.specularColor;
    // diffuse intensity is the dot product of the surcace normal and light direction
    float3 N = normalize(fragmentIn.worldNormal.xyz);
    
    float3 V = normalize(uniforms.cameraWorldPosition - fragmentIn.worldPosition.xyz);
    float3 finalColor(0, 0, 0);
    
    for (int i = 0; i < LightCount; ++i) {
        float3 L = normalize(uniforms.lights[i].worldPosition - fragmentIn.worldPosition.xyz);
        float3 diffuseIntensity = saturate(dot(N, L));
        float3 H = normalize(L + V);
        float specularBase = saturate(dot(N, H));
        float specularIntensity = powr(specularBase, uniforms.specularPower);
        float3 lightColor = uniforms.lights[i].color;
        finalColor +=   uniforms.ambientLightColor * baseColor +
                        diffuseIntensity * lightColor * baseColor +
                        specularIntensity * lightColor * specularColor;
    }
    
    return float4(finalColor, 1);
}
