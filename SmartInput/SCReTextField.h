//
//  SCReTextField.h
//  CardRechage
//
//  Created by zhy on 03/06/2017.
//  Copyright © 2017 zhy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCReTextField : UITextField
/**
 间隔，即多少个字符插一个空格
 */
@property (nonatomic) IBInspectable NSUInteger gap;

/**
 长度限制，不算空格数
 */
@property (nonatomic) IBInspectable NSUInteger limit;

/**
 输入时检查的正则表达式，如@"^(([a-zA-Z0-9]{5}(?: )){4})[a-zA-Z0-9]{2}$"
 */
@property (nonatomic, copy) IBInspectable NSString *pattern;

/**
 当复制粘贴 内容时需检查的正则表达式，如@"^[a-zA-Z0-9 ]*$"
 */
@property (nonatomic, copy) IBInspectable NSString *patternWhenCopy;

@property (nonatomic, copy) void(^valueChangeBlock)(UITextField *textField);
@end
