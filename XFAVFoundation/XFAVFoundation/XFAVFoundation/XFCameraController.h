//
//  XFCameraController.h
//  
//
//  Created by xf-ling on 2017/6/1.
//  Copyright © 2017年 LXF. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^TakePhotosCompletionBlock)(UIImage *image, NSError *error);
typedef void(^ShootCompletionBlock)(NSURL *vedioUrl, UIImage *thumbnailImage, NSError *error);

@interface XFCameraController : UIViewController

/**
 *  拍照完成后的Block回调
 */
@property (copy, nonatomic) TakePhotosCompletionBlock takePhotosCompletionBlock;

/**
 *  拍摄完成后的Block回调
 */
@property (copy, nonatomic) ShootCompletionBlock shootCompletionBlock;

+ (instancetype)defaultCameraController;

@end
