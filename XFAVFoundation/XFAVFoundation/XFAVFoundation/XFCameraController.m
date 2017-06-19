//
//  XFCameraController.m
//  
//
//  Created by xf-ling on 2017/6/1.
//  Copyright © 2017年 LXF. All rights reserved.
//

#import "XFCameraController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "XFCameraButton.h"
#import "RAFileManager.h"
#import "XFPhotoLibraryManager.h"
#import <Photos/Photos.h>

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define TIMER_INTERVAL 0.01f                                        //定时器记录视频间隔
#define VIDEO_RECORDER_MAX_TIME 10.0f                               //视频最大时长 (单位/秒)
#define VIDEO_RECORDER_MIN_TIME 1.0f                                //最短视频时长 (单位/秒)
#define START_VIDEO_ANIMATION_DURATION 0.3f                         //录制视频前的动画时间

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface XFCameraController() <AVCaptureFileOutputRecordingDelegate, UIGestureRecognizerDelegate>

@property (nonatomic) dispatch_queue_t sessionQueue;

@property (strong, nonatomic) AVCaptureSession *captureSession;                          //负责输入和输出设备之间的数据传递

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;                          //视频输入
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;                          //声音输入

@property (strong, nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;        //照片输出流
@property(nonatomic,strong) AVCaptureMovieFileOutput *movieFileOutput;                   //视频输出流

@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;      //预览图层

@property (nonatomic, strong) NSTimer *timer;                                            //记录录制时间

@property (weak, nonatomic) IBOutlet UIView *viewContainer;
@property (weak, nonatomic) IBOutlet UIButton *rotateCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *takeButton;                               //拍摄按钮
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UILabel *tipLabel;
@property (strong, nonatomic) XFCameraButton *cameraButton;                              //拍摄按钮

@property (weak, nonatomic) IBOutlet UIImageView *focusImageView;                        //聚焦视图
@property (assign, nonatomic) Boolean isFocusing;                                        //镜头正在聚焦
@property (assign, nonatomic) Boolean isShooting;                                        //正在拍摄

//捏合缩放摄像头
@property (nonatomic,assign) CGFloat beginGestureScale;                                  //记录开始的缩放比例
@property (nonatomic,assign) CGFloat effectiveScale;                                     //最后的缩放比例

// 拍照摄像后的预览模块
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;
@property (weak, nonatomic) IBOutlet UIButton *confirmButton;
@property (strong, nonatomic) UIImageView *photoPreviewImageView;                        //相片预览ImageView
@property (strong, nonatomic) UIView *videoPreviewContainerView;                         //视频预览View
@property (strong, nonatomic) NSURL *videoURL;                                           //视频文件地址
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;

@end

@implementation XFCameraController{
    
    CGFloat timeLength;             //时间长度
    
}

#pragma mark - 工厂方法

+ (instancetype)defaultCameraController
{
    XFCameraController *cameraController = [[XFCameraController alloc] initWithNibName:@"XFCameraController" bundle:nil];
    
    return cameraController;
}

#pragma mark - 控制器方法

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 隐藏状态栏
    [self prefersStatusBarHidden];
    [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    
    _isFocusing = NO;
    _isShooting = NO;
    _beginGestureScale = 1.0f;
    _effectiveScale = 1.0f;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self initAVCaptureSession];
    
    [self configDefaultUIDisplay];
    
    [self addTapGenstureRecognizerForCamera];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self startSession];
    
    [self setFocusCursorWithPoint:self.viewContainer.center];
    
    [self tipLabelAnimation];
    
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self stopSession];
}

- (void)dealloc
{
    NSLog(@"dealloc");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - 控件方法

/**
 *  关闭当前界面
 */
- (IBAction)closeBtnFunc:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

/**
 *  切换前后摄像头
 */
- (IBAction)rotateCameraBtnFunc:(id)sender
{
    if (_isShooting)
    {
        return;
    }
    
    AVCaptureDevice *currentDevice = [self.videoInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront)
    {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.videoInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput])
    {
        [self.captureSession addInput:toChangeDeviceInput];
        self.videoInput = toChangeDeviceInput;
    }
    
    //提交会话配置
    [self.captureSession commitConfiguration];
    
}

- (IBAction)cancelBtnfunc:(id)sender
{
    [self removePlayerItemNotification];
    
    [self startAnimationGroup];
    
}

/**
 *  确认按钮并返回代理
 */
