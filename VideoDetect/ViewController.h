//
//  ViewController.h
//  VideoDetect
//
//  Created by Yan Jiao on 10/6/17.
//  Copyright © 2017 Yan Jiao. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *gifImageView;
@property (nonatomic, weak) IBOutlet UIView *spinnerView;
@property (nonatomic, weak) IBOutlet UITextView *logTextView;

@end

