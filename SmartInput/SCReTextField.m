//
//  SCReTextField.m
//  CardRechage
//
//  Created by zhy on 03/06/2017.
//  Copyright © 2017 zhy. All rights reserved.
//

#import "SCReTextField.h"
#import "WTReParser.h"

@interface SCReTextField () <UITextFieldDelegate>

/**
 待替换成的字符串
 */
@property (nonatomic, copy) NSString *changeStr;
/**
 上次输入框中的文本字符串
 */
@property (nonatomic, copy) NSString *lastTextStr;
/**
 待替换的范围
 */
@property (nonatomic) NSRange replaceRange;
/**
 需要把光标定位到的位置
 */
@property (nonatomic) NSUInteger targetCursorPosition;
@end

@implementation SCReTextField

#pragma mark - lifeCycle
- (void)awakeFromNib
{
    [super awakeFromNib];
    self.delegate = self; //由于整个工程引用了UITextField+BlocksKit，这里不能使用代理
//    @weakify(self);
//    self.bk_shouldChangeCharactersInRangeWithReplacementStringBlock = ^BOOL(UITextField *textField, NSRange range, NSString *string) {
//        @strongify(self);
//        return [self textField:textField shouldChangeCharactersInRange:range replacementString:string];
//    };
    [self addTarget:self action:@selector(formatInput:) forControlEvents:UIControlEventEditingChanged]; //用于抓取联想词输入
    
    [self addObserver:self forKeyPath:@"selectedTextRange" options:NSKeyValueObservingOptionNew context:nil]; //用于获取实时的光标位置
}

- (instancetype)init
{
    return [self initWithFrame:CGRectZero];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self addTarget:self action:@selector(formatInput:) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (void)dealloc
{
    [self removeTarget:self action:@selector(formatInput:) forControlEvents:UIControlEventEditingChanged];
    [self removeObserver:self forKeyPath:@"selectedTextRange"];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string

{
    NSLog(@"location=%ld, length=%ld", range.location, range.length);
    if (!_pattern || !_patternWhenCopy || _gap == 0 || _limit == 0) {
        return YES;
    }
    
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", self.patternWhenCopy];
    BOOL isValid = [predicate evaluateWithObject:string];
    if (!isValid && ![string isEqualToString:@""]) {
        return NO;
    }
    NSMutableString *matchStr = [NSMutableString stringWithString:textField.text];
    
    if ([matchStr stringByReplacingOccurrencesOfString:@" " withString:@""].length > self.limit && string.length > 0) {
        //如果原始字段已经到达限制，不允许再输入
        return NO;
    }
    
    if (string == nil || string.length == 0) { //代表删除
        if ((range.location + 1) % (self.gap + 1) == 0 && range.length == 1) { //如果删除的为空格，再多删除一位
            range.location -= 1;
            range.length += 1;
        }
        [matchStr deleteCharactersInRange:range];
    }else{ //代表替换
        [matchStr replaceCharactersInRange:range withString:string];
    }
    
    //这是获取改变后的textfiled的内容
    NSMutableString *cardNum = [NSMutableString stringWithString:[matchStr stringByReplacingOccurrencesOfString:@" " withString:@""]];
    
    //需要替换成的
    NSMutableString *changedStr = [NSMutableString stringWithString:[string stringByReplacingOccurrencesOfString:@" " withString:@""]];
    if (string.length > 0 && changedStr.length == 0) { //如果只是输入或粘贴空格，不予处理
        return NO;
    }
    if (cardNum.length > self.limit) { //大于多少位位不能输入，进行截取，取字符串前段部分
        NSInteger characterLeft = cardNum.length - self.limit;
        changedStr = [NSMutableString stringWithString:[changedStr substringToIndex:changedStr.length - characterLeft]];
        
        NSMutableString *matchStr = [NSMutableString stringWithString:textField.text]; //重新赋值
        [matchStr insertString:changedStr atIndex:range.location];
        cardNum = [NSMutableString stringWithString:[matchStr stringByReplacingOccurrencesOfString:@" " withString:@""]];
    }
    
    self.replaceRange = range;
    self.changeStr = changedStr;
    return YES;
    
}

- (void)formatInput:(UITextField *)textField
{
    NSLog(@"%@", textField.text);
    
    NSMutableString *cardNum = [NSMutableString stringWithString:[textField.text stringByReplacingOccurrencesOfString:@" " withString:@""]];//这是获取改变后的textfiled的内容
    NSMutableString *str =  [NSMutableString stringWithString:cardNum];
    
    //在特殊位置添加空格
    WTReParser *parser = [[WTReParser alloc] initWithPattern:self.pattern];
    NSString *formattedStr = [parser reformatString:str];
    
    //将最终显示的内容复制给textfield
    if (!formattedStr) { //如果输入内容中含有非法字符，则回滚到原先的内容
        textField.text = self.lastTextStr;
        
        //重新定位光标
        UITextPosition *targetPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:self.targetCursorPosition];
        [textField setSelectedTextRange:[textField textRangeFromPosition:targetPosition toPosition:targetPosition]];
        return;
    } else if (![formattedStr isEqualToString:textField.text]) {
        textField.text = formattedStr;
    }
    
    
    if (self.lastTextStr.length != textField.text.length) {
        
        //这个是判断是删除还是添加内容，假如是删除那就将光标向前移，假如添加就要将光标向后移动
        NSUInteger targetCursorPosition = self.targetCursorPosition;
        NSRange range = self.replaceRange;
        if (self.changeStr != nil && self.changeStr.length != 0)
        {
            targetCursorPosition = (targetCursorPosition - targetCursorPosition/(self.gap + 1) + self.changeStr.length) + (targetCursorPosition - targetCursorPosition/(self.gap + 1) + self.changeStr.length - 1) / (self.gap);
        }else{
            if (range.location < targetCursorPosition) { //不选取任何范围，进行回删
                targetCursorPosition = range.location;
                if (targetCursorPosition > 0 && targetCursorPosition % (self.gap + 1) == 0) {
                    targetCursorPosition--;
                }
            } else if (range.location == targetCursorPosition) { //选取一定范围进行回删
                if (targetCursorPosition > 0 && targetCursorPosition % (self.gap + 1) == 0) {
                    targetCursorPosition--;
                }
            }
        }
        //重新定位光标
        UITextPosition *targetPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:targetCursorPosition];
        [textField setSelectedTextRange:[textField textRangeFromPosition:targetPosition toPosition:targetPosition]];
        
        //更新相关数据
        self.targetCursorPosition = targetCursorPosition;
        self.lastTextStr = formattedStr;
    }
    
    //对外的回调
    if (self.valueChangeBlock) {
        self.valueChangeBlock(self);
    }
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"selectedTextRange"]) {
        self.targetCursorPosition = [self offsetFromPosition:self.beginningOfDocument toPosition:self.selectedTextRange.start];
    }
}
@end
