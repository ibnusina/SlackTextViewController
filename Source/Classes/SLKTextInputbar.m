//
//   Copyright 2014 Slack Technologies, Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import "SLKTextInputbar.h"
#import "SLKTextViewController.h"
#import "SLKTextView.h"
#import "SLKTextView+SLKAdditions.h"
#import "SLKUIConstants.h"
#import "UIView+SLKAdditions.h"

@interface SLKTextInputbar ()

@property (nonatomic, strong) NSLayoutConstraint *leftButtonWC;
@property (nonatomic, strong) NSLayoutConstraint *leftButtonHC;
@property (nonatomic, strong) NSLayoutConstraint *leftMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *bottomMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonWC;
@property (nonatomic, strong) NSLayoutConstraint *rightMarginWC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonTopMarginC;
@property (nonatomic, strong) NSLayoutConstraint *rightButtonBottomMarginC;

@property (nonatomic, strong) Class textViewClass;

@end

@implementation SLKTextInputbar

#pragma mark - Initialization

- (instancetype)initWithTextViewClass:(Class)textViewClass
{
    if (self = [super init]) {
        self.textViewClass = textViewClass;
        [self slk_commonInit];
    }
    return self;
}

- (id)init
{
    if (self = [super init]) {
        [self slk_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        [self slk_commonInit];
    }
    return self;
}

- (void)slk_commonInit
{
    self.buttonWidth = 48;
    
    self.autoHideRightButton = YES;
    self.contentInset = UIEdgeInsetsMake(5.0, 8.0, 5.0, 8.0);
    
    [self addSubview:self.leftButton];
    [self addSubview:self.rightButton];
    [self addSubview:self.textView];
    
    [self slk_setupViewConstraints];
    [self slk_updateConstraintConstants];
    
    self.counterStyle = SLKCounterStyleNone;
    self.counterPosition = SLKCounterPositionTop;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewText:) name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(slk_didChangeTextViewContentSize:) name:SLKTextViewContentSizeDidChangeNotification object:nil];
    
    [self.leftButton.imageView addObserver:self forKeyPath:NSStringFromSelector(@selector(image)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
    [self.rightButton.titleLabel addObserver:self forKeyPath:NSStringFromSelector(@selector(font)) options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
}


#pragma mark - UIView Overrides

- (void)layoutIfNeeded
{
    if (self.constraints.count == 0) {
        return;
    }
    
    [self slk_updateConstraintConstants];
    [super layoutIfNeeded];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(UIViewNoIntrinsicMetric, 44.0);
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}


#pragma mark - Getters

- (SLKTextView *)textView
{
    if (!_textView)
    {
        Class class = self.textViewClass ? : [SLKTextView class];
        
        _textView = [[class alloc] init];
        _textView.translatesAutoresizingMaskIntoConstraints = NO;
        _textView.font = [UIFont systemFontOfSize:15.0];
        _textView.maxNumberOfLines = [self slk_defaultNumberOfLines];
        
        _textView.typingSuggestionEnabled = YES;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
        _textView.keyboardType = UIKeyboardTypeTwitter;
        _textView.returnKeyType = UIReturnKeyDefault;
        _textView.enablesReturnKeyAutomatically = YES;
        _textView.scrollIndicatorInsets = UIEdgeInsetsMake(0.0, -1.0, 0.0, 1.0);
        _textView.textContainerInset = UIEdgeInsetsMake(8.0, 4.0, 8.0, 0.0);
        _textView.layer.cornerRadius = 5.0;
        _textView.layer.borderWidth = 0.5;
        _textView.layer.borderColor =  [UIColor colorWithRed:200.0/255.0 green:200.0/255.0 blue:205.0/255.0 alpha:1.0].CGColor;
        
        // Adds an aditional action to a private gesture to detect when the magnifying glass becomes visible
        for (UIGestureRecognizer *gesture in _textView.gestureRecognizers) {
            if ([gesture isKindOfClass:NSClassFromString(@"UIVariableDelayLoupeGesture")]) {
                [gesture addTarget:self action:@selector(slk_willShowLoupe:)];
            }
        }
    }
    return _textView;
}

- (SLKInputAccessoryView *)inputAccessoryView
{
    if (!_inputAccessoryView)
    {
        _inputAccessoryView = [[SLKInputAccessoryView alloc] initWithFrame:self.bounds];
        _inputAccessoryView.backgroundColor = [UIColor clearColor];
        _inputAccessoryView.userInteractionEnabled = NO;
    }
    
    return _inputAccessoryView;
}

- (UIButton *)leftButton
{
    if (!_leftButton)
    {
        _leftButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _leftButton.translatesAutoresizingMaskIntoConstraints = NO;
        _leftButton.titleLabel.font = [UIFont systemFontOfSize:15.0];
    }
    return _leftButton;
}

- (UIButton *)rightButton
{
    if (!_rightButton)
    {
        _rightButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _rightButton.translatesAutoresizingMaskIntoConstraints = NO;
        _rightButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _rightButton.enabled = NO;
        
        [_rightButton setTitle:NSLocalizedString(@"Send", nil) forState:UIControlStateNormal];
    }
    return _rightButton;
}

- (BOOL)isViewVisible
{
    SEL selector = NSSelectorFromString(@"isViewVisible");
    
    if ([self.controller respondsToSelector:selector]) {
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        BOOL visible = (BOOL)[self.controller performSelector:selector];
#pragma clang diagnostic pop
        
        return visible;
    }
    return NO;
}

- (CGFloat)minimumInputbarHeight
{
    return self.intrinsicContentSize.height;
}

- (CGFloat)appropriateHeight
{
    CGFloat height = 0.0;
    CGFloat minimumHeight = [self minimumInputbarHeight];
    
    if (self.textView.numberOfLines == 1) {
        height = minimumHeight;
    }
    else if (self.textView.numberOfLines < self.textView.maxNumberOfLines) {
        height = [self slk_inputBarHeightForLines:self.textView.numberOfLines];
    }
    else {
        height = [self slk_inputBarHeightForLines:self.textView.maxNumberOfLines];
    }
    
    if (height < minimumHeight) {
        height = minimumHeight;
    }
    
    return roundf(height);
}

- (CGFloat)slk_deltaInputbarHeight
{
    return self.textView.intrinsicContentSize.height-self.textView.font.lineHeight;
}

- (CGFloat)slk_inputBarHeightForLines:(NSUInteger)numberOfLines
{
    CGFloat height = [self slk_deltaInputbarHeight];
    
    height += roundf(self.textView.font.lineHeight*numberOfLines);
    height += self.contentInset.top+self.contentInset.bottom;
    
    return height;
}

- (BOOL)limitExceeded
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (self.maxCharCount > 0 && text.length > self.maxCharCount) {
        return YES;
    }
    return NO;
}

- (CGFloat)slk_appropriateRightButtonWidth
{
    if (self.autoHideRightButton) {
        if (self.textView.text.length == 0) {
            return 0.0;
        }
    }
    NSString *title = [self.rightButton titleForState:UIControlStateNormal];
    
    CGSize rightButtonSize;
    if ([title length] == 0 && self.rightButton.imageView.image) {
        rightButtonSize = self.rightButton.imageView.image.size;
    } else {
        rightButtonSize = [title sizeWithAttributes:@{NSFontAttributeName: self.rightButton.titleLabel.font}];
    }
    
    return rightButtonSize.width+self.contentInset.right;
}

- (CGFloat)slk_appropriateRightButtonMargin
{
    if (self.autoHideRightButton) {
        if (self.textView.text.length == 0) {
            return 0.0;
        }
    }
    return self.contentInset.right;
}

- (NSUInteger)slk_defaultNumberOfLines
{
    if (SLK_IS_IPAD) {
        return 8;
    }
    if (SLK_IS_IPHONE4) {
        return 4;
    }
    else {
        return 6;
    }
}


#pragma mark - Setters

- (void)setBackgroundColor:(UIColor *)color
{
    [super setBackgroundColor:color];
}

- (void)setAutoHideRightButton:(BOOL)hide
{
    if (self.autoHideRightButton == hide) {
        return;
    }
    
    _autoHideRightButton = hide;
    
    self.rightButtonWC.constant = [self slk_appropriateRightButtonWidth];
    [self layoutIfNeeded];
}

- (void)setContentInset:(UIEdgeInsets)insets
{
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, insets)) {
        return;
    }
    
    if (UIEdgeInsetsEqualToEdgeInsets(self.contentInset, UIEdgeInsetsZero)) {
        _contentInset = insets;
        return;
    }
    
    _contentInset = insets;
    
    // Add new constraints
    [self removeConstraints:self.constraints];
    [self slk_setupViewConstraints];
    
    // Add constant values and refresh layout
    [self slk_updateConstraintConstants];
    [super layoutIfNeeded];
}

