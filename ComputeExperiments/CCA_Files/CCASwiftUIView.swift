//
//  CCASwiftUIView.swift
//  ComputeShaderExperiments
//
//  Created by Chait Shah on 3/25/23.
//

import SwiftUI
import UIKit
import Photos

struct CCASwiftUIView: View {
    @StateObject private var viewModel = CCAViewModel()
    @State private var showingShareSheet = false
    @State private var imageToShare: UIImage?
    
    var body: some View { 
        NavigationView{
            VStack{

                CCAMetalView(viewModel: viewModel)
                    .aspectRatio(contentMode: .fit)
                    .padding(.bottom)



                Divider();

                CCASettingsView(viewModel: viewModel);
            }
            .padding(.top,10)
            .toolbar(content: {
                
            })
            .navigationBarItems(trailing:
                            HStack {
                                Spacer()
                Button(action: {
                    if let cgImage = viewModel.cgImage() {
                                        imageToShare = UIImage(cgImage: cgImage)
                                        showingShareSheet = true
                                    }
                    
                }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .imageScale(.large)
                                }
                            }
                        )
            .sheet(isPresented: $showingShareSheet) {
                            if let image = imageToShare {
                                ShareSheet(items: [image])
                            } else {
                                EmptyView()
                            }
            }
        }
        
       
    }


    func saveImageToPhotosAlbum(_ image: UIImage) {
        // Check if the app has permission to access the photo library
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    self.saveImageToPhotosAlbum(image)
                }
            }
            return
        }
        guard status == .authorized else { return }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if let error = error {
                print("Error saving image to photos album: \(error)")
            } else {
                print("Image successfully saved to photos album")
            }
        }
    }

    }

    struct CCASwiftUIView_Previews: PreviewProvider {
        static var previews: some View {
            CCASwiftUIView()
        }
    }
