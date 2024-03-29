//
//  EditTextVC.h
//  HeartMate
//
//  Created by xaoxuu on 08/03/2018.
//  Copyright © 2018 xaoxuu. All rights reserved.
//

#import "BaseViewController.h"
#import "BaseTextField.h"



@interface EditTextVC : BaseViewController

/**
 title
 */
@property (copy, nonatomic) NSString *editTitle;

@property (copy, nonatomic) NSString *defaultText;

/**
 completion
 */
@property (copy, nonatomic) void (^block_completion)(NSString *text);


@end