- (IBAction)confirmBtnFunc:(id)sender
{
    __weak typeof(self) weakSelf = self;
    if (self.photoPreviewImageView)
    {
//        UIImageWriteToSavedPhotosAlbum(self.photoPreviewImageView.image, nil, nil, nil);
        
//        if (self.takePhotosCompletionBlock)
//        {
//            self.takePhotosCompletionBlock(self.photoPreviewImageView.image, nil);
//        }
        
        [XFPhotoLibraryManager savePhotoWithImage:self.photoPreviewImageView.image andAssetCollectionName:nil withCompletion:^(UIImage *image, NSError *error) {
            
            if (self.takePhotosCompletionBlock)
            {
                if (error)
                {
                    NSLog(@"保存照片失败!");
                    weakSelf.takePhotosCompletionBlock(nil, error);
                }
                else
                {
                    NSLog(@"保存照片成功!");
                    weakSelf.takePhotosCompletionBlock(image, nil);
                }
            }
            
        }];
        
        [self startAnimationGroup];
        
    }
    else
    {
        [XFPhotoLibraryManager saveVideoWithVideoUrl:self.videoURL andAssetCollectionName:nil withCompletion:^(NSURL *vedioUrl, NSError *error) {
            
            if (self.shootCompletionBlock)
            {
                if (error)
                {
                    NSLog(@"保存视频失败!");
                    self.shootCompletionBlock(nil, nil, error);
                }
                else
                {
                    NSLog(@"保存视频成功!");
                    // 获取视频的第一帧图片
                    UIImage *image = [weakSelf thumbnailImageRequestWithVideoUrl:vedioUrl andTime:0.01f];
                    
                    //保存到相册
//                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
                    
                    self.shootCompletionBlock(vedioUrl, image, nil);
                }
            }
            
            [self startAnimationGroup];
        }];
        
    }
}

#pragma mark - 私有方法

/**
 *  初始化AVCapture会话
 */
- (void)initAVCaptureSession
{
    //初始化会话
    self.captureSession = [[AVCaptureSession alloc] init];
    
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
    {
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    }
    else if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetHigh])
    {
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    else if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetMedium])
    {
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    
    //1、添加 "视频" 与 "音频" 输入流到session
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (!captureDevice)
    {
        NSLog(@"取得后置摄像头时出现问题.");
        
        return;
    }
    
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error)
    {
        NSLog(@"取得设备输入videoInput对象时出错，错误原因：%@", error);
        
        return;
    }
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if (error)
    {
        NSLog(@"取得设备输入audioInput对象时出错，错误原因：%@", error);
        
        return;
    }
    
    //2、添加图片，movie输出流到session
    self.captureStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{
                                     AVVideoCodecKey:AVVideoCodecJPEG
                                     };
    [_captureStillImageOutput setOutputSettings:outputSettings];        //输出设置
    
    self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    //3、将设备输出添加到会话中
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    
    if ([self.captureSession canAddInput:self.audioInput]) {
        
        [self.captureSession addInput:self.audioInput];
    }
    
    if ([self.captureSession canAddOutput:_captureStillImageOutput])
    {
        [self.captureSession addOutput:_captureStillImageOutput];
    }
    
    if ([self.captureSession canAddOutput:self.movieFileOutput]) {
        
        [self.captureSession addOutput:self.movieFileOutput];
    }
    
    //4、创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    
    CALayer *layer = self.viewContainer.layer;
    
    _captureVideoPreviewLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;           //填充模式
    
    //5、将视频预览层添加到界面中
    [layer addSublayer:_captureVideoPreviewLayer];
    
    //设置静音状态也可播放声音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];

}

/**
 *  开启会话
 */
- (void)startSession
{
    if (![self.captureSession isRunning])
    {
        [self.captureSession startRunning];
    }
}

/**
 *  停止会话
 */
- (void)stopSession
{
    if ([self.captureSession isRunning])
    {
        [self.captureSession stopRunning];
    }
}

/**
 *  开始拍照录像动画组合
 */
- (void)startAnimationGroup
{
    [self configDefaultUIDisplay];
    
    [self setFocusCursorWithPoint:self.viewContainer.center];
    
    [self tipLabelAnimation];
}

/**
 *  配置默认UI信息
 */
