//
//  RSGreentViewController.m
//  Greent
//
//  Created by R0CKSTAR on 8/21/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSGreentViewController.h"

#import "GPUImage.h"

@interface RSGreentViewController ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;

@end

@implementation RSGreentViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    
    GPUImageFilter *customFilter = [[GPUImageSepiaFilter alloc] init];
    [self.videoCamera addTarget:customFilter];
    
    GPUImageView *filterView = (GPUImageView *)self.view;
    filterView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [customFilter addTarget:filterView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.videoCamera startCameraCapture];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.videoCamera stopCameraCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
