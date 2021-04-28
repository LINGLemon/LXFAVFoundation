//
//  ViewController.m
//  LXFAVFoundation
//
//  Created by 凌煊峰 on 2021/4/28.
//

#import "ViewController.h"
#import "LXFCameraController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}


- (IBAction)videoBtnFunc:(id)sender
{
    LXFCameraController *cameraController = [LXFCameraController defaultCameraController];
    
    __weak LXFCameraController *weakCameraController = cameraController;
    
    cameraController.takePhotosCompletionBlock = ^(UIImage *image, NSError *error) {
        NSLog(@"takePhotosCompletionBlock");
        
        [weakCameraController dismissViewControllerAnimated:YES completion:nil];
    };
    
    cameraController.shootCompletionBlock = ^(NSURL *videoUrl, CGFloat videoTimeLength, UIImage *thumbnailImage, NSError *error) {
        NSLog(@"shootCompletionBlock");
        
        [weakCameraController dismissViewControllerAnimated:YES completion:nil];
    };
    
    cameraController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:cameraController animated:YES completion:nil];
    
}


@end
