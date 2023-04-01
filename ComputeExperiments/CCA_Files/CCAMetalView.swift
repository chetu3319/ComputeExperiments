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


class CCAViewModel: ObservableObject {
    
    @Published var nStates:Int = 2
    @Published var range:Int = 10
    @Published var threshold:Int = 18
    
    var resolution:Int = 1024;
    var counter:UInt32 = 0
    var readTex:MTLTexture!, writeTex:MTLTexture!
    
    private var resetPipelineState:MTLComputePipelineState!
    private var ccaStepFunctionPipleState:MTLComputePipelineState!
    
    public let device:MTLDevice!
    private let commandQueue: MTLCommandQueue!
    public var view:MTKView!
    
    init()
    {
        device = MTLCreateSystemDefaultDevice();
        commandQueue = device.makeCommandQueue();
        
        SetupPipelineStates()
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


struct CCAMetalView:UIViewRepresentable{
   
    public let ccaMetalView = MTKView()
    public var coordinate:Coordinator!
    @ObservedObject var viewModel: CCAViewModel
    
    func makeUIView(context: Context) -> MTKView {
       
        ccaMetalView.autoResizeDrawable = false;
        ccaMetalView.drawableSize = CGSize(width: 1024, height: 1024)
        
        viewModel.view = ccaMetalView;
        ccaMetalView.delegate = context.coordinator
        ccaMetalView.device = viewModel.device;
//        ccaMetalView.device = context.coordinator.device
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
 
//        var device:MTLDevice!
//        var commandQueue:MTLCommandQueue!
//
//        var resetPipelineState:MTLComputePipelineState!
//        var ccaStepFunctionPipleState:MTLComputePipelineState!
//
       
        
        var nStates:UInt = 2
        var range:UInt = 10
        var threshold:UInt = 18
        
        let resolution:Int = 1024;
        
        var counter:UInt32 = 0;
        
//        var readTex:MTLTexture!, writeTex:MTLTexture!
//
//        var textureSampler:MTLSamplerState!
        
        init(_ parent: CCAMetalView, uiView: MTKView) {
            
            print("initializing coordinator")
            print(counter);
            self.parent = parent
            self.uiView = uiView
            
            super.init()
//            setupMetal()
//            parent.viewModel.SetupPipelineStates(device: device)
//            parent.viewModel.resetKernel(commandQueue: commandQueue);
//            setupPipeline()
//            resetKernel();
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
           
            parent.viewModel.resetKernel()
        }
        
        func draw(in view: MTKView) {
           
            if(counter % 1 == 0)
            {
                parent.viewModel.CCAStepKernel(drawable: view.currentDrawable!);
//                CCASetpKernel(in: view)
//                print(counter)
//                swapTextures()
            }
//            counter+=1;
  
            
        }
        
//        func setupMetal()
//        {
//            device = MTLCreateSystemDefaultDevice();
//            commandQueue = device.makeCommandQueue();
//        }
        
//        func setupPipeline()
//        {
//            let library = device.makeDefaultLibrary();
//
//            let constantValues = MTLFunctionConstantValues()
//
//            constantValues.setConstantValue(&self.nStates, type: .uint, index: 0)
//            constantValues.setConstantValue(&self.range, type: .uint, index: 1)
//            constantValues.setConstantValue(&self.threshold, type: .uint, index: 2)
//
//
//            do
//            {
//                let resetFunction = try library?.makeFunction(name: "ResetKernel",constantValues: constantValues)
//                let ccaStepFunction = try library?.makeFunction(name: "CCAStepKernel", constantValues: constantValues)
//                resetPipelineState = try device.makeComputePipelineState(function: resetFunction!);
//                ccaStepFunctionPipleState = try device.makeComputePipelineState(function: ccaStepFunction!);
//            }
//            catch
//            {
//                print("Failed to create compute pipeline state: \(error)")
//            }
//        }
//
//        func resetKernel()
//        {
//            guard let commandBuffer = commandQueue.makeCommandBuffer(),
//                  let resetComputCommandEncoder = commandBuffer.makeComputeCommandEncoder()
//                  else {return}
//
//
//            self.initTextures(view:self.uiView!)
//
//            // Define the size of the thread groups and the number of thread groups
//            let threadGroupSize = MTLSize(width: 32, height:16, depth: 1)
//            let threadGroupCount = MTLSize(width: (resolution + threadGroupSize.width - 1) / threadGroupSize.width,
//                                           height: (resolution + threadGroupSize.height - 1) / threadGroupSize.height,
//                                           depth: 1)
//
//            resetComputCommandEncoder.setTexture(writeTex, index: 0)
//            resetComputCommandEncoder.setComputePipelineState(resetPipelineState);
//            resetComputCommandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
//
//
//
//            resetComputCommandEncoder.endEncoding()
//
//
//            commandBuffer.commit()
//
//            commandBuffer.waitUntilCompleted()
//
//            swapTextures()
//
//
//        }
        
//        public func CCASetpKernel(in view:MTKView)
//        {
//
//
//            guard let commandBuffer = commandQueue.makeCommandBuffer(),
//                  let ccaStepComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder(),
//                  let drawable = view.currentDrawable else {return}
//
//            // Define the size of the thread groups and the number of thread groups
//            let threadGroupSize = MTLSize(width: 32, height: 16, depth: 1)
//            let threadGroupCount = MTLSize(width: (drawable.texture.width + threadGroupSize.width - 1) / threadGroupSize.width,
//                                           height: (drawable.texture.height + threadGroupSize.height - 1) / threadGroupSize.height,
//                                           depth: 1)
//
//
//            ccaStepComputeCommandEncoder.setComputePipelineState(ccaStepFunctionPipleState);
//            ccaStepComputeCommandEncoder.setTexture(readTex, index: 0)
//            ccaStepComputeCommandEncoder.setTexture(writeTex, index: 1)
//            ccaStepComputeCommandEncoder.setTexture(drawable.texture, index: 2)
//
//            ccaStepComputeCommandEncoder.dispatchThreadgroups(threadGroupCount, threadsPerThreadgroup: threadGroupSize)
//            ccaStepComputeCommandEncoder.endEncoding();
//
//            commandBuffer.present(drawable)
//            commandBuffer.commit()
//
//            commandBuffer.waitUntilCompleted()
//
//            swapTextures()
//
//            counter += 1
//            print(counter)
//
//        }
        
//        func initTextures(view:MTKView)
//        {
//
//            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float,
//                                                                             width: Int(resolution),
//                                                                             height: Int(resolution),
//                                                                             mipmapped: false)
//            textureDescriptor.usage = [.shaderRead, .shaderWrite]
//            readTex = device.makeTexture(descriptor: textureDescriptor)
//            writeTex = device.makeTexture(descriptor: textureDescriptor)
//
//        }
        
//        func swapTextures()
//        {
//            let temp = readTex
//            readTex = writeTex
//            writeTex = temp
//        }
        
//        public func RandomizeInit()
//        {
//
//
//            // Randomize nStates,ranges,threshold within a range
//            nStates = UInt.random(in: 2...10)
//            range = UInt.random(in: 2...10)
//            threshold = UInt.random(in: 2...30)
//
//            print("nStates: \(nStates), range: \(range), threshold: \(threshold)")
//
//            setupPipeline()
//            resetKernel()
//            counter += 1;
//            print("counter: \(counter)")
//        }
        

    }
    
    
}



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

