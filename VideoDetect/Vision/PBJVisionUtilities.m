//
//  PBJVisionUtilities.m
//  Vision
//
//  Created by Patrick Piemonte on 5/20/13.
//  Copyright (c) 2013-present, Patrick Piemonte, http://patrickpiemonte.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "PBJVisionUtilities.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "NSGIF.h"

NSString * const HTMergedVideoLocalFileName = @"merged_video.mp4";
#define kScreenWidth [[UIScreen mainScreen] bounds].size.width
#define kScreenHeight [[UIScreen mainScreen] bounds].size.height
#define CaptureVideoClipLength 3.0

@implementation PBJVisionUtilities

+ (NSString *)getVideoCacheDirectoryName
{
    NSString *outputDirectory = NSTemporaryDirectory();
    return outputDirectory;
}

+ (NSString *)getVideoCameraClipPathWithClipName:(NSString *)clipName
{
    NSString *outputDirectory = NSTemporaryDirectory();
    NSString *outputPath = [outputDirectory stringByAppendingPathComponent:clipName];
    return outputPath;
}

+ (void) composeAndExportVideo:(NSURL *)videoURL durations:(NSArray *)durations block:(HTVideoExportBlock)block
{
    
    NSError *error = nil;
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    
    CMTime totalDuration = kCMTimeZero;

    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (id timeObj in durations)
    {
        CMTime time = [timeObj CMTimeValue];
        CMTimeRange timeRange = CMTimeRangeMake(time, CMTimeMake(CaptureVideoClipLength*time.timescale, time.timescale));
        
        if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0){
            [audioTrack insertTimeRange:timeRange
                                ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                 atTime:totalDuration
                                  error:nil];
        }
        
        [videoTrack insertTimeRange:timeRange
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        totalDuration = CMTimeAdd(totalDuration, timeRange.duration);
    }
    
    //Get path
    NSString *outputPath = [[PBJVisionUtilities getVideoCacheDirectoryName] stringByAppendingPathComponent:HTMergedVideoLocalFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:outputPath error:&error]) {
            NSLog(@"could not setup an output file: %@", error);
            
            if (block) {
                block(nil, error);
            }
            return;
        }
    }
    
    //Create exporter
    NSURL *url = [NSURL fileURLWithPath:outputPath];
    //AVAssetExportPresetMediumQuality or AVAssetExportPresetHighestQuality
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                      presetName:AVAssetExportPreset1280x720];
    exporter.outputURL=url;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
                
            if (block) {
                block(exporter.outputURL, nil);
            }
            
        });
    }];
}

+ (UIImage *)captureFrameAtSecond: (CMTime) captureTime onClipUrl:(NSURL *) clipUrl
{
    AVAsset *asset = [AVAsset assetWithURL:clipUrl];
    CGFloat scale = [[UIScreen mainScreen]scale];
    AVAssetImageGenerator *imgGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imgGenerator.appliesPreferredTrackTransform = YES;
    imgGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imgGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    NSError *error;
    CMTime actualTimeCapture;
    CGImageRef imageRef = [imgGenerator copyCGImageAtTime:captureTime actualTime:&actualTimeCapture error:&error];
    UIImage *capturedImg;
    if (!error && imageRef) {
        capturedImg = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
        CGImageRelease(imageRef);
    }
    return capturedImg;
}


+ (void)convertVideo:(NSURL *)videoUrl toGIFFile:(NSString*)filename withBlock:(HTVideoMergeCaptionBlock)block
{
    [NSGIF optimalGIFfromURL:videoUrl loopCount:0 completion:^(NSURL *GifURL) {
        
        NSString *outputPath = [[PBJVisionUtilities getVideoCacheDirectoryName] stringByAppendingPathComponent:filename];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:outputPath error:&error]) {
                NSLog(@"could not setup an output file: %@", error);
                
                if (block) {
                    block(nil, error);
                }
                return;
            }
        }
        
        NSError *error = nil;
        [[NSFileManager defaultManager] moveItemAtURL:GifURL toURL:[NSURL fileURLWithPath:outputPath] error:&error];
        
        if (block) {
            block(outputPath, error);
        }
        
    }];
}

@end

#pragma mark - NSString Extras

@implementation NSString (PBJExtras)

+ (NSString *)PBJformattedTimestampStringFromDate:(NSDate *)date
{
    if (!date)
        return nil;
    
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
        [dateFormatter setLocale:[NSLocale autoupdatingCurrentLocale]];
    });
    
    return [dateFormatter stringFromDate:date];
}

@end

