//
//  ViewController.swift
//  metalapp
//
//  Created by 세차오 루카스 on 1/18/23.
//

import UIKit
import MetalKit

class ViewController: UIViewController {
    
    var mtkView: MTKView!
    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView() // instantiate MTKView
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mtkView)
        
        // configure with autolayout
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "|[mtkView]|",
            metrics: nil,
            views: ["mtkView": mtkView]))
        
        view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|[mtkView]|",
            metrics: nil,
            views: ["mtkView": mtkView]))
    
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float // uses 32b float per pixel to track distance from camera to nearest fragment seen
        
        renderer = Renderer(view: mtkView, device: device)
        mtkView.delegate = renderer
    }


}

