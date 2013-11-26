//
//  RSVideoFilterViewController.m
//  Greent
//
//  Created by R0CKSTAR on 11/22/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSVideoFilterViewController.h"

#import "GPUImage.h"

#import "RSCameraRotator.h"

#import "UIColor+Hex.h"

@interface RSVideoFilterViewController ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;

@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;

@property (nonatomic, weak) IBOutlet GPUImageView *filterView;

@property (nonatomic, weak) IBOutlet UIButton *a;

@property (nonatomic, weak) IBOutlet UIButton *b;

@property (nonatomic, weak) IBOutlet UIButton *c;

- (IBAction)aa:(id)sender;

@end

@implementation RSVideoFilterViewController
- (IBAction)aa:(id)sender
{
    [self.videoCamera rotateCamera];
}
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
    
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    self.videoCamera.outputImageOrientation = self.interfaceOrientation;;
    
    self.filter = [[GPUImageFilter alloc] init];
    
    [self.videoCamera addTarget:self.filter];
    [self.filter addTarget:self.filterView];
    
    RSCameraRotator *rotator = [[RSCameraRotator alloc] initWithFrame:CGRectMake(100, 100, 165, 50)];
    rotator.offColor = [UIColor colorWithARGBHex:0xff498e14];
    rotator.onColorLight = [UIColor colorWithARGBHex:0xff9dd32a];
    rotator.onColorDark = [UIColor colorWithARGBHex:0xff66a61b];
    rotator.tintColor = [UIColor blackColor];
    [self.filterView addSubview:rotator];
    
    self.a.alpha = 0.6f;
    self.b.alpha = 0.6f;
    self.c.alpha = 0.6f;
    
    self.filterView.layer.borderWidth = 1;
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

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    self.videoCamera.outputImageOrientation = toInterfaceOrientation;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
