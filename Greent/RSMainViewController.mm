//
//  RSMainViewController.m
//  Greent
//
//  Created by R0CKSTAR on 11/20/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSMainViewController.h"

#import "RSGLView.h"

#import <opencv2/highgui/cap_ios.h>

using namespace cv;

// Uniform index.
enum {
    UNIFORM_VIDEOFRAME,
	UNIFORM_INPUTCOLOR,
	UNIFORM_THRESHOLD,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

@interface RSMainViewController () <CvVideoCameraDelegate>
{
    GLuint _directDisplayProgram;
    GLuint _videoFrameTexture;
    
    Mat camFrameTex, camFrameDstROI;
}

@property (nonatomic, strong) RSGLView *glView;

@property (nonatomic, strong) CvVideoCamera *camera;



@end

@implementation RSMainViewController

#pragma mark -
#pragma mark OpenGL ES 2.0 setup methods

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
    uniforms[UNIFORM_INPUTCOLOR] = glGetUniformLocation(*programPointer, "inputColor");
    uniforms[UNIFORM_THRESHOLD] = glGetUniformLocation(*programPointer, "threshold");
    
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
    if (!source)
    {
        NSLog(@"Failed to load vertex shader");
        return FALSE;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        glDeleteShader(*shader);
        return FALSE;
    }
    
    return TRUE;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0)
        return FALSE;
    
    return TRUE;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.glView = [[RSGLView alloc] initWithFrame:self.view.bounds];
    self.glView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.glView];
    
    // Start capturing from camera
    self.camera = [[CvVideoCamera alloc] init];
    self.camera.delegate = self;
    self.camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self.camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.camera.defaultFPS = 30;
    self.camera.grayscaleMode = NO;
    
    [self loadVertexShader:@"Shader" fragmentShader:@"Shader" forProgram:&_directDisplayProgram];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.camera start];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.camera stop];
}

- (void)processImage:(cv::Mat &)image
{

    dispatch_async(dispatch_get_main_queue(), ^{
        if (camFrameTex.empty()) {
            // Create background image with the full texture size, but with a ROI to copy only the rectangle containing the frame
            camFrameTex.create(568, 320, CV_8UC4);
            camFrameDstROI = camFrameTex(cv::Rect(0, 0, 320, 568));
        }
        // Copy the camera frame to the background image
        Mat camFrameSrcROI = image(cv::Rect((image.cols - camFrameDstROI.cols) / 2, (image.rows - camFrameDstROI.rows) / 2, camFrameDstROI.cols, camFrameDstROI.rows));
        camFrameSrcROI.copyTo(camFrameDstROI);
        
        // Create a new texture from the camera frame data, display that using the shaders
        glGenTextures(1, &_videoFrameTexture);
        glBindTexture(GL_TEXTURE_2D, _videoFrameTexture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        // This is necessary for non-power-of-two textures
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // Using BGRA extension to pull in video frame data directly
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 320, 568, 0, GL_BGRA, GL_UNSIGNED_BYTE, camFrameTex.data);
        
        //    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, bgTexWidth, bgTexHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, camFrameTex.data);
        [self drawFrame];
        
        	glDeleteTextures(1, &_videoFrameTexture);
    });
	
	

}

#pragma mark -
#pragma mark OpenGL ES 2.0 rendering methods

- (void)drawFrame
{
    // Replace the implementation of this method to do your own custom drawing.
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
    
    /*	static const GLfloat passthroughTextureVertices[] = {
     0.0f, 0.0f,
     1.0f, 0.0f,
     0.0f,  1.0f,
     1.0f,  1.0f,
     };
     */
        glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    
	// Use shader program.
    [_glView setDisplayFramebuffer];
    glUseProgram(_directDisplayProgram);
    
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, _videoFrameTexture);
	
	// Update uniform values
	glUniform1i(uniforms[UNIFORM_VIDEOFRAME], 0);
//	glUniform4f(uniforms[UNIFORM_INPUTCOLOR], thresholdColor[0], thresholdColor[1], thresholdColor[2], 1.0f);
//	glUniform1f(uniforms[UNIFORM_THRESHOLD], thresholdSensitivity);
    
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0, textureVertices);
	glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
	
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [_glView presentFramebuffer];
}

@end
