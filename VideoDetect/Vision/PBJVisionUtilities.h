//
//  PBJVisionUtilities.h
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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern NSString * const HTMergedVideoLocalFileName;

typedef void (^HTVideoExportBlock)(NSURL *url, NSError *error);
typedef void (^HTVideoMergeCaptionBlock)(id object, NSError *error);

@interface PBJVisionUtilities : NSObject

+ (NSString *)getVideoCacheDirectoryName;

+ (void) composeAndExportVideo:(NSURL *)videoURL durations:(NSArray *)durations block:(HTVideoExportBlock)block;

+ (UIImage *)captureFrameAtSecond: (CMTime) captureTime onClipUrl:(NSURL *) clipUrl;

+ (void)convertVideo:(NSURL *)videoUrl toGIFFile:(NSString*)filename withBlock:(HTVideoMergeCaptionBlock)block;

@end

@interface NSString (PBJExtras)

+ (NSString *)PBJformattedTimestampStringFromDate:(NSDate *)date;

@end
