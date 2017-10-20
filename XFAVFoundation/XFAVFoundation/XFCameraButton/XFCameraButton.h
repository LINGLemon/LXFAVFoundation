//
//  XFCameraButton.h
//  
//
//  Created by xf-ling on 2017/6/1.
//  Copyright © 2017年 LXF. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^TapEventBlock)(UITapGestureRecognizer *tapGestureRecognizer);
typedef void(^LongPressEventBlock)(UILongPressGestureRecognizer *longPressGestureRecognizer);

@interface XFCameraButton : UIView

/**
 *  设置进度条的录制视频时长百分比 = 当前录制时间 / 最大录制时间
 */
@property (nonatomic, assign) CGFloat progressPercentage;

+ (instancetype)defaultCameraButton;

/**
 *  配置点击事件
 */
- (void)configureTapCameraButtonEventWithBlock:(TapEventBlock)tapEventBlock;

/**
 *  配置按压事件
 */
- (void)configureLongPressCameraButtonEventWithBlock:(LongPressEventBlock)longPressEventBlock;

/**
 *  开始录制前的准备动画
 */
- (void)startShootAnimationWithDuration:(NSTimeInterval)duration;

/**
 *  结束摄影动画
 */
- (void)stopShootAnimation;

@end
