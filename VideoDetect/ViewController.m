//
//  ViewController.m
//  VideoDetect
//
//  Created by Yan Jiao on 10/6/17.
//  Copyright © 2017 Yan Jiao. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "GPUImage.h"
#import "PBJVisionUtilities.h"
#import "UIImage+GIF.h"
#import <Photos/Photos.h>

@interface ViewController () <GPUImageVideoCameraDelegate> {
    NSURL *_videoUrl;
    GPUImageOutput<GPUImageInput> *_filter;
    GPUImageMovie *_videoFile;
    NSMutableArray *_frameTimes;
    NSTimer *_processTimer;
    NSString *_gifUrlString;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _frameTimes = [NSMutableArray new];
    _filter = [[GPUImageMotionDetector alloc] init];
    __unsafe_unretained ViewController * weakSelf = self;
    NSMutableArray* __weak weakFrameTimes = _frameTimes;
    [(GPUImageMotionDetector *) _filter setMotionDetectionBlock:^(CGPoint motionCentroid, CGFloat motionIntensity, CMTime frameTime) {
        if (motionIntensity > 0.2)
        {
            NSString *log = [NSString stringWithFormat:@"Motion: Intensity %f, Point:(%f,%f), Time: %f", motionIntensity, motionCentroid.x, motionCentroid.y, frameTime.value*1.0/frameTime.timescale];
            [weakFrameTimes addObject:@[[NSNumber numberWithFloat:motionIntensity], [NSValue valueWithCMTime:frameTime]]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf printLog: log];
            });
            
        }
    }];
    
    //long press gesture to save image
    UILongPressGestureRecognizer *longPressGes = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(saveImage:)];
    [self.gifImageView addGestureRecognizer:longPressGes];
    self.gifImageView.userInteractionEnabled = YES;
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction) loadVideo:(id)sender
{
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
    {
        UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        cameraUI.allowsEditing = YES;
        cameraUI.delegate = self;
        cameraUI.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *) kUTTypeMovie, nil];
        [self presentViewController: cameraUI animated: YES completion:NULL];
    }
}

- (IBAction)startProcess:(id)sender
{
    _spinnerView.hidden = NO;
    _videoFile = [[GPUImageMovie alloc] initWithURL:_videoUrl];
    [_videoFile addTarget:_filter];
    [_videoFile startProcessing];
    
    [_processTimer invalidate];
    _processTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkVideoFilterProcess) userInfo:nil repeats:YES];
    [_processTimer fire];
}

- (void) checkVideoFilterProcess
{
    if (_videoFile.progress == 1.0) {
        [_processTimer invalidate];
        [self printLog:@"Processing video finished."];
        [self processFrameTimes];
        _spinnerView.hidden = YES;
    }
}

