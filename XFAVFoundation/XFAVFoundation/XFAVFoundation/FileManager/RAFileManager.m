//
//  RAFileManager.m
//  VideoRecord
//
//  Created by ZCBL on 16/2/23.
//  Copyright © 2016年 ZCBL. All rights reserved.
//

#import "RAFileManager.h"
#import "NSString+Hash.h"

#define FILE_PROJECT_NAME @"videos"

static RAFileManager * manager = nil;

@implementation RAFileManager
+ (id)defaultManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[RAFileManager alloc] init];
    });
    NSFileManager* filemanager = [NSFileManager defaultManager];
    
    NSString* path = [manager getFileBasePath];
    NSLog(@"path = %@", path);
    NSURL* urlPath = [NSURL fileURLWithPath:path];
    BOOL falg;
    falg = [filemanager createDirectoryAtURL:urlPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSLog(@"falg = %d", falg);
    
    return manager;
}
//  创建文件夹
- (NSString *)fileCreateWithName:(NSString *)filenName
{
    NSString * basePath = [self getFileBasePath];
    NSString * filePath = [basePath stringByAppendingPathComponent:filenName];
    NSFileManager * fileMangaer = [NSFileManager defaultManager];
    [fileMangaer createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    return filePath;
}
//  判断文件是否存在, 如果存在 返回
- (BOOL)fileExistsWithName:(NSString *)fileName file:(void (^)(NSData * data,BOOL isExist))block_file
{
    NSFileManager* filemanager = [NSFileManager defaultManager];
    NSString * filePath = [NSString stringWithFormat:@"%@/%@.mp4",[self fileCreateWithName:@"video"],fileName];
    BOOL flag;
    flag = [filemanager fileExistsAtPath:filePath isDirectory:nil];
    if (flag) {
        NSData * fileData = [NSData dataWithContentsOfFile:filePath];
        if (block_file) {
            block_file(fileData,YES);
            return YES;
        }
        else{
            return YES;
        }
    }
    else{
        block_file(nil,NO);
        return NO;
    }
}
//   清楚缓存
- (BOOL)clearCache
{
    NSFileManager* filemanager = [NSFileManager defaultManager];
    NSString* path = [self getFileBasePath];
    return [filemanager removeItemAtPath:path error:nil];
}

- (void)removeFileWithUrl:(NSURL*)url block:(void (^)(BOOL success))callblock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if ([fileManager fileExistsAtPath:url.path]) {
            NSError *error;
            [fileManager removeItemAtPath:url.path error:&error];
            NSLog(@"删除成功---->%@",url);
            if (callblock) {
                if (error) {
                    callblock(NO);
                }
                else{
                    callblock(YES);
                }
            }
        }
    });
}

- (void)conversionFormatMp4WithUrl:(NSURL*)videoUrl videoUrl:(NSString *)url videoblock:(void (^)(BOOL success, NSString* urlString))callblock
{
//    AVMutableVideoComposition *composition = [self addTitleLayerToVideoWithURL:videoUrl];
    
    AVURLAsset* avAsset = [AVURLAsset URLAssetWithURL:videoUrl options:nil];
    NSArray* compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        AVAssetExportSession* exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
        NSDateFormatter* formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
        //        NSString *path = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@.mp4", [formater stringFromDate:[NSDate date]]];
        
        exportSession.outputURL = [self filePathUrlWithUrl:url]; //转换输出地址
        exportSession.outputFileType = AVFileTypeMPEG4; //转换格式 支持安卓设备播放格式
        exportSession.shouldOptimizeForNetworkUse = YES;
//        exportSession.videoComposition = composition;
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            switch ([exportSession status]) {
                case AVAssetExportSessionStatusFailed:
                    NSLog(@"%@",exportSession.error);
                    if (callblock) {
                        callblock(NO,[NSString stringWithFormat:@"%@",exportSession.error]);
                    }
                    break;
                case AVAssetExportSessionStatusCancelled:
                    break;
                case AVAssetExportSessionStatusCompleted:{
                    NSLog(@"转换完成");
                    //                    ZLog(@"---文件大小:---->%f----地址-----> %@",[self getFileSizeWithUrl:[self filePathUrlWithUrl:url]],[self filePathUrlWithUrl:url]);
                    if (callblock) {
                        callblock(YES,[self filePathWithUrl:url]);
                    }
                    break;
                }
                default:
                    break;
            }
        }];
    }
}


- (CGFloat)getFileSizeWithPath:(NSString*)path
{
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    float filesize = -1.0;
    if ([fileManager fileExistsAtPath:[self filePathWithUrl:path]]) {
        NSDictionary* fileDic = [fileManager attributesOfItemAtPath:[self filePathWithUrl:path] error:nil]; //获取文件的属性
        unsigned long long size = [[fileDic objectForKey:NSFileSize] longLongValue];
        filesize = 1.0 * size / 1024;
    }
    return filesize;
}

- (CGFloat)getFileSizeWithUrl:(NSURL*)url
{
    NSFileManager* fileManager = [[NSFileManager alloc] init];
    float filesize = -1.0;
    if ([fileManager fileExistsAtPath:url.path]) {
        NSDictionary* fileDic = [fileManager attributesOfItemAtPath:url.path error:nil]; //获取文件的属性
        unsigned long long size = [[fileDic objectForKey:NSFileSize] longLongValue];
        filesize = 1.0 * size / 1024;
    }
    return filesize;
}

- (NSString *)filePathWithUrl:(NSString *)url
{
    NSString *fileName = [url md5String];
    return [NSString stringWithFormat:@"%@/%@.mp4", [self getFileBasePath], fileName];
}

- (NSURL*)filePathUrlWithUrl:(NSString*)url
{
    return [NSURL fileURLWithPath:[self filePathWithUrl:url]];
}

/*
 *   获得根路径
 */
- (NSString*)getFileBasePath
{
    NSString* basePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    NSString* path = [basePath stringByAppendingPathComponent:FILE_PROJECT_NAME];
    
    return path;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

@end