- (void)configDefaultUIDisplay
{
    [self.view bringSubviewToFront:self.rotateCameraButton];
    [self.view bringSubviewToFront:self.closeButton];
    [self.rotateCameraButton setHidden:NO];
    [self.closeButton setHidden:NO];
    
    [self.view bringSubviewToFront:self.tipLabel];
    [self.tipLabel setAlpha:0];
    
    [self.cancelButton setHidden:YES];
    [self.confirmButton setHidden:YES];
    if (self.photoPreviewImageView)
    {
        [self.photoPreviewImageView removeFromSuperview];
        self.photoPreviewImageView = nil;
    }
    if (self.videoPreviewContainerView)
    {
        [self.videoPreviewContainerView removeFromSuperview];
        self.videoPreviewContainerView = nil;
        self.videoURL = nil;
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
        self.player = nil;
        self.playerItem = nil;
    }
    
    // 设置拍照按钮
    if (_cameraButton == nil)
    {
        XFCameraButton *cameraButton = [XFCameraButton defaultCameraButton];
        _cameraButton = cameraButton;
        
        [self.view addSubview:cameraButton];
        CGFloat cameraBtnX = (kScreenWidth - cameraButton.bounds.size.width) / 2;
        CGFloat cameraBtnY = kScreenHeight - cameraButton.bounds.size.height - 60;    //距离底部60
        cameraButton.frame = CGRectMake(cameraBtnX, cameraBtnY, cameraButton.bounds.size.width, cameraButton.bounds.size.height);
        [self.view bringSubviewToFront:cameraButton];
        
        // 设置拍照按钮点击事件
        __weak typeof(self) weakSelf = self;
        // 配置拍照方法
        [cameraButton configureTapCameraButtonEventWithBlock:^(UITapGestureRecognizer *tapGestureRecognizer) {
            [weakSelf takePhotos:tapGestureRecognizer];
        }];
        // 配置拍摄方法
        [cameraButton configureLongPressCameraButtonEventWithBlock:^(UILongPressGestureRecognizer *longPressGestureRecognizer) {
            [weakSelf longPressCameraButtonFunc:longPressGestureRecognizer];
        }];
    }
    [self.cameraButton setHidden:NO];
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    // 对焦imageView
    [self.view bringSubviewToFront:self.focusImageView];
    [self.focusImageView setAlpha:0];
    
}

/**
 *  隐藏状态栏
 */
- (BOOL)prefersStatusBarHidden
{
    return YES;//隐藏为YES，显示为NO
}

/**
 *  提示语动画
 */
- (void)tipLabelAnimation
{
    [self.view bringSubviewToFront:self.tipLabel];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:1.0f delay:0.5f options:UIViewAnimationOptionCurveEaseInOut animations:^{
        
        [weakSelf.tipLabel setAlpha:1];
        
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:1.0f delay:3.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            
            [weakSelf.tipLabel setAlpha:0];
            
        } completion:nil];
        
    }];
    
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras)
    {
        if ([camera position] == position)
        {
            [camera lockForConfiguration:nil];
//            [camera setFlashMode:AVCaptureFlashModeOff];      //5s机型会崩溃
            [camera unlockForConfiguration];
            
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange
{
    AVCaptureDevice *captureDevice = [self.videoInput device];
    NSError *error;
    
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error])
    {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }
    else
    {
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

#pragma mark - 拍照功能

/**
 *  拍照方法
 */
- (void)takePhotos:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self requestAuthorizationForVideo];
    
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection = [self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    [captureConnection setVideoScaleAndCropFactor:self.effectiveScale];
    
    //根据连接取得设备输出的数据
    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer)
        {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:imageData];
            
            [self previewPhotoWithImage:image];
        }
    }];
}

/**
 *  预览图片
 */
- (void)previewPhotoWithImage:(UIImage *)image
{
    [self requestAuthorizationForPhotoLibrary];
    
    [self.cameraButton setHidden:YES];
    [self.closeButton setHidden:YES];
    [self.rotateCameraButton setHidden:YES];

    self.photoPreviewImageView = [[UIImageView alloc] initWithImage:image];
    self.photoPreviewImageView.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    
    [self.view addSubview:self.photoPreviewImageView];
    [self.view bringSubviewToFront:self.photoPreviewImageView];
    [self.view bringSubviewToFront:self.cancelButton];
    [self.view bringSubviewToFront:self.confirmButton];
    [self.cancelButton setHidden:NO];
    [self.confirmButton setHidden:NO];
}

#pragma mark - 视频录制

/**
 *  录制视频方法
 */