- (void)setEditing:(BOOL)editing
{
    if (self.isEditing == editing) {
        return;
    }
    
    _editing = editing;
}

#pragma mark - Text Editing

- (BOOL)canEditText:(NSString *)text
{
    if ((self.isEditing && [self.textView.text isEqualToString:text]) || self.controller.isTextInputbarHidden) {
        return NO;
    }
    
    return YES;
}

- (void)beginTextEditing
{
    if (self.isEditing || self.controller.isTextInputbarHidden) {
        return;
    }
    
    self.editing = YES;
    
    [self slk_updateConstraintConstants];
    
    if (!self.isFirstResponder) {
        [self layoutIfNeeded];
    }
}

- (void)endTextEdition
{
    if (!self.isEditing || self.controller.isTextInputbarHidden) {
        return;
    }
    
    self.editing = NO;
    [self slk_updateConstraintConstants];
}


#pragma mark - Character Counter

- (void)slk_updateCounter
{
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *counter = nil;
    
    if (self.counterStyle == SLKCounterStyleNone) {
        counter = [NSString stringWithFormat:@"%lu", (unsigned long)text.length];
    }
    if (self.counterStyle == SLKCounterStyleSplit) {
        counter = [NSString stringWithFormat:@"%lu/%lu", (unsigned long)text.length, (unsigned long)self.maxCharCount];
    }
    if (self.counterStyle == SLKCounterStyleCountdown) {
        counter = [NSString stringWithFormat:@"%ld", (long)(text.length - self.maxCharCount)];
    }
    if (self.counterStyle == SLKCounterStyleCountdownReversed)
    {
        counter = [NSString stringWithFormat:@"%ld", (long)(self.maxCharCount - text.length)];
    }
}


