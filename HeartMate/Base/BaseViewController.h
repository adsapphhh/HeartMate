//
//  BaseViewController.h
//  AXKit
//
//  Created by xaoxuu on 29/04/2017.
//  Copyright © 2017 Titan Studio. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AXKit/TableKit.h>

typedef NS_ENUM(NSUInteger, ContentViewStyle) {
    ContentViewStyleNoTopBar, // 默认   // view的区域覆盖屏幕除了navBar以外的地方，（适用于只有navBar没tabBar的视图）
    ContentViewStyleNoBottomBar,       // view的区域覆盖屏幕除了tabBar以外的地方，（适用于只有tabBar没有navBar的视图）
    ContentViewStyleNoTopAndBottomBar, // view的区域覆盖屏幕除了navBar和tabBar以外的地方，（适用于既有navBar又有tabBar的视图）
    ContentViewStyleFullScreen,             // view的区域覆盖全屏幕，（适用于没有navBar和tabBar的视图）
};

#pragma mark - 基类协议
@protocol BaseVC <NSObject>
@optional


- (CGRect)ax_contentViewFrame:(CGRect)frame;

- (void)ax_initSubview;


- (void)ax_initTableView;

- (void)ax_initNavigationBar;

- (void)ax_initProperty;

@end

@interface BaseViewController : UIViewController <BaseVC>

@end