- (void)longPressCameraButtonFunc:(UILongPressGestureRecognizer *)sender
{
    [self requestAuthorizationForVideo];
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied)
    {
        return;
    }
    
    //判断用户是否允许访问麦克风权限
    authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied)
    {
        return;
    }
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            [self startVideoRecorder];
            break;
        case UIGestureRecognizerStateCancelled:
            [self stopVideoRecorder];
            break;
        case UIGestureRecognizerStateEnded:
            [self stopVideoRecorder];
            break;
        case UIGestureRecognizerStateFailed:
            [self stopVideoRecorder];
            break;
        default:
            break;
    }
    
}

/**
 *  开始录制视频
 */
- (void)startVideoRecorder
{
    _isShooting = YES;
    
    [self setCaptureVideoPreviewLayerTransformWithScale:1.0f];
    
    [self.cameraButton startShootAnimationWithDuration:START_VIDEO_ANIMATION_DURATION];
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(START_VIDEO_ANIMATION_DURATION * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        AVCaptureConnection *movieConnection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        
        CGFloat videoMaxScaleAndCropFactor = [[self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        
        NSLog(@"%f", videoMaxScaleAndCropFactor);
        if (self.effectiveScale > videoMaxScaleAndCropFactor)
        {
            self.effectiveScale = videoMaxScaleAndCropFactor;
        }
        
        [movieConnection setVideoScaleAndCropFactor:self.effectiveScale];
        
        AVCaptureVideoOrientation avcaptureOrientation = AVCaptureVideoOrientationPortrait;
        [movieConnection setVideoOrientation:avcaptureOrientation];
        [movieConnection setVideoScaleAndCropFactor:1.0];
        
        NSURL *url = [[RAFileManager defaultManager] filePathUrlWithUrl:[self getVideoSaveFilePathString]];
        
        [weakSelf.movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
        [weakSelf timerFired];
        
    });
}

/**
 *  结束录制视频
 */
- (void)stopVideoRecorder
{
    self.cameraButton.progressPercentage = 0.0f;
    [self.cameraButton stopShootAnimation];
    _isShooting = NO;
    
    [self.movieFileOutput stopRecording];
    
    [self timerStop];
}

- (NSString*)getVideoSaveFilePathString
{
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString* nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    return nowTimeStr;
}

/**
 *  开启定时器
 */
- (void)timerFired
{
    timeLength = 0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(timerRecord) userInfo:nil repeats:YES];
}

/**
 *  绿色转圈百分比计算
 */
- (void)timerRecord
{
    timeLength += TIMER_INTERVAL;
    
//    NSLog(@"%lf", timeLength / VIDEO_RECORDER_MAX_TIME);
    
    self.cameraButton.progressPercentage = timeLength / VIDEO_RECORDER_MAX_TIME;
    
    // 时间大于VIDEO_RECORDER_MAX_TIME则停止录制
    if (timeLength > VIDEO_RECORDER_MAX_TIME)
    {
        [self stopVideoRecorder];
    }
}

/**
 *  停止定时器
 */
- (void)timerStop
{
    if ([self.timer isValid])
    {
        [self.timer invalidate];
        self.timer = nil;
    }
}

/**
 *  预览录制的视频
 */
- (void)previewVideoAfterShoot
{
    [self requestAuthorizationForPhotoLibrary];
    
    if (self.videoURL == nil)
    {
        return;
    }
    
    // 初始化AVPlayer
    self.videoPreviewContainerView = [[UIView alloc] init];
    self.videoPreviewContainerView.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
    
    AVURLAsset *asset = [AVURLAsset assetWithURL:self.videoURL];
    self.playerItem = [AVPlayerItem playerItemWithAsset: asset];
    self.player = [[AVPlayer alloc]initWithPlayerItem:_playerItem];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
//    playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.videoPreviewContainerView.layer addSublayer:self.playerLayer];
    
    // 其余UI布局设置
    [self.view addSubview:self.videoPreviewContainerView];
    [self.view bringSubviewToFront:self.videoPreviewContainerView];
    [self.view bringSubviewToFront:self.cancelButton];
    [self.view bringSubviewToFront:self.confirmButton];
    [self.cameraButton setHidden:YES];
    [self.closeButton setHidden:YES];
    [self.rotateCameraButton setHidden:YES];
    [self.cancelButton setHidden:NO];
    [self.confirmButton setHidden:NO];
    
    // 重复播放预览视频
    [self addNotificationWithPlayerItem];
    
    // 开始播放
    [self.player play];
}

/**
 *  截取指定时间的视频缩略图
 *
 *  @param timeBySecond 时间点，单位：s
 */
- (UIImage *)thumbnailImageRequestWithVideoUrl:(NSURL *)videoUrl andTime:(CGFloat)timeBySecond
{
    if (self.videoURL == nil)
    {
        return nil;
    }
    
    AVURLAsset *urlAsset = [AVURLAsset assetWithURL:videoUrl];
    
    //根据AVURLAsset创建AVAssetImageGenerator
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlAsset];
    /*截图
     * requestTime:缩略图创建时间
     * actualTime:缩略图实际生成的时间
     */
    NSError *error = nil;
    CMTime requestTime = CMTimeMakeWithSeconds(timeBySecond, 10); //CMTime是表示电影时间信息的结构体，第一个参数表示是视频第几秒，第二个参数表示每秒帧数.(如果要活的某一秒的第几帧可以使用CMTimeMake方法)
    CMTime actualTime;
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:requestTime actualTime:&actualTime error:&error];
    if(error)
    {
        NSLog(@"截取视频缩略图时发生错误，错误信息：%@", error.localizedDescription);
        return nil;
    }
    
    CMTimeShow(actualTime);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    UIImage *finalImage = [self rotateImage:image withOrientation:UIImageOrientationRight];
    
    return finalImage;
}