#pragma mark - Magnifying Glass handling

- (void)slk_willShowLoupe:(UIGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateChanged) {
        self.textView.loupeVisible = YES;
    }
    else {
        self.textView.loupeVisible = NO;
    }
    
    // We still need to notify a selection change in the textview after the magnifying class is dismissed
    if (gesture.state == UIGestureRecognizerStateEnded) {
        if (self.textView.delegate && [self.textView.delegate respondsToSelector:@selector(textViewDidChangeSelection:)]) {
            [self.textView.delegate textViewDidChangeSelection:self.textView];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SLKTextViewSelectedRangeDidChangeNotification object:self.textView userInfo:nil];
    }
}


#pragma mark - Notification Events

- (void)slk_didChangeTextViewText:(NSNotification *)notification
{
    SLKTextView *textView = (SLKTextView *)notification.object;
    
    // Skips this it's not the expected textView.
    if (![textView isEqual:self.textView]) {
        return;
    }
    
    // Updates the char counter label
    if (self.maxCharCount > 0) {
        [self slk_updateCounter];
    }
    
    if (self.autoHideRightButton && !self.isEditing)
    {
        CGFloat rightButtonNewWidth = [self slk_appropriateRightButtonWidth];
        
        if (self.rightButtonWC.constant == rightButtonNewWidth) {
            return;
        }
        
        self.rightButtonWC.constant = rightButtonNewWidth;
        self.rightMarginWC.constant = [self slk_appropriateRightButtonMargin];
        
        if (rightButtonNewWidth > 0) {
            [self.rightButton sizeToFit];
        }
        
        BOOL bounces = self.controller.bounces && [self.textView isFirstResponder];
        
        if ([self isViewVisible]) {
            [self slk_animateLayoutIfNeededWithBounce:bounces
                                              options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionBeginFromCurrentState
                                           animations:NULL];
        }
        else {
            [self layoutIfNeeded];
        }
    }
}

- (void)slk_didChangeTextViewContentSize:(NSNotification *)notification
{
    if (self.maxCharCount > 0) {
        BOOL shouldHide = (self.textView.numberOfLines == 1) || self.editing;
    }
}


#pragma mark - View Auto-Layout

- (void)slk_setupViewConstraints
{
    [self.rightButton sizeToFit];
    
    CGFloat rightVerMargin = (self.intrinsicContentSize.height - CGRectGetHeight(self.rightButton.frame)) / 2.0;
    
    NSDictionary *views = @{@"textView": self.textView,
                            @"leftButton": self.leftButton,
                            @"rightButton": self.rightButton,
                            };
    
    NSDictionary *metrics = @{@"top" : @(self.contentInset.top),
                              @"bottom" : @(self.contentInset.bottom),
                              @"left" : @(self.contentInset.left),
                              @"right" : @(self.contentInset.right),
                              @"rightVerMargin" : @(rightVerMargin),
                              @"minTextViewHeight" : @(self.textView.intrinsicContentSize.height),
                              @"buttonWidth" : @(self.buttonWidth)
                              };
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[leftButton(buttonWidth)]-(0)-[textView]-(0)-[rightButton(buttonWidth)]-(0)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0)-[leftButton(0)]-(0@750)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(>=0)-[rightButton(buttonWidth)]-(0@750)-|" options:0 metrics:metrics views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(<=top)-[textView(minTextViewHeight@250)]-(<=bottom)-|" options:0 metrics:metrics views:views]];
    
    self.leftButtonWC = [self slk_constraintForAttribute:NSLayoutAttributeWidth firstItem:self.leftButton secondItem:nil];
    self.leftButtonHC = [self slk_constraintForAttribute:NSLayoutAttributeHeight firstItem:self.leftButton secondItem:nil];
    
    self.leftMarginWC = [self slk_constraintsForAttribute:NSLayoutAttributeLeading][0];
    self.bottomMarginWC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.leftButton];
    
    self.rightButtonWC = [self slk_constraintForAttribute:NSLayoutAttributeWidth firstItem:self.rightButton secondItem:nil];
    self.rightMarginWC = [self slk_constraintsForAttribute:NSLayoutAttributeTrailing][0];
    
    self.rightButtonTopMarginC = [self slk_constraintForAttribute:NSLayoutAttributeTop firstItem:self.rightButton secondItem:self];
    self.rightButtonBottomMarginC = [self slk_constraintForAttribute:NSLayoutAttributeBottom firstItem:self secondItem:self.rightButton];
}

- (void)slk_updateConstraintConstants
{
    CGFloat zero = 0.0;
    
    if (self.isEditing)
    {
        self.leftButtonWC.constant = zero;
        self.leftButtonHC.constant = zero;
        self.leftMarginWC.constant = zero;
        self.bottomMarginWC.constant = zero;
        self.rightButtonWC.constant = zero;
        self.rightMarginWC.constant = zero;
    }
    else {
        CGSize leftButtonSize = [self.leftButton imageForState:self.leftButton.state].size;
        
        if (leftButtonSize.width > 0) {
            self.leftButtonHC.constant = roundf(self.buttonWidth);
            self.bottomMarginWC.constant = roundf(0);
        }
        
        self.leftButtonWC.constant = roundf(self.buttonWidth);
        self.leftMarginWC.constant = zero;
        
        self.rightButtonWC.constant = self.buttonWidth;
        self.rightMarginWC.constant = 0;
        
        CGFloat rightVerMargin = (self.intrinsicContentSize.height - CGRectGetHeight(self.rightButton.frame)) / 2.0;
        
        self.rightButtonTopMarginC.constant = 0;
        self.rightButtonBottomMarginC.constant = 0;
    }
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([object isEqual:self.leftButton.imageView] && [keyPath isEqualToString:NSStringFromSelector(@selector(image))]) {
        UIImage *newImage = change[NSKeyValueChangeNewKey];
        UIImage *oldImage = change[NSKeyValueChangeOldKey];
        
        if ([newImage isEqual:oldImage]) {
            return;
        }
        
        [self slk_updateConstraintConstants];
    }
    else if ([object isEqual:self.rightButton.titleLabel] && [keyPath isEqualToString:NSStringFromSelector(@selector(font))]) {
        [self slk_updateConstraintConstants];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Lifeterm

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SLKTextViewContentSizeDidChangeNotification object:nil];
    
    [_leftButton.imageView removeObserver:self forKeyPath:NSStringFromSelector(@selector(image))];
    [_rightButton.titleLabel removeObserver:self forKeyPath:NSStringFromSelector(@selector(font))];
    
    _leftButton = nil;
    _rightButton = nil;
    
    _textView.delegate = nil;
    _textView = nil;
    
    _leftButtonWC = nil;
    _leftButtonHC = nil;
    _leftMarginWC = nil;
    _bottomMarginWC = nil;
    _rightButtonWC = nil;
    _rightMarginWC = nil;
    _rightButtonTopMarginC = nil;
    _rightButtonBottomMarginC = nil;
}

@end
