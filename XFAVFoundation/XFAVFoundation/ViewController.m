//
//  ViewController.m
//  XFAVFoundation
//
//  Created by xf-ling on 2017/6/19.
//  Copyright © 2017年 LXF. All rights reserved.
//

#import "ViewController.h"
#import "XFCameraController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)videoBtnFunc:(id)sender
{
    XFCameraController *cameraController = [XFCameraController defaultCameraController];
    
    cameraController.takePhotosCompletionBlock = ^(UIImage *image, NSError *error) {
        NSLog(@"takePhotosCompletionBlock");
    };
    
    cameraController.shootCompletionBlock = ^(NSURL *vedioUrl, UIImage *thumbnailImage, NSError *error) {
        NSLog(@"shootCompletionBlock");
    };
    
    [self presentViewController:cameraController animated:YES completion:nil];
    
}

@end