/**
 *  图片旋转
 */
- (UIImage *)rotateImage:(UIImage *)image withOrientation:(UIImageOrientation)orientation
{
    long double rotate = 0.0;
    CGRect rect;
    float translateX = 0;
    float translateY = 0;
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    switch (orientation)
    {
        case UIImageOrientationLeft:
            rotate = M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = 0;
            translateY = -rect.size.width;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationRight:
            rotate = 3 * M_PI_2;
            rect = CGRectMake(0, 0, image.size.height, image.size.width);
            translateX = -rect.size.height;
            translateY = 0;
            scaleY = rect.size.width/rect.size.height;
            scaleX = rect.size.height/rect.size.width;
            break;
        case UIImageOrientationDown:
            rotate = M_PI;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = -rect.size.width;
            translateY = -rect.size.height;
            break;
        default:
            rotate = 0.0;
            rect = CGRectMake(0, 0, image.size.width, image.size.height);
            translateX = 0;
            translateY = 0;
            break;
    }
    
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    //做CTM变换
    CGContextTranslateCTM(context, 0.0, rect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextRotateCTM(context, rotate);
    CGContextTranslateCTM(context, translateX, translateY);
    
    CGContextScaleCTM(context, scaleX, scaleY);
    //绘制图片
    CGContextDrawImage(context, CGRectMake(0, 0, rect.size.width, rect.size.height), image.CGImage);
    
    UIImage *newPic = UIGraphicsGetImageFromCurrentImageContext();
    
    return newPic;
}

#pragma mark - 预览视频通知
/**
 *  添加播放器通知
 */
-(void)addNotificationWithPlayerItem
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playVideoFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.playerItem];
}

-(void)removePlayerItemNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 *  播放完成通知
 *
 *  @param notification 通知对象
 */
-(void)playVideoFinished:(NSNotification *)notification
{
//    NSLog(@"视频播放完成.");
    
    // 播放完成后重复播放
    // 跳到最新的时间点开始播放
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player play];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    // 录制视频时间过短则返回
//    if (CMTimeGetSeconds(captureOutput.recordedDuration) < VIDEO_RECORDER_MIN_TIME)
//    {
//        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"视频时间过短" message:nil preferredStyle:UIAlertControllerStyleAlert];
//        
//        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//            
//        }];
//        
//        [alertController addAction:confirmAction];
//        
//        [self presentViewController:alertController animated:YES completion:^{
//            
//        }];
//        
//        return;
//    }
    
    NSLog(@"%s-- url = %@, recode = %f, int %lld kb", __func__, outputFileURL, CMTimeGetSeconds(captureOutput.recordedDuration), captureOutput.recordedFileSize / 1024);
    
    self.videoURL = outputFileURL;
    [self previewVideoAfterShoot];
    
}

#pragma mark - 摄像头聚焦，与缩放

/**
 *  添加点按手势
 */
- (void)addTapGenstureRecognizerForCamera
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapScreen:)];
    
    [self.viewContainer addGestureRecognizer:tapGesture];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    
    pinchGesture.delegate = self;
    
    [self.viewContainer addGestureRecognizer:pinchGesture];
}