- (void)processFrameTimes
{
    __unsafe_unretained ViewController * weakSelf = self;
    
    //1. sorting frame times by intensity
    [self printLog:@"Sorting by Intensity..."];
    NSArray *sortedArray = [_frameTimes sortedArrayUsingComparator:^(id obj1, id obj2){
        if ([obj1 isKindOfClass:[NSArray class]] && [obj2 isKindOfClass:[NSArray class]]) {
            CGFloat intensity1 = [((NSArray*)obj1).firstObject floatValue];
            CGFloat intensity2 = [((NSArray*)obj2).firstObject floatValue];
            
            if (intensity1 > intensity2) {
                return (NSComparisonResult)NSOrderedAscending;
            } else if (intensity1 < intensity2) {
                return (NSComparisonResult)NSOrderedDescending;
            }
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    //2. for the top 3 frame time, catch video clip
    int max = 3;
    int idx = 0;
    float previewTime = 0;
    NSMutableArray *selectedFrameTimeArray = [NSMutableArray new];
    for (NSArray *values in sortedArray)
    {
        CGFloat intensity = [values.firstObject floatValue];
        CMTime frameTime = [values.lastObject CMTimeValue];
        float seconds = (frameTime.value/frameTime.timescale*1.0);
        if (previewTime < seconds - 3) {
            [self printLog:[NSString stringWithFormat:@"%ld. Intensity %f happened on %f seconds", selectedFrameTimeArray.count, intensity, seconds]];
            [selectedFrameTimeArray addObject:[NSValue valueWithCMTime:frameTime]];
            previewTime = seconds;
        }
        idx ++;
        if (selectedFrameTimeArray.count == max) break;
    }
    
    //3. concat clips
    [PBJVisionUtilities composeAndExportVideo:_videoUrl durations:selectedFrameTimeArray block:^(NSURL *url, NSError *error) {
        if (!error) {
            [weakSelf printLog:[NSString stringWithFormat: @"Extract and concat the video to %@", url.relativeString]];
            
            //4. convert to gif
            [PBJVisionUtilities convertVideo:url toGIFFile:@"tmp.gif" withBlock:^(NSString *object, NSError *error) {
                [weakSelf printLog:[NSString stringWithFormat: @"Finished converting video to gif: %@", object]];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSData *data = [NSData dataWithContentsOfFile:object];
                    weakSelf.gifImageView.image = [UIImage sd_animatedGIFWithData:data];
                    _gifUrlString = object;
                });
            }];
        }
    }];
    
    
}

- (void) reset
{
    [_videoFile endProcessing];
    _videoFile = nil;
    self.logTextView.text = @"";
}

- (void) saveImage:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer state] == UIGestureRecognizerStateEnded)
    {
        if (!_gifUrlString) {
            return;
        }
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:_gifUrlString]];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self showMessageView:@"Saved"];
                }else{
                    [self showMessageView:@"Failed to save."];
                }
            });
        }];
    }
}

#pragma mark - ImagePickerDelegate
// For responding to the user accepting a newly-captured picture or movie
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info
{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {
        
        NSURL *movieUrl = [info objectForKey:
                           UIImagePickerControllerMediaURL];
        
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (movieUrl.path)) {
            UISaveVideoAtPathToSavedPhotosAlbum (
                                                 movieUrl.path, nil, nil, nil);
        }
        
        [picker dismissViewControllerAnimated: NO completion:NULL];
        
        _videoUrl = movieUrl;
        [self reset];
        [self printLog:[NSString stringWithFormat:@"Selected video: %@", movieUrl.relativeString]];
        
    }else{
        [picker dismissViewControllerAnimated: YES completion:NULL];
    }
    
}

- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker
{
    [picker  dismissViewControllerAnimated: YES completion:NULL];
    
}

#pragma mark - Utilities
- (void) printLog:(NSString *)log
{
    self.logTextView.text = [log stringByAppendingFormat:@"\n%@", self.logTextView.text];
}

-(void) showMessageView: (NSString *) message
{
    UIView* msgMaskView =[[UIView alloc] initWithFrame:CGRectMake(90,210,140,60)];
    msgMaskView.layer.cornerRadius =15;
    msgMaskView.opaque = NO;
    msgMaskView.backgroundColor =[UIColor colorWithWhite:0.0f alpha:0.6f];
    UILabel* msgLabel =[[UILabel alloc] initWithFrame:CGRectMake(0,0,140,60)];
    msgLabel.text = message;
    msgLabel.font =[UIFont boldSystemFontOfSize:14.0f];
    msgLabel.textAlignment = NSTextAlignmentCenter;
    msgLabel.textColor =[UIColor colorWithWhite:1.0f alpha:1.0f];
    msgLabel.backgroundColor =[UIColor clearColor];
    [msgMaskView addSubview:msgLabel];
    [self.view addSubview:msgMaskView];
    msgMaskView.center = CGPointMake(msgMaskView.superview.frame.size.width/2, msgMaskView.superview.frame.size.height/2);
    
    [NSTimer scheduledTimerWithTimeInterval:2 target:msgMaskView selector:@selector(removeFromSuperview) userInfo:nil repeats:NO];
    
}

@end
