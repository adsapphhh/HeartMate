//
//  RecordVC.m
//  HeartMate
//
//  Created by xaoxuu on 04/03/2018.
//  Copyright © 2018 xaoxuu. All rights reserved.
//

#import "RecordVC.h"
#import <AXKit/StatusKit.h>
#import "RecordStartButton.h"
#import "HeartKit.h"
#import "HMHeartRate.h"
#import "HeartRateDetailVC.h"

static BOOL run = NO;
static ax_dispatch_operation_t token;

static inline UILabel *defaultLabelWithFontSize(CGFloat fontSize){
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, kScreenW - 16, 40)];
    label.adjustsFontSizeToFitWidth = YES;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont fontWithName:axThemeManager.font.name size:fontSize];
    return label;
}


static BOOL prepared = NO;

@interface RecordVC () <HKCaptureSessionDelegate>

@property (strong, nonatomic) HKOutputView *live;

@property (strong, nonatomic) UILabel *largeTitle;

@property (strong, nonatomic) UILabel *statusTips;

@property (strong, nonatomic) UIProgressView *progressView;

@property (strong, nonatomic) UIButton *startButton;

@property (strong, nonatomic) UIVisualEffectView *visualEffectView;

@property (strong, nonatomic) UIView *mask;
@property (strong, nonatomic) UIView *overlay;

@property (strong, nonatomic) UIButton *edit;

@end

@implementation RecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationController.view.backgroundColor = axThemeManager.color.theme;
    self.view.backgroundColor = axThemeManager.color.theme;
    self.view.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBarHidden = YES;
    [self setupVisualLayer];
    
    [self setupSubviews];
    
    
    //开启测心率方法
    [HKCaptureSession sharedInstance].delegate = self;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (CGRect)ax_contentViewFrame:(CGRect)frame{
//    frame.size.height -= kTabBarHeight;
    return frame;
}


- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    // 如果太快，用户可能没反应过来，看不到动画
    token = ax_dispatch_cancellable(0.2, dispatch_get_main_queue(), ^{
        [self startCapture];
    });
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    // 如果用户在0.2秒内迅速离开页面，要取消掉[self startCapture]的定时任务
    ax_dispatch_cancel_operation(token);
    [self stopCapture];
}


- (void)stopCapture{
    run = NO;
    [self updateUI:^{
        [[HKCaptureSession sharedInstance] stopRunning];
        [[HKCaptureSession sharedInstance].previewLayer removeFromSuperlayer];
    }];
    
}

- (void)startCapture{
    if (prepared) {
        run = YES;
        [HKCaptureSession sharedInstance].previewLayer.frame = self.overlay.bounds;
        [self.overlay.layer insertSublayer:[HKCaptureSession sharedInstance].previewLayer atIndex:0];
        [self updateUI:^{
            [[HKCaptureSession sharedInstance] startRunning];
            // 操作过快的时候图层可能没有设置完毕
            [self.overlay.layer insertSublayer:[HKCaptureSession sharedInstance].previewLayer atIndex:0];
        }];
        
    } else {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[HKCaptureSession sharedInstance] prepare];
        });
    }
}

- (void)hkCaptureSession:(HKCaptureSession *)session didLoadFinished:(BOOL)finished error:(NSError *)error{
    prepared = finished;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (finished) {
            [self startCapture];
        }
        if (error) {
            [UIAlertController ax_showAlertWithTitle:error.localizedDescription message:error.localizedRecoverySuggestion actions:nil];
        }
    });
}
- (void)hkCaptureSession:(HKCaptureSession *)session timestamp:(NSTimeInterval)timestamp point:(CGFloat)point{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.live drawRateWithPoint:@(point)];
    });
}

