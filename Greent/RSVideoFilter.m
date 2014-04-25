//
//  RSVideoFilter.m
//  Greent
//
//  Created by R0CKSTAR on 11/27/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSVideoFilter.h"

@implementation RSVideoFilter

// Hardcode the vertex shader for standard filters, but this can be overridden
NSString *const kVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const kFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 
lowp vec3 normalizeColor(lowp vec3 color)
{
    return color / max(dot(color, vec3(1.0/3.0)), 0.001);
}
 
 
 void main()
 {
//     lowp float distance;
//     lowp vec3 green_color = vec3(0.0, 1.0, 0.0);
//     lowp vec4 color = texture2D(inputImageTexture, textureCoordinate);
//     
//     // Compute distance between current pixel color and reference color.
//     distance = distance(normalizeColor(color.rgb),
//                         normalizeColor(green_color));
//     
//     // If color difference is larger than threshold, return black.
//     if (distance > 2.45) {
//         gl_FragColor = color;
//     } else {
//         gl_FragColor = vec4(0.0);
//     }
     
     // lookup the color of the texel corresponding to the fragment being
     // generated while rendering a triangle
     lowp vec4 tempColor = texture2D(inputImageTexture, textureCoordinate);
     
     // Calculate the average intensity of the texel's red and blue components
     lowp float rbAverage = tempColor.r * 0.7 + tempColor.b * 0.7;
     
     // Calculate the difference between the green element intensity and the
     // average of red and blue intensities
     lowp float gDelta = tempColor.g - rbAverage;
     
     // If the green intensity is greater than the average of red and blue
     // intensities, calculate a transparency value in the range 0.0 to 1.0
     // based on how much more intense the green element is
     tempColor.a = 1.0 - smoothstep(0.00, 0.80, gDelta);
     
     // Use the cube of the of the transparency value. That way, a fragment that
     // is partially translucent becomes even more translucent. This sharpens
     // the final result by avoiding almost but not quite opaque fragments that
     // tend to form halos at color boundaries.
     tempColor.a = tempColor.a * tempColor.a * tempColor.a;
     
     if (tempColor.a == 1.0) {
         gl_FragColor = vec4(0.0);
     } else {
         gl_FragColor = vec4(1.0);
     }
 }
 );

- (id)init
{
    self = [super initWithVertexShaderFromString:kVertexShaderString fragmentShaderFromString:kFragmentShaderString];
    if (self) {
        NSLog(@"init complete");
    }
    return self;
}

@end
