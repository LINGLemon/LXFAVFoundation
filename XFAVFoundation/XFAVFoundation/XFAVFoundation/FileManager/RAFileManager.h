//
//  RAFileManager.h
//  VideoRecord
//
//  Created by ZCBL on 16/2/23.
//  Copyright © 2016年 ZCBL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface RAFileManager : NSObject
/*
 *  获得实例化对象,返回并不是 单例
 */
+(id)defaultManager;
- (NSString*)getFileBasePath;
/*
 *  创建文件夹,并返回相对路径 (默认 DOC/IPHONE 目录下文件)
 */
- (NSString *)fileCreateWithName:(NSString *)filenName;
/*
 *  查看本地是否已下载,如果已存在 返回 文件 (默认 DOC/IPHONE/video 目录下文件)
 */
- (BOOL)fileExistsWithName:(NSString *)fileName file:(void (^)(NSData * data,BOOL isExist))block_file;
/*
 *  清楚缓存
 */
- (BOOL)clearCache;
/*
 *  视频url转本地路径  return srting
 */
- (NSString *)filePathWithUrl:(NSString *)url;
/*
 *  视频url转本地路径 return NSURL
 */
- (NSURL *)filePathUrlWithUrl:(NSString *)url;
/*
 *  根据完整路径 删除
 */
-(void)removeFileWithUrl:(NSURL *)url block:(void (^)(BOOL success))callblock;

/*
 *  根据视频url找到视频并转换格式
 */
-(void)conversionFormatMp4WithUrl:(NSURL *)videoUrl videoUrl:(NSString *)url videoblock:(void (^)(BOOL success,NSString* urlString))callblock;
/*
 *  根据视频url计算视频文件大小
 */
- (CGFloat)getFileSizeWithPath:(NSString *)path;
/*
 *  根据视频url计算视频文件大小
 */
- (CGFloat)getFileSizeWithUrl:(NSURL *)url;

@end