- (void)hkCaptureSession:(HKCaptureSession *)session progress:(CGFloat)progress instantHeartRate:(NSInteger)instantHeartRate {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusTips.text = [NSString stringWithFormat:@"%d bpm", (int)instantHeartRate];
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)hkCaptureSession:(HKCaptureSession *)session didCompletedWithHeartRate:(NSInteger)heartRate detail:(NSArray<NSNumber *> *)detail{
    if (run) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusTips.text = [NSString stringWithFormat:@"%d bpm", (int)heartRate];
            [self stopCapture];
            
            HMHeartRate *avgHR = [[HMHeartRate alloc] init];
            avgHR.time = [NSDate date];
            [avgHR.detail addObjects:detail];
            avgHR.heartRate = heartRate;
            [avgHR.tags addObject:[LocalizedStringUtilities stringForCurrentWeekday]];
            [avgHR.tags addObject:[LocalizedStringUtilities stringForCurrentTimeInDay]];
            RLMRealm *realm = [RLMRealm defaultRealm];
            [realm transactionWithBlock:^{
                [realm addObject:avgHR];
            }];
//            [[NSNotificationCenter defaultCenter] postNotificationName:NOTI_HR_UPDATE object:@1];
            
            HeartRateDetailVC *vc = [[HeartRateDetailVC alloc] init];
            vc.model = avgHR;
            [self.navigationController pushViewController:vc animated:YES];
            
//            NSString *msg = [NSString stringWithFormat:@"\n%@\n%@", NSLocalizedString(@"The data samples for this measurement are:", @"本次测量的数据样本为："), detail.firstObject];
//            for (int i = 1; i < detail.count; i++) {
//                msg = [msg stringByAppendingFormat:@",%@", detail[i]];
//            }
//            [UIAlertController ax_showAlertWithTitle:self.statusTips.text message:msg actions:^(UIAlertController * _Nonnull alert) {
//                [alert ax_addDestructiveActionWithTitle:NSLocalizedString(@"Discard", @"丢弃") handler:^(UIAlertAction * _Nonnull sender) {
//                    [self stopCapture];
//                }];
//                [alert ax_addDefaultActionWithTitle:NSLocalizedString(@"Save", @"保存") handler:^(UIAlertAction * _Nonnull sender) {
//                    [UIAlertController ax_showAlertWithTitle:NSLocalizedString(@"Set Tags", @"设置标签") message:NSLocalizedString(@"Please enter a simple vocabulary as a comma separated by commas. You can use these tags for data analysis later.", @"请输入简单的词汇作为标签，用英文逗号分隔。以后你可以通过这些标签进行数据分析。") actions:^(UIAlertController * _Nonnull alert) {
//                        HMHeartRate *avgHR = [[HMHeartRate alloc] init];
//                        avgHR.time = [NSDate date];
//                        [avgHR.detail addObjects:detail];
//                        avgHR.heartRate = heartRate;
//
//                        __block UITextField *tf;
//                        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
//                            tf = textField;
//                            textField.text = defaultTags();
//                            textField.returnKeyType = UIReturnKeyDone;
//                            [textField ax_addEditingEndOnExitHandler:^(__kindof UITextField * _Nonnull sender) {
//                                [self stopCapture];
//                            }];
//                        }];
//                        [alert ax_addDefaultActionWithTitle:nil handler:^(UIAlertAction * _Nonnull sender) {
//                            NSArray<NSString *> *tags = [tf.text componentsSeparatedByString:@","];
//                            if (tags.count) {
//                                [avgHR.tags addObjects:tags];
//                            }
//                            RLMRealm *realm = [RLMRealm defaultRealm];
//                            [realm transactionWithBlock:^{
//                                [realm addObject:avgHR];
//                            }];
//                            [self stopCapture];
//                            [[NSNotificationCenter defaultCenter] postNotificationName:NOTI_HR_UPDATE object:@1];
//                        }];
//                        [alert ax_addCancelActionWithTitle:nil handler:^(UIAlertAction * _Nonnull sender) {
//                            RLMRealm *realm = [RLMRealm defaultRealm];
//                            [realm transactionWithBlock:^{
//                                [realm addObject:avgHR];
//                            }];
//                            [self stopCapture];
//                        }];
//                    }];
//                }];
            
//            }];
        });
        
    }
}


- (void)hkCaptureSession:(HKCaptureSession *)session state:(HKCaptureState)state error:(nonnull NSError *)error{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state == HKCaptureStateError) {
            self.progressView.hidden = YES;
            self.largeTitle.text = NSLocalizedString(@"Press the camera with your fingertip.", @"请用指尖轻轻按住摄像头");
        } else if (state == HKCaptureStatePreparing) {
            self.progressView.hidden = YES;
            self.largeTitle.text = NSLocalizedString(@"Detecting pulse ...", @"正在检测脉搏...");
        } else if (state == HKCaptureStateCapturing) {
            self.progressView.hidden = NO;
            self.largeTitle.text = NSLocalizedString(@"Measuring ...", @"正在测量...");
        } else if (state == HKCaptureStateCompleted) {
            self.progressView.hidden = NO;
            self.largeTitle.text = NSLocalizedString(@"Measurement is completed!", @"测量完成");
        }
    });
}




- (void)setupVisualLayer{
    UIView *overlay = UIViewWithHeight(kScreenH);
    [self.view addSubview:overlay];
    self.overlay = overlay;
    
    UIVisualEffectView *vev = [[UIVisualEffectView alloc] initWithFrame:CGRectMake(0, 0, kScreenW, kScreenH)];
    UIVisualEffect *ve = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    vev.effect = ve;
    UIView *view = [[UIView alloc] initWithFrame:vev.bounds];
    view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    [vev.contentView addSubview:view];
    [overlay addSubview:vev];
    self.visualEffectView = vev;
    
}



