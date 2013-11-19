//
//  GLViewController.m
//  MotionTest
//
//  Created by uavster on 7/23/13.
//  Copyright (c) 2013 uavster. All rights reserved.
//

#import "RSGreentViewController.h"

#import <opencv2/highgui/cap_ios.h>

using namespace cv;

@interface RSGreentViewController() <CvVideoCameraDelegate>
{
    Mat camFrameTex, camFrameDstROI;
    GLuint bgTex;
    int bgTexWidth, bgTexHeight;    // Background texture dimensions
    int camWidth, camHeight;        // Camera frame dimesions
    int vpWidth, vpHeight;          // Viewport dimensions
}
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CvVideoCamera *camera;
@property (nonatomic, strong) NSObject *syncLastFrame;
@end

@implementation RSGreentViewController

-(void)viewDidLoad {
    static const float fps = 30.0f;
    
    @try {
        
        self.syncLastFrame = [NSObject alloc];
        
        vpWidth = self.view.bounds.size.width * self.view.contentScaleFactor;
        vpHeight = self.view.bounds.size.height * self.view.contentScaleFactor;
        
        // Start capturing from camera
        self.camera = [[CvVideoCamera alloc] init];
        self.camera.delegate = self;
        self.camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
        self.camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
        self.camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
        self.camera.defaultFPS = 30;
        self.camera.grayscaleMode = NO;
        [self.camera start];
        
        // Crop one of the camera frame dimensions, so aspect ratio is equal to the viewport's
        camWidth = self.camera.imageHeight; // Swapped dimensions because of portrait mode
        camHeight = self.camera.imageWidth;
        float camAspect = camWidth / (float)camHeight;
        float vpAspect = vpWidth / (float)vpHeight;
        if (camAspect > vpAspect) {
            // Crop width
            camWidth = camHeight * vpAspect;
        } else if (camAspect < vpAspect) {
            // Crop height
            camHeight = camWidth / vpAspect;
        }
        
        // Background texture dimensions must be powers of two while larger than the frame dimensions
        bgTexWidth = pow(2, ceil(log2(camWidth)));
        bgTexHeight = pow(2, ceil(log2(camHeight)));
        
        // Create GL context
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        if (self.context == nil) @throw [NSException exceptionWithName:@"Load error" reason:@"Failed to create ES context" userInfo:nil];
        
        // Set GL current context
        [EAGLContext setCurrentContext:self.context];
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(0.0, 0.0, 0.0, 1.0);
        
        // Tell the view about the GL context
        GLKView *view = (GLKView *)self.view;
        view.context = self.context;
        
        // Create texture for camera frames
        glEnable(GL_TEXTURE_2D);
        glGenTextures(1, &bgTex);
        glBindTexture(GL_TEXTURE_2D, bgTex);
        glTexImage2D(GL_TEXTURE_2D, 0, 4, bgTexWidth, bgTexHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        
        // GL render configuration
        view.drawableMultisample = GLKViewDrawableMultisampleNone;
        self.preferredFramesPerSecond = fps;
        
    } @catch(NSException *e) {
    }
}

-(void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    static double time = 0;
    time += (double)self.timeSinceLastDraw;
    
    glViewport(0, 0, vpWidth, vpHeight);
    
    // Set image from camera as background
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_CULL_FACE);
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(GLKMatrix4MakeOrtho(0, 1, 1, 0, -1, 1).m);
    glMatrixMode(GL_TEXTURE);
    glLoadIdentity();
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    glDisable(GL_LIGHTING);
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, bgTex);
    @synchronized(self.syncLastFrame) {
        if (!camFrameTex.empty()) {
            // glTexSubImage2D does not work!! Some people reported the same problem, but couldn't find why it happens. Had to use glTexImage2D instead. Tested on iPhone 4S.
            // glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, bgTexWidth, bgTexHeight, GL_RGB, GL_UNSIGNED_BYTE, camFrameTex.data);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bgTexWidth, bgTexHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, camFrameTex.data);
        }
    }
    const static GLfloat backgroundVertices[] = { 0, 0, 1, 0, 1, 1, 0, 1 };
    float maxTexX = camWidth / (float)bgTexWidth;
    float maxTexY = camHeight / (float)bgTexHeight;
    GLfloat backgroundTexCoords[] = { 0, 0, maxTexX, 0, maxTexX, maxTexY, 0, maxTexY };
    const static GLubyte backgroundIndices[] = { 0, 1, 2, 2, 3, 0 };
    glColor4f(1, 1, 1, 1);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, backgroundVertices);
    glTexCoordPointer(2, GL_FLOAT, 0, backgroundTexCoords);
    glDrawElements(GL_TRIANGLES, sizeof(backgroundIndices) / sizeof(backgroundIndices[0]), GL_UNSIGNED_BYTE, backgroundIndices);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
}

-(void)processImage:(cv::Mat &)image {
    @synchronized(self.syncLastFrame) {
        if (camFrameTex.empty()) {
            // Create background image with the full texture size, but with a ROI to copy only the rectangle containing the frame
            camFrameTex.create(bgTexHeight, bgTexWidth, CV_8UC4);
            camFrameDstROI = camFrameTex(cv::Rect(0, 0, camWidth, camHeight));
        }
        // Copy the camera frame to the background image
        Mat camFrameSrcROI = image(cv::Rect((image.cols - camFrameDstROI.cols) / 2, (image.rows - camFrameDstROI.rows) / 2, camFrameDstROI.cols, camFrameDstROI.rows));
        camFrameSrcROI.copyTo(camFrameDstROI);
    }
}

@end
