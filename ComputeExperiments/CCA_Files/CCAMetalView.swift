//
//  CCAMetalView.swift
//  ComputeShaderExperiments
//
//  Created by Chait Shah on 3/25/23.
//

import Foundation
import MetalKit
import Metal
import SwiftUI
import UIKit

// MARK: DATA MODEL FOR CCA
/// Data Model for CCA calculations
class CCADataModel: ObservableObject {
    
    /// Number of states in the simulation of the CCA
    @Published var nStates:Int = 2
    /// Range surrounding the cell to consider
    @Published var range:Int = 10
    /// Threshold number above which the state of the cell will change
    @Published var threshold:Int = 18
    
    let resolution:Int = 1024;
    
    var counter:UInt32 = 0
    var readTex:MTLTexture!, writeTex:MTLTexture!
    
    private var resetPipelineState:MTLComputePipelineState!
    private var ccaStepFunctionPipleState:MTLComputePipelineState!
    
    public let device:MTLDevice!
    private let commandQueue: MTLCommandQueue!
   
    public var view:MTKView!
    
    // MARK: Metal Init
    init()
    {
        // Setup Metal
        device = MTLCreateSystemDefaultDevice();
        commandQueue = device.makeCommandQueue();
        
        // Init pipeline
        SetupPipelineStates()
        
        // CCA Reset Kernel
        resetKernel()
    }
    
    func SetupPipelineStates()
    {
        let library = device.makeDefaultLibrary();
        
        let constantValues = MTLFunctionConstantValues()
        
        constantValues.setConstantValue(&self.nStates, type: .uint, index: 0)
        constantValues.setConstantValue(&self.range, type: .uint, index: 1)
        constantValues.setConstantValue(&self.threshold, type: .uint, index: 2)
     
        
        do
        {
            let resetFunction = try library?.makeFunction(name: "ResetKernel",constantValues: constantValues)
            let ccaStepFunction = try library?.makeFunction(name: "CCAStepKernel", constantValues: constantValues)
            resetPipelineState = try device.makeComputePipelineState(function: resetFunction!);
            ccaStepFunctionPipleState = try device.makeComputePipelineState(function: ccaStepFunction!);
        }
        catch
        {
            print("Failed to create compute pipeline state: \(error)")
        }
    }
    
    // MARK: Metal Compute Programs
    func resetKernel()
    {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let resetComputCommandEncoder = commandBuffer.makeComputeCommandEncoder()
              else {return}


        self.initTextures()

        // Define the size of the thread groups and the number of thread groups
        let threadGroupSize = MTLSize(width: 32, height:16, depth: 1)
        let threadGroupCount = MTLSize(width: (resolution + threadGroupSize.width - 1) / threadGroupSize.width,
                                       height: (resolution + threadGroupSize.height - 1) / threadGroupSize.height,
                                       depth: 1)

        resetComputCommandEncoder.setTexture(writeTex, index: 0)
        resetComputCommandEncoder.setComputePipelineState(resetPipelineState);
        resetComputCommandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        
        
        
        resetComputCommandEncoder.endEncoding()

        
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
        
        swapTextures()
       
        
    }
    
    func CCAStepKernel(drawable: CAMetalDrawable)
    {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let ccaStepComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        else {return}
        
        // Define the size of the thread groups and the number of thread groups
        let threadGroupSize = MTLSize(width: 32, height: 16, depth: 1)
        let threadGroupCount = MTLSize(width: (drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
                                       height: (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
                                       depth: 1)
        
        
        ccaStepComputeCommandEncoder.setComputePipelineState(ccaStepFunctionPipleState);
        ccaStepComputeCommandEncoder.setTexture(readTex, index: 0)
        ccaStepComputeCommandEncoder.setTexture(writeTex, index: 1)
        ccaStepComputeCommandEncoder.setTexture(drawable.texture, index: 2)
      
        ccaStepComputeCommandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
        ccaStepComputeCommandEncoder.endEncoding();
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
        
        swapTextures()
        
        counter += 1
   
    }
    
    
    // MARK: Util functions
    func swapTextures()
    {
        let temp = readTex
        readTex = writeTex
        writeTex = temp
    }
    
    func initTextures()
    {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float,
                                                                         width: Int(resolution),
                                                                         height: Int(resolution),
                                                                         mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        readTex = device.makeTexture(descriptor: textureDescriptor)
        writeTex = device.makeTexture(descriptor: textureDescriptor)
        
        
    }
    
    func randomizeInit()
    {
        nStates = Int.random(in: 2...10)
        range = Int.random(in: 2...10)
        threshold = Int.random(in: 2...30)
        
       
       
        SetupPipelineStates()
        resetKernel()
    }
    
    func cgImage() -> CGImage? {
        
        let texture = view.currentDrawable?.texture
        
        let width = texture!.width
        let height = texture!.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let dataSize = width * height * bytesPerPixel

        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        defer {
            rawData.deallocate()
        }

        let region = MTLRegionMake2D(0, 0, width, height)
        texture!.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)]

        guard let bitmapContext = CGContext(data: rawData,
                                            width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bytesPerRow: bytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo.rawValue) else {
            print("Returning nil")
            return nil }

        print("Making Image"); 
        return bitmapContext.makeImage()
    }
}

// MARK: UIViewRepresentable for MetalView for CCA Simulation
/// UIViewRepresentable for the Metal View
struct CCAMetalView:UIViewRepresentable{
   
    @ObservedObject var ccaDataModel: CCADataModel
    
    public let ccaMetalView = MTKView()
    public var coordinate:Coordinator!
    
    func makeUIView(context: Context) -> MTKView {
       
        ccaMetalView.autoResizeDrawable = false;
        let resolution = ccaDataModel.resolution;
        ccaMetalView.drawableSize = CGSize(width: resolution, height: resolution)
        
        ccaDataModel.view = ccaMetalView;
        ccaMetalView.delegate = context.coordinator
        ccaMetalView.device = ccaDataModel.device;
        ccaMetalView.framebufferOnly = false
        ccaMetalView.layer.magnificationFilter = .linear
    
        return ccaMetalView;
    }
    
    func makeCoordinator() -> Coordinator {
      
        Coordinator(self, uiView: MTKView())
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.uiView = uiView;
    }
    
    class Coordinator: NSObject, MTKViewDelegate{
        var parent:CCAMetalView
        var uiView: MTKView?
        var counter:UInt32 = 0
        
        init(_ parent: CCAMetalView, uiView: MTKView) {
            
            print("initializing coordinator")
            self.parent = parent
            self.uiView = uiView
            
            super.init()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            parent.ccaDataModel.resetKernel()
        }
        
        func draw(in view: MTKView) {
           
            if(counter % 1 == 0)
            {
                parent.ccaDataModel.CCAStepKernel(drawable: view.currentDrawable!)
            }
            counter += 1
        }
    }
    
    
}

// MARK: UIViewRepresentable for ShareSheet
/// UIViewRepresentable for the Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

