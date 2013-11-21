//
//  RSGLView.h
//  Greent
//
//  Created by R0CKSTAR on 11/20/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RSGLView : UIView
- (void)createFramebuffers;
- (void)destroyFramebuffer;
- (void)setDisplayFramebuffer;
- (BOOL)presentFramebuffer;
@end
