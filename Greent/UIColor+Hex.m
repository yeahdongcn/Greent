//
//  UIColor+Hex.m
//  Greent
//
//  Created by R0CKSTAR on 8/23/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "UIColor+Hex.h"

@implementation UIColor (Hex)

+ (UIColor *)colorWithARGBHex:(UInt32)hex
{
    int b = hex & 0x000000FF;
    int g = ((hex & 0x0000FF00) >> 8);
    int r = ((hex & 0x00FF0000) >> 16);
    int a = ((hex & 0xFF000000) >> 24);
    
    return [UIColor colorWithRed:r / 255.0f
                           green:g / 255.0f
                            blue:b / 255.0f
                           alpha:a / 255.f];
}

@end
