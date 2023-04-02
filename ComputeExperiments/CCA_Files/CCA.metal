//
//  CCA.metal
//  ComputeShaderExperiments
//
//  Created by Chait Shah on 3/25/23.
//

#include <metal_stdlib>
using namespace metal;

constant uint nStates[[function_constant(0)]];
constant uint range[[function_constant(1)]];
constant uint threshold[[function_constant(2)]];



// This function generates a random noise based on the input position
float2 Random(float2 position)
{
    // Use the position to generate a random float3
    float3 randomFloat3 = fract(position.xyx * float3(123.32,234.43,345.65));
    // Add the dot product of the randomFloat3 and itself plus 35.45
    randomFloat3 += dot(randomFloat3, randomFloat3 + 34.45);
    // Return the fractional part of the product of the x, y, and z components of the randomFloat3
    return fract(float(randomFloat3.x * randomFloat3.y * randomFloat3.z)); 
}

kernel void ResetKernel(uint2 gridPos [[thread_position_in_grid]],
                        uint2 threadGroup [[threadgroup_position_in_grid]],
                        texture2d<float,access::write> writeTex[[texture(0)]])
{

    // if the threadgroup value is 0,0 then set it to 1 else set it to 0
    writeTex.write( (uint)((Random(float2(gridPos.xy) * 0.1).x) * nStates), gridPos);
    
}

float4 hsb2rgb(float3 c) {
    float3 rgb = c.x * 6.0;
    float3 temp = float3(0.0, 4.0, 2.0);
    float3 mod = rgb + fract(temp/6);
    float3 absVal = abs(mod - 3.0) - 1.0;
    rgb = clamp(absVal, 0.0, 1.0);
    
    rgb = rgb * rgb * (3.0 - 2.0 * rgb);
    float3 o = c.z * mix(float3(1.0, 1.0, 1.0), rgb, c.y);
    return float4(o.r, o.g, o.b, 1);
}




// This function returns a color based on the input state
float4 Color(uint state, int count, float4 texCol) {
   
    // Calculate the saturation level by dividing the state with the total number of states
    float hueLevel = float(state) / float(nStates);

    float normalizedState = float(state) / float(nStates);
    float normalizedCount = count / float(threshold);

    float3 hsb = float3(0.5, 0.9, 1.);
    
    texCol *= 0.8;
    hsb.x = hsb.y = hsb.z = normalizedCount;

    hsb.y += 0.7;
    hsb.x = mix(hsb.x, 0.3, 0.7);
    texCol += hsb2rgb(hsb);
 
    
    return texCol;

}


constexpr sampler textureSampler(coord::normalized,
                                 address::repeat,
                                 filter::nearest);

kernel void CCAStepKernel(uint2 gridPosition [[thread_position_in_grid]],
                          texture2d<float> readTex [[texture(0)]],
                          texture2d<float,access::write> writeTex [[texture(1)]],
                          texture2d<float, access::read_write> outputTex [[texture(2)]])
{
    
    float width = readTex.get_width();
    float height = readTex.get_height();
    
    uint stateValue = readTex.read(gridPosition).x;
    uint nextStateValue = stateValue + 1 == nStates ? 0: stateValue + 1; // Preserve higher States

     uint count = 0;
     for (int i = -(int)range; i <(int)range + 1; i++) {
         for (int j = -(int)range; j <(int)range + 1; j++) {

             // ignore self
             if (i == 0 && j == 0) {
                 continue;
             }

             // TODO: Use this condition for moore or neu window
             if (i == 0 || j == 0)
             {
                 float2 samplePos = (float2)gridPosition + float2(i,j);
                 samplePos /= float2(width,height);

                 uint sampleValue = (uint) readTex.sample(textureSampler, samplePos).x;
                 if(sampleValue == nextStateValue)
                 {
                     count +=1;
                 }
             }
         }
     }
    
    stateValue = count >= threshold ? abs((stateValue + 1)%nStates) : stateValue;


    // write the sampled grid position
    writeTex.write(stateValue, gridPosition);

    float4 color = Color(stateValue, count,outputTex.read(gridPosition));
    outputTex.write(color, gridPosition);
}
