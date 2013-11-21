//
//  RSViewController.m
//  Greent
//
//  Created by R0CKSTAR on 11/20/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSViewController.h"

#import <opencv2/highgui/cap_ios.h>

using namespace cv;

// Uniform index.
enum {
    UNIFORM_VIDEOFRAME,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

@interface RSViewController () <CvVideoCameraDelegate> {
    GLuint _program;
    
    int _textureWidth, _textureHeight;   // Texture dimensions
    int _cameraWidth, _cameraHeight;     // Camera frame dimesions
    int _viewportWidth, _viewportHeight; // Viewport dimensions

    
    GLuint _videoFrameTexture;
    Mat camFrameTex, camFrameDstROI;
    

}

@property (strong, nonatomic) EAGLContext *context;

@property (strong, nonatomic) GLKBaseEffect *effect;

@property (nonatomic, strong) CvVideoCamera *camera;

@property (nonatomic, strong) NSObject *syncLastFrame;

@end

@implementation RSViewController

- (BOOL)loadVertexShader:(NSString *)vertexShaderName fragmentShader:(NSString *)fragmentShaderName forProgram:(GLuint *)programPointer;
{
    GLuint vertexShader, fragShader;
	
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    *programPointer = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:vertexShaderName ofType:@"vsh"];
    if (![self compileShader:&vertexShader type:GL_VERTEX_SHADER file:vertShaderPathname])
    {
        NSLog(@"Failed to compile vertex shader");
        return FALSE;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShaderName ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname])
    {
        NSLog(@"Failed to compile fragment shader");
        return FALSE;
    }
    
    // Attach vertex shader to program.
    glAttachShader(*programPointer, vertexShader);
    
    // Attach fragment shader to program.
    glAttachShader(*programPointer, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(*programPointer, ATTRIB_VERTEX, "position");
    glBindAttribLocation(*programPointer, ATTRIB_TEXTUREPOSITON, "inputTextureCoordinate");
    
    // Link program.
    if (![self linkProgram:*programPointer])
    {
        NSLog(@"Failed to link program: %d", *programPointer);
        
        if (vertexShader)
        {
            glDeleteShader(vertexShader);
            vertexShader = 0;
        }
        if (fragShader)
        {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (*programPointer)
        {
            glDeleteProgram(*programPointer);
            *programPointer = 0;
        }
        
        return FALSE;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_VIDEOFRAME] = glGetUniformLocation(*programPointer, "videoFrame");
    
    // Release vertex and fragment shaders.
    if (vertexShader)
	{
        glDeleteShader(vertexShader);
	}
    if (fragShader)
	{
        glDeleteShader(fragShader);
	}
    
    return TRUE;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.syncLastFrame = [NSObject alloc];
    _viewportWidth = self.view.bounds.size.width * self.view.contentScaleFactor;
    _viewportHeight = self.view.bounds.size.height * self.view.contentScaleFactor;

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(0, 1, 0, 1);
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupCamera];
    
    [self setupGL];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.camera start];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.camera stop];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)setupCamera
{
    // Start capturing from camera
    self.camera = [[CvVideoCamera alloc] init];
    self.camera.delegate = self;
    self.camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.camera.defaultFPS = 30;
    self.camera.grayscaleMode = NO;
    
    [self.camera start];
    
    // Crop one of the camera frame dimensions, so aspect ratio is equal to the viewport's
    _cameraWidth = self.camera.imageHeight; // Swapped dimensions because of portrait mode
    _cameraHeight = self.camera.imageWidth;
    float cameraAspect = _cameraWidth / (float)_cameraHeight;
    float viewportAspect = _viewportWidth / (float)_viewportHeight;
    if (cameraAspect > viewportAspect) {
        // Crop width
        _cameraWidth = _cameraHeight * viewportAspect;
    } else if (cameraAspect < viewportAspect) {
        // Crop height
        _cameraHeight = _cameraWidth / viewportAspect;
    }
    
    // Texture dimensions must be powers of two while larger than the frame dimensions
    _textureWidth = pow(2, ceil(log2(_cameraWidth)));
    _textureHeight = pow(2, ceil(log2(_cameraHeight)));
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadVertexShader:@"Shader" fragmentShader:@"Shader" forProgram:&_program];
    
    glEnable(GL_TEXTURE_2D);
	glDisable(GL_DEPTH_TEST);
    
    glGenTextures(1, &_videoFrameTexture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _videoFrameTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteTextures(1, &_videoFrameTexture);
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

- (void)processImage:(cv::Mat &)image
{
    @synchronized(self.syncLastFrame) {
        if (camFrameTex.empty()) {
            // Create background image with the full texture size, but with a ROI to copy only the rectangle containing the frame
            camFrameTex.create(568, 320, CV_8UC4);
            camFrameDstROI = camFrameTex(cv::Rect(0, 0, 320, 568));
        }
        // Copy the camera frame to the background image
        Mat camFrameSrcROI = image(cv::Rect((image.cols - camFrameDstROI.cols) / 2, (image.rows - camFrameDstROI.rows) / 2, camFrameDstROI.cols, camFrameDstROI.rows));
        camFrameSrcROI.copyTo(camFrameDstROI);
    }
}

- (void)update
{
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };
    
	static const GLfloat textureVertices[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f,  1.0f,
        0.0f,  0.0f,
    };
    
	// Use shader program.
    glUseProgram(_program);
    
    [self.effect prepareToDraw];
    
    
    @synchronized(self.syncLastFrame) {
        if (!camFrameTex.empty()) {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 320, 568, 0, GL_BGRA, GL_UNSIGNED_BYTE, camFrameTex.data);
        }
    }
    
	// Update uniform values
	glUniform1i(uniforms[UNIFORM_VIDEOFRAME], 0);
    
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(ATTRIB_VERTEX); 
	glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureVertices);
	glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
	
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

@end
