# XFAVFoundation
这是一个模仿微信拍照，摄像，保存照片或视频到自己本地自定义app相册里面的demo，具有快速简易接入项目的接口

博客地址：
http://blog.csdn.net/sinat_31177681/article/details/75252341

1、=====================================================================================================================
上调了帧率和像素，10s的视频2.8m左右
详细参数设置如下：
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.videoURL fileType:AVFileTypeMPEG4 error:nil];
    //写入视频大小
    NSInteger numPixels = kScreenWidth * kScreenHeight;
    //每像素比特
    CGFloat bitsPerPixel = 12.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(15),
                                             AVVideoMaxKeyFrameIntervalKey : @(15),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    
    //视频属性
    self.videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                       AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                       AVVideoWidthKey : @(kScreenHeight * 2),
                                       AVVideoHeightKey : @(kScreenWidth * 2),
                                       AVVideoCompressionPropertiesKey : compressionProperties };
    
    _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:self.videoCompressionSettings];

========================================================================================================================

2、=====================================================================================================================
新增监听屏幕方向，支持各个方向录制，查看录制的小视频时，会按home键在下方正常显示
========================================================================================================================