- (void)setupSubviews{
    
    
    CGFloat centerX = 0.5 * self.view.width;
    CGFloat height = self.view.bounds.size.height;
    
    self.largeTitle = defaultLabelWithFontSize(24);
    [self.view addSubview:self.largeTitle];
    self.largeTitle.top = 40;
    self.largeTitle.text = NSLocalizedString(@"Press the camera with your fingertip.", @"请用指尖轻轻按住摄像头");
    
    RecordStartButton *startButton = [[RecordStartButton alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    [self.view addSubview:startButton];
    self.startButton = startButton;
    startButton.bottom = height - 20 - kTabBarHeight;
    startButton.centerX = centerX;
    __weak typeof(self) weakSelf = self;
    [startButton ax_addTouchUpInsideHandler:^(__kindof UIButton * _Nonnull sender) {
        if (sender.selected) {
            [weakSelf stopCapture];
        } else {
            [weakSelf startCapture];
        }
    }];
    
    
    UIButton *edit = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [self.view addSubview:edit];
    self.edit = edit;
    edit.imageEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    [edit setImage:UIImageNamed(@"icon_setting") forState:UIControlStateNormal];
    edit.centerY = startButton.centerY;
    edit.right = self.view.width - 8;
    [edit ax_addTouchUpInsideHandler:^(__kindof UIButton * _Nonnull sender) {
        NSString *tip = NSLocalizedString(@"In general, the longer the measurement duration, the higher the accuracy.", @"一般来说，测量时长越长，准确率越高。");
        NSString *msg = [NSString stringWithFormat:@"%@\n\n\n", tip];
        [BaseAlertController ax_showActionSheetWithTitle:NSLocalizedString(@"Select Duration", @"选择测量时长") message:msg actions:^(UIAlertController * _Nonnull alert) {
            CGFloat width = self.view.width - 20 - 16;
            CGFloat topMargin = [tip ax_textHeightWithFont:[UIFont systemFontOfSize:13] width:width];
            CGFloat height = 40;
            
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(16, kNavBarHeight + topMargin + 8, 60, height)];
            lb.textAlignment = NSTextAlignmentCenter;
            lb.text = [NSString stringWithFormat:@"%.0f%@", [HKCaptureSession sharedInstance].expectedDuration, NSLocalizedString(@"s", @"秒")];
            [alert.view addSubview:lb];
            lb.font = axThemeManager.font.customLarge;
            
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(lb.right+8, lb.top, width - lb.right - 8, lb.height)];
            [alert.view addSubview:slider];
            slider.minimumValue = 5.0;
            slider.maximumValue = 30.0;
            slider.tintColor = axThemeManager.color.accent;
            slider.value = [HKCaptureSession sharedInstance].expectedDuration;
            [slider ax_addValueChangedHandler:^(__kindof UISlider * _Nonnull sender) {
                lb.text = [NSString stringWithFormat:@"%.0f%@", sender.value, NSLocalizedString(@"s", @"秒")];
            }];
            [slider ax_addTouchUpHandler:^(__kindof UISlider * _Nonnull sender) {
                [HKCaptureSession sharedInstance].expectedDuration = sender.value;
            }];
            [alert ax_addCancelActionWithTitle:NSLocalizedString(@"Done", @"完成") handler:nil];
        }];
    } animatedScale:1.36 duration:0.8];
    
    UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, 0, 120, 2)];
    [self.view addSubview:progressView];
    progressView.hidden = YES;
    progressView.progress = 0;
    progressView.centerX = centerX;
    progressView.bottom = startButton.top - 54;
    progressView.tintColor = [UIColor whiteColor];
    progressView.trackTintColor = [UIColor colorWithWhite:1 alpha:0.3];
    self.progressView = progressView;
    
    self.statusTips = defaultLabelWithFontSize(32);
    self.statusTips.height = 50;
    [self.view addSubview:self.statusTips];
    self.statusTips.bottom = self.progressView.top - 8;
    
    
    //创建一个心电图的View
    CGFloat centerY = (self.statusTips.top - self.largeTitle.bottom)/2 + self.largeTitle.bottom;
    self.live = [[HKOutputView alloc]initWithFrame:CGRectMake(0, 0, self.view.width, 150)];
    [self.view addSubview:self.live];
    self.live.center = CGPointMake(centerX, centerY);
    self.live.backgroundColor = [UIColor clearColor];
    
    
    
    UIView *mask = UIMaskViewWithSizeAndCornerRadius(self.startButton.bounds.size, 0.5*self.startButton.height);
    mask.frame = self.startButton.frame;
    self.mask = mask;
    self.overlay.maskView = self.mask;
    
    [self updateUI:^{
        
    }];
    
}


- (void)updateUI:(void (^)(void))completion{
    if (run) {
        [self.progressView setProgress:0 animated:NO];
        self.startButton.selected = YES;
        [UIView animateWithDuration:1 delay:0.08 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionCurveEaseInOut animations:^{
            CGFloat w0 = self.startButton.height/2;
            CGFloat n = 12; // 放大n倍，w1 = n * w0
            CGFloat offset = n*w0;
            self.mask.transform = CGAffineTransformScale(CGAffineTransformMakeTranslation(0, -offset), n, n);
            self.tabBarController.tabBar.transform = CGAffineTransformMakeTranslation(0, 12);
            self.edit.transform = CGAffineTransformMakeTranslation(kScreenW - self.edit.left, 0);
        } completion:^(BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    } else {
        self.startButton.selected = NO;
        [UIView animateWithDuration:1 delay:0.08 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionCurveEaseInOut animations:^{
            self.mask.transform = CGAffineTransformIdentity;
            self.tabBarController.tabBar.transform = CGAffineTransformIdentity;
            self.edit.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    }
}



@end
