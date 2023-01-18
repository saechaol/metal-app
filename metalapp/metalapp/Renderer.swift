//
//  Renderer.swift
//  metalapp
//
//  Created by 세차오 루카스 on 1/18/23.
//

import Foundation
import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    
    // called when view changes size
    // this lets us update resolution dependent properties like projection matrix
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    // redraws contents of view
    func draw(in view: MTKView) {
        
    }
    
    let device: MTLDevice
    let mtkView: MTKView
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        super.init()
    }
}