/**
 *  点击屏幕，聚焦事件
 */
- (void)tapScreen:(UITapGestureRecognizer *)tapGesture
{
    if (_isFocusing)
    {
        return;
    }
    
    CGPoint point = [tapGesture locationInView:self.viewContainer];
    
    if (point.y > CGRectGetMaxY(self.tipLabel.frame))
    {
        return;
    }
    
    [self setFocusCursorWithPoint:point];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point
{
    self.isFocusing = YES;
    
    self.focusImageView.center = point;
    self.focusImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
    self.focusImageView.alpha = 1;
    
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint = [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:1.0 animations:^{
        
        weakSelf.focusImageView.transform = CGAffineTransformIdentity;
        
    } completion:^(BOOL finished) {
        
        weakSelf.focusImageView.alpha = 0;
        weakSelf.isFocusing = NO;
        
    }];
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point
{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice)
    {
        if ([captureDevice isFocusModeSupported:focusMode])
        {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported])
        {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode])
        {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported])
        {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
    BOOL allTouchesAreOnTheCaptureVideoPreviewLayer = YES;
    
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for ( i = 0; i < numTouches; ++i)
    {
        CGPoint location = [recognizer locationOfTouch:i inView:self.viewContainer];
        CGPoint convertedLocation = [self.captureVideoPreviewLayer convertPoint:location fromLayer:self.captureVideoPreviewLayer.superlayer];
        if (![self.captureVideoPreviewLayer containsPoint:convertedLocation])
        {
            allTouchesAreOnTheCaptureVideoPreviewLayer = NO;
            break;
        }
    }
    
    if (allTouchesAreOnTheCaptureVideoPreviewLayer)
    {
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < 1.0f)
        {
            self.effectiveScale = 1.0f;
        }
        
//        NSLog(@"%f-------------->%f------------recognizerScale%f", self.effectiveScale, self.beginGestureScale, recognizer.scale);
        
        CGFloat imageMaxScaleAndCropFactor = [[self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
        
//        NSLog(@"%f", imageMaxScaleAndCropFactor);
        if (self.effectiveScale > imageMaxScaleAndCropFactor)
        {
            self.effectiveScale = imageMaxScaleAndCropFactor;
        }
        
        [self setCaptureVideoPreviewLayerTransformWithScale:self.effectiveScale];
    }
}

- (void)setCaptureVideoPreviewLayerTransformWithScale:(CGFloat)scale
{
    self.effectiveScale = scale;
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.25f];      //时长最好低于 START_VIDEO_ANIMATION_DURATION
    [self.captureVideoPreviewLayer setAffineTransform:CGAffineTransformMakeScale(scale, scale)];
    [CATransaction commit];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]])
    {
        self.beginGestureScale = self.effectiveScale;
    }
    
    return YES;
}

#pragma mark - 判断是否有权限

/**
 *  请求权限
 */
- (void)requestAuthorizationForVideo
{
    __weak typeof(self) weakSelf = self;
    
    // 请求相机权限
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"请在iPhone的\"设置-隐私-相机\"选项中，允许%@访问你的相机", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"系统设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    // 请求麦克风权限
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthStatus != AVAuthorizationStatusAuthorized)
    {
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"请在iPhone的\"设置-隐私-麦克风\"选项中，允许%@访问你的麦克风", appName];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }];
        
        UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"系统设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                [[UIApplication sharedApplication] openURL:url];
            }
        }];
        
        [alertController addAction:okAction];
        [alertController addAction:setAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    }
    

}

- (void)requestAuthorizationForPhotoLibrary
{
    __weak typeof(self) weakSelf = self;
    
    // 请求照片权限
    [XFPhotoLibraryManager requestALAssetsLibraryAuthorizationWithCompletion:^(Boolean isAuth) {
        
        if (!isAuth)
        {
            NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
            
            NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
            NSString *message = [NSString stringWithFormat:@"请在iPhone的\"设置-隐私-照片\"选项中，允许%@访问你的照片", appName];
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            }];
            
            UIAlertAction *setAction = [UIAlertAction actionWithTitle:@"系统设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                if ([[UIApplication sharedApplication] canOpenURL:url])
                {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }];
            
            [alertController addAction:okAction];
            [alertController addAction:setAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
            
        }
    }];
}

@end














