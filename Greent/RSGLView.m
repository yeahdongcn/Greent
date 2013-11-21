//
//  RSGLView.m
//  Greent
//
//  Created by R0CKSTAR on 11/20/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSGLView.h"

#define FBO_HEIGHT 480
#define FBO_WIDTH 320

@interface RSGLView () {
    CAEAGLLayer *_eaglLayer;
    EAGLContext *_context;
    
    /* The pixel dimensions of the backbuffer */
	GLint _backingWidth, _backingHeight;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
	GLuint _viewRenderbuffer, _viewFramebuffer;
    
    GLuint _positionRenderTexture;
	GLuint _positionRenderbuffer, _positionFramebuffer;
}

@end

@implementation RSGLView

// Override the class method to return the OpenGL layer, as opposed to the normal CALayer
+ (Class) layerClass {
	return [CAEAGLLayer class];
}

- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer *)self.layer;
    _eaglLayer.opaque = YES;
}

- (void)setupContext {
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)createFramebuffers
{
	glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
    
	// Onscreen framebuffer object
	glGenFramebuffers(1, &_viewFramebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
	
	glGenRenderbuffers(1, &_viewRenderbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
	NSLog(@"Backing width: %d, height: %d", _backingWidth, _backingHeight);
	
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _viewRenderbuffer);
	
	if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
	{
		NSLog(@"Failure with framebuffer generation");
		exit(1);
	}
	
	// Offscreen position framebuffer object
	glGenFramebuffers(1, &_positionFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _positionFramebuffer);
    
	glGenRenderbuffers(1, &_positionRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _positionRenderbuffer);
	
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, FBO_WIDTH, FBO_HEIGHT);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _positionRenderbuffer);
    
    
	// Offscreen position framebuffer texture target
	glGenTextures(1, &_positionRenderTexture);
    glBindTexture(GL_TEXTURE_2D, _positionRenderTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glHint(GL_GENERATE_MIPMAP_HINT, GL_NICEST);
    //	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	//GL_NEAREST_MIPMAP_NEAREST
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, FBO_WIDTH, FBO_HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    //    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, FBO_WIDTH, FBO_HEIGHT, 0, GL_RGBA, GL_FLOAT, 0);
    
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _positionRenderTexture, 0);
    //	NSLog(@"GL error15: %d", glGetError());
	
	
	
	
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE)
	{
		NSLog(@"Incomplete FBO: %d", status);
        exit(1);
    }
}

- (void)destroyFramebuffer;
{
	if (_viewFramebuffer)
	{
		glDeleteFramebuffers(1, &_viewFramebuffer);
		_viewFramebuffer = 0;
	}
	
	if (_viewRenderbuffer)
	{
		glDeleteRenderbuffers(1, &_viewRenderbuffer);
		_viewRenderbuffer = 0;
	}
}

- (void)setDisplayFramebuffer;
{
    if (_context)
    {
        //        [EAGLContext setCurrentContext:context];
        
        if (!_viewFramebuffer)
		{
            [self createFramebuffers];
		}
        
        glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
        
        glViewport(0, 0, _backingWidth, _backingHeight);
    }
}

- (BOOL)presentFramebuffer;
{
    BOOL success = FALSE;
    
    if (_context)
    {
        //      [EAGLContext setCurrentContext:context];
        
        glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
        
        success = [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    
    return success;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayer];
        [self setupContext];
        //        [self setupRenderBuffer];
        //        [self setupFrameBuffer];
        //        [self render];
        [self createFramebuffers];
    }
    return self;
}

@end