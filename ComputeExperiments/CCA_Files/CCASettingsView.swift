//
//  CCASettingsView.swift
//  ComputeExperiments
//
//  Created by Chait Shah on 3/25/23.
//

import SwiftUI

/// A settings screen for a cellular automaton simulation. 
/// Includes three `VariableStepperView` instances and two buttons that modify the `viewModel` object.
struct CCASettingsView: View {
    
    @ObservedObject var viewModel:CCADataModel

    var body: some View {
        
        VStack{
            
            VariableStepperView(stepperVariable: $viewModel.nStates, rangeList: 1...10, valueLabel: "N States: \(viewModel.nStates)")
            
            VariableStepperView(stepperVariable: $viewModel.range, rangeList: 1...10, valueLabel: "Range: \(viewModel.range)")
            
            VariableStepperView(stepperVariable: $viewModel.threshold,  rangeList:1...30, valueLabel: "Threshold: \(viewModel.threshold)")
            
            HStack{
                Button(action: {
                    // Action for first button

                    viewModel.SetupPipelineStates()
                    viewModel.resetKernel()
                    
                }) {
                    Text("Reset")
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Action for second button

                    viewModel.randomizeInit()
                    
                }) {
                    Text("Randomize")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            
        }
        .padding(.horizontal, 20)
        
    }
    
    /// Subview for the specific style of stepper views.
    /// paramenter
    /// - stepper variable binding
    /// - rangeList
    /// - lable for the stepper
    struct VariableStepperView: View {
        
        @Binding var stepperVariable: Int
        public var rangeList:ClosedRange<Int>;
        public var valueLabel:String;
        
        var body: some View {
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(radius: 5)
                    .frame(height: 50)
                Stepper(valueLabel,
                        value: $stepperVariable,
                        in: rangeList)
                    .padding(.horizontal, 40)
            }
        }
    }
}
