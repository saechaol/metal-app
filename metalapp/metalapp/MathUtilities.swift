//
//  MathUtilities.swift
//  metalapp
//
//  Created by 세차오 루카스 on 1/18/23.
//

import Foundation
import simd

extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

extension float4x4 {
    init(scaleBy s: Float) {
        self.init(
            SIMD4<Float>(s, 0, 0, 0),
            SIMD4<Float>(0, s, 0, 0),
            SIMD4<Float>(0, 0, s, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
    }
    
    init(rotateAbout axis: SIMD3<Float>, by angleRadians: Float) {
        let x = axis.x, y = axis.y, z = axis.z
        let c = cosf(angleRadians)
        let s = sinf(angleRadians)
        let t = 1 - c
        self.init(
            SIMD4<Float>( t * x * x + c,      t * x * y + z * s,      t * x * z - y * s, 0),
            SIMD4<Float>( t * x * y - z * s,  t * y * y + c,          t * y * z + x * s, 0),
            SIMD4<Float>( t * x * z + y * s,  t * y * z - x * s,      t * z * z + c, 0),
            SIMD4<Float>(                 0,                  0,                  0, 1)
        )
    }
    
    init(translateBy t: SIMD3<Float>) {
        self.init(
            SIMD4<Float>( 1,  0,  0,  0),
            SIMD4<Float>( 0,  1,  0,  0),
            SIMD4<Float>( 0,  0,  1,  0),
            SIMD4<Float>(t[0], t[1], t[2], 1)
        )
    }
    
    init(perspectiveProjectionMatrix fovRadians: Float, aspectRatio aspect: Float, nearZ: Float, farZ: Float) {
        let yScale = 1 / tan(fovRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = farZ - nearZ
        let zScale = -(farZ + nearZ) / zRange
        let wzScale = -2 * farZ * nearZ / zRange
        
        let xx = xScale
        let yy = yScale
        let zz = zScale
        let zw = Float(-1)
        let wz = wzScale
        
        self.init(
            SIMD4<Float>(xx, 0, 0, 0),
            SIMD4<Float>(0, yy, 0, 0),
            SIMD4<Float>(0, 0, zz, zw),
            SIMD4<Float>(0, 0, wz, 1)
        )
    }
    
    var normalMatrix: float3x3 {
        let upperLeft = float3x3(self[0].xyz, self[1].xyz, self[2].xyz)
        return upperLeft.transpose.inverse
    }
}
