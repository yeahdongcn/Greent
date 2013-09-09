//
//  RSBrand.h
//  Greent
//
//  Created by R0CKSTAR on 8/26/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RSBrand : NSObject <NSCoding>

@property (nonatomic, assign) NSUInteger id;
@property (nonatomic, strong) NSString  *name;
@property (nonatomic, strong) NSURL     *logoNormal;
@property (nonatomic, strong) NSURL     *logoSelected;
@property (nonatomic, strong) UIColor   *colorNormal;
@property (nonatomic, strong) UIColor   *colorSelected;

@end
