#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

@class SnifferScriptBridge;
@class SnifferDomainModalView;

@interface SnifferScriptBridge : NSObject <WKScriptMessageHandler>
@end

@interface SnifferDomainModalView : UIView
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, copy) void (^onSaveBlock)(NSString *text);
@property (nonatomic, copy) void (^onCloseBlock)(void);
- (void)showInView:(UIView *)parentView initialText:(NSString *)text;
@end

@implementation SnifferDomainModalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
        self.alpha = 0.0;

        UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBgTap:)];
        [self addGestureRecognizer:bgTap];

        CGFloat cardW = MIN(frame.size.width - 48, 330);
        CGFloat cardH = 260;

        _cardView = [[UIView alloc] initWithFrame:CGRectMake((frame.size.width - cardW) / 2.0, (frame.size.height - cardH) / 2.0, cardW, cardH)];
        _cardView.backgroundColor = [UIColor clearColor];
        _cardView.layer.cornerRadius = 20;
        _cardView.layer.masksToBounds = YES;
        _cardView.layer.borderWidth = 0.5;
        _cardView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = _cardView.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_cardView addSubview:blurView];

        UIView *tintOverlay = [[UIView alloc] initWithFrame:_cardView.bounds];
        tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintOverlay.backgroundColor = [UIColor colorWithRed:0.98 green:0.97 blue:0.96 alpha:0.88];
        [_cardView addSubview:tintOverlay];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 14, cardW - 32, 20)];
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        titleLabel.textColor = [UIColor colorWithRed:0.18 green:0.2 blue:0.24 alpha:1.0];
        titleLabel.text = @"嗅探域名放行白名单";
        [_cardView addSubview:titleLabel];

        UILabel *tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 36, cardW - 32, 16)];
        tipLabel.font = [UIFont systemFontOfSize:11];
        tipLabel.textColor = [UIColor colorWithRed:0.5 green:0.53 blue:0.58 alpha:1.0];
        tipLabel.text = @"支持后缀匹配，多个域名用逗号或换行分隔";
        [_cardView addSubview:tipLabel];

        _textView = [[UITextView alloc] initWithFrame:CGRectMake(16, 56, cardW - 32, 134)];
        _textView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        _textView.layer.cornerRadius = 10;
        _textView.layer.borderWidth = 0.5;
        _textView.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.08].CGColor;
        _textView.font = [UIFont systemFontOfSize:13];
        _textView.textColor = [UIColor colorWithRed:0.2 green:0.22 blue:0.26 alpha:1.0];
        _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _textView.autocorrectionType = UITextAutocorrectionTypeNo;
        _textView.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
        [_cardView addSubview:_textView];

        CGFloat btnY = cardH - 52;
        CGFloat btnH = 36;
        CGFloat btnW = (cardW - 32 - 16) / 3.0;

        UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cancelBtn.frame = CGRectMake(16, btnY, btnW, btnH);
        cancelBtn.backgroundColor = [UIColor colorWithRed:0.91 green:0.92 blue:0.94 alpha:1.0];
        cancelBtn.layer.cornerRadius = 9;
        cancelBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
        [cancelBtn setTitleColor:[UIColor colorWithRed:0.35 green:0.38 blue:0.42 alpha:1.0] forState:UIControlStateNormal];
        [cancelBtn addTarget:self action:@selector(cancelTap) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:cancelBtn];

        UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        clearBtn.frame = CGRectMake(16 + btnW + 8, btnY, btnW, btnH);
        clearBtn.backgroundColor = [UIColor colorWithRed:0.96 green:0.91 blue:0.91 alpha:1.0];
        clearBtn.layer.cornerRadius = 9;
        clearBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
        [clearBtn setTitleColor:[UIColor colorWithRed:0.82 green:0.28 blue:0.28 alpha:1.0] forState:UIControlStateNormal];
        [clearBtn addTarget:self action:@selector(clearTap) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:clearBtn];

        UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        saveBtn.frame = CGRectMake(16 + (btnW + 8) * 2, btnY, btnW, btnH);
        saveBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.52 blue:0.96 alpha:1.0];
        saveBtn.layer.cornerRadius = 9;
        saveBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [saveBtn setTitle:@"保存" forState:UIControlStateNormal];
        [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [saveBtn addTarget:self action:@selector(saveTap) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:saveBtn];

        [self addSubview:_cardView];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleBgTap:(UITapGestureRecognizer *)tap {
    CGPoint p = [tap locationInView:self];
    if (CGRectContainsPoint(self.cardView.frame, p)) {
        return;
    }
    if ([self.textView isFirstResponder]) {
        [self.textView resignFirstResponder];
    } else {
        [self cancelTap];
    }
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGRect kbFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat screenH = self.bounds.size.height;
    CGFloat cardH = self.cardView.frame.size.height;
    CGFloat targetCenterY = (screenH - kbFrame.size.height) / 2.0;

    [UIView animateWithDuration:duration > 0 ? duration : 0.25 animations:^{
        CGPoint c = self.cardView.center;
        c.y = MAX(targetCenterY, cardH / 2.0 + 20);
        self.cardView.center = c;
    }];
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGFloat duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat screenH = self.bounds.size.height;

    [UIView animateWithDuration:duration > 0 ? duration : 0.25 animations:^{
        CGPoint c = self.cardView.center;
        c.y = screenH / 2.0;
        self.cardView.center = c;
    }];
}

- (void)showInView:(UIView *)parentView initialText:(NSString *)text {
    self.frame = parentView.bounds;
    self.textView.text = text;

    CGFloat cardW = MIN(self.bounds.size.width - 48, 330);
    CGFloat cardH = 260;
    self.cardView.frame = CGRectMake((self.bounds.size.width - cardW) / 2.0, (self.bounds.size.height - cardH) / 2.0, cardW, cardH);

    [parentView addSubview:self];
    [parentView bringSubviewToFront:self];

    self.cardView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:0 animations:^{
        self.alpha = 1.0;
        self.cardView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)dismissSelf {
    [self.textView resignFirstResponder];
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0.0;
        self.cardView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        self.cardView.transform = CGAffineTransformIdentity;
    }];
}

- (void)cancelTap {
    UIImpactFeedbackGenerator *f = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [f impactOccurred];
    [self dismissSelf];
    if (self.onCloseBlock) {
        self.onCloseBlock();
    }
}

- (void)clearTap {
    UIImpactFeedbackGenerator *f = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [f impactOccurred];
    self.textView.text = @"";
}

- (void)saveTap {
    UIImpactFeedbackGenerator *f = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [f impactOccurred];
    if (self.onSaveBlock) {
        self.onSaveBlock(self.textView.text ?: @"");
    }
    [self dismissSelf];
}

@end

@interface SnifferManager : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *latestMediaUrl;
@property (nonatomic, strong) UIView *buttonsContainer;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) SnifferScriptBridge *scriptBridge;
@property (nonatomic, strong) UILongPressGestureRecognizer *toggleGesture;
@property (nonatomic, copy) NSArray<NSString *> *customDomains;
@property (nonatomic, strong) SnifferDomainModalView *domainModalView;
+ (instancetype)sharedManager;
- (void)captureUrl:(NSString *)urlStr;
- (void)setupFloatingUI;
- (void)clearMedia;
- (void)registerNotifications;
- (void)savePositionRatio:(CGFloat)ratio;
- (CGFloat)loadPositionRatio;
- (void)saveCustomDomains:(NSString *)rawString;
- (NSString *)loadCustomDomainsString;
- (BOOL)isSuspendedHidden;
- (void)saveSuspendedHidden:(BOOL)hidden;
- (void)forceAlignRightEdge;
@end

@implementation SnifferScriptBridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSString *url = message.body[@"url"];
        if (url) {
            [[SnifferManager sharedManager] captureUrl:url];
        }
    } else if ([message.body isKindOfClass:[NSString class]]) {
        [[SnifferManager sharedManager] captureUrl:(NSString *)message.body];
    }
}
@end

@implementation SnifferManager

+ (instancetype)sharedManager {
    static SnifferManager *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[SnifferManager alloc] init];
        inst.scriptBridge = [[SnifferScriptBridge alloc] init];
        inst.customDomains = @[];
        [inst reloadCustomDomains];
    });
    return inst;
}

- (BOOL)isSuspendedHidden {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"Sniffer_User_SuspendedHidden"];
}

- (void)saveSuspendedHidden:(BOOL)hidden {
    [[NSUserDefaults standardUserDefaults] setBool:hidden forKey:@"Sniffer_User_SuspendedHidden"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)reloadCustomDomains {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"Sniffer_CustomDomains"];
    NSMutableArray *arr = [NSMutableArray array];
    if (saved && saved.length > 0) {
        NSString *normalized = [saved stringByReplacingOccurrencesOfString:@"，" withString:@","];
        normalized = [normalized stringByReplacingOccurrencesOfString:@"\n" withString:@","];
        NSArray *items = [normalized componentsSeparatedByString:@","];
        for (NSString *item in items) {
            NSString *trimmed = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].lowercaseString;
            if (trimmed.length > 0) {
                [arr addObject:trimmed];
            }
        }
    }
    self.customDomains = [arr copy];
}

- (void)saveCustomDomains:(NSString *)rawString {
    [[NSUserDefaults standardUserDefaults] setObject:rawString forKey:@"Sniffer_CustomDomains"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadCustomDomains];
}

- (NSString *)loadCustomDomainsString {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"Sniffer_CustomDomains"] ?: @"";
}

- (void)savePositionRatio:(CGFloat)ratio {
    [[NSUserDefaults standardUserDefaults] setDouble:ratio forKey:@"Sniffer_Buttons_PositionRatio_Y"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CGFloat)loadPositionRatio {
    double ratio = [[NSUserDefaults standardUserDefaults] doubleForKey:@"Sniffer_Buttons_PositionRatio_Y"];
    if (ratio <= 0.05 || ratio >= 0.95) {
        return 0.45;
    }
    return (CGFloat)ratio;
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupFloatingUI];
        [self attachGlobalGestures];
    });
}

- (void)onActive {
    [self setupFloatingUI];
    [self attachGlobalGestures];
}

- (UIWindow *)findHostKeyWindow {
    UIWindow *targetWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow && !w.hidden && w.alpha > 0.01) {
                    targetWindow = w;
                    break;
                }
            }
            if (!targetWindow) {
                for (UIWindow *w in scene.windows) {
                    if (!w.hidden && w.alpha > 0.01) {
                        targetWindow = w;
                        break;
                    }
                }
            }
        }
        if (targetWindow) {
            break;
        }
    }
    if (!targetWindow) {
        targetWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    return targetWindow;
}

- (void)attachGlobalGestures {
    UIWindow *targetWindow = [self findHostKeyWindow];
    if (!targetWindow) {
        return;
    }

    if (!self.toggleGesture) {
        self.toggleGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleGlobalToggleGesture:)];
        self.toggleGesture.numberOfTouchesRequired = 2;
        self.toggleGesture.minimumPressDuration = 2.0;
        self.toggleGesture.delegate = self;
        self.toggleGesture.cancelsTouchesInView = NO;
    }

    if (self.toggleGesture.view != targetWindow) {
        [self.toggleGesture.view removeGestureRecognizer:self.toggleGesture];
        [targetWindow addGestureRecognizer:self.toggleGesture];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.refreshButton) {
        CGPoint p = [touch locationInView:self.refreshButton];
        if ([self.refreshButton pointInside:p withEvent:nil]) {
            return NO;
        }
    }
    return YES;
}

- (void)handleGlobalToggleGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];

        BOOL currentHidden = [self isSuspendedHidden];
        BOOL targetHidden = !currentHidden;
        [self saveSuspendedHidden:targetHidden];

        if (targetHidden) {
            [self hideButtonsWithAnimation];
        } else {
            if (self.latestMediaUrl && self.latestMediaUrl.length > 0) {
                [self showButtonsWithAnimation];
            }
        }
    }
}

- (void)handleRefreshLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [feedback impactOccurred];
        [self openDomainManagerCard];
    }
}

- (void)openDomainManagerCard {
    UIWindow *window = [self findHostKeyWindow];
    if (!window) {
        return;
    }

    if (!self.domainModalView) {
        self.domainModalView = [[SnifferDomainModalView alloc] initWithFrame:window.bounds];
        __weak typeof(self) weakSelf = self;
        self.domainModalView.onSaveBlock = ^(NSString *text) {
            [weakSelf saveCustomDomains:text];
        };
    }

    [self.domainModalView showInView:window initialText:[self loadCustomDomainsString]];
}

- (BOOL)isMediaSegmentUrl:(NSString *)urlStr {
    NSString *lower = [urlStr lowercaseString];
    NSArray<NSString *> *segmentKeys = @[
        @".ts",
        @".m4s",
        @".cmfv",
        @".cmfa",
        @".aac",
        @".mp3",
        @".vtt",
        @".key",
        @"segment",
        @"chunk",
        @"fragment"
    ];
    for (NSString *key in segmentKeys) {
        if ([lower containsString:key]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isMediaUrl:(NSString *)urlStr {
    NSString *lower = [urlStr lowercaseString];

    NSArray<NSString *> *domains = self.customDomains;
    if (domains.count > 0) {
        NSString *host = nil;
        NSRange schemeRange = [lower rangeOfString:@"://"];
        if (schemeRange.location != NSNotFound) {
            NSString *afterScheme = [lower substringFromIndex:schemeRange.location + 3];
            NSRange slashRange = [afterScheme rangeOfString:@"/"];
            if (slashRange.location != NSNotFound) {
                host = [afterScheme substringToIndex:slashRange.location];
            } else {
                host = afterScheme;
            }
            NSRange colonRange = [host rangeOfString:@":"];
            if (colonRange.location != NSNotFound) {
                host = [host substringToIndex:colonRange.location];
            }
        }

        if (host && host.length > 0) {
            for (NSString *d in domains) {
                if ([host isEqualToString:d] || [host hasSuffix:[NSString stringWithFormat:@".%@", d]]) {
                    return YES;
                }
            }
        }
    }

    NSArray *blackList = @[@".png", @".jpg", @".jpeg", @".gif", @".webp", @".css", @".js", @".svg", @".ico", @".woff", @".ttf"];
    for (NSString *b in blackList) {
        if ([lower containsString:b]) {
            return NO;
        }
    }

    if ([self isMediaSegmentUrl:urlStr]) {
        return NO;
    }

    NSArray *keys = @[@"m3u8", @"mp4", @"flv", @"mov", @"mkv", @"webm", @"mpd", @"f4v", @"avi", @"playlist", @"manifest", @"videoplayback", @"stream", @"video", @"live", @"vod", @"media", @"playurl", @"play_url", @"video_url"];
    for (NSString *key in keys) {
        if ([lower containsString:key]) {
            return YES;
        }
    }
    return NO;
}

- (void)rotateRefreshIcon {
    UIButton *btn = self.refreshButton;
    if (!btn) {
        return;
    }

    btn.transform = CGAffineTransformIdentity;
    [UIView animateKeyframesWithDuration:1.5 delay:0 options:UIViewKeyframeAnimationOptionCalculationModeLinear animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.33 animations:^{
            btn.transform = CGAffineTransformMakeRotation((CGFloat)(M_PI * 0.66));
        }];
        [UIView addKeyframeWithRelativeStartTime:0.33 relativeDuration:0.33 animations:^{
            btn.transform = CGAffineTransformMakeRotation((CGFloat)(M_PI * 1.33));
        }];
        [UIView addKeyframeWithRelativeStartTime:0.66 relativeDuration:0.34 animations:^{
            btn.transform = CGAffineTransformMakeRotation((CGFloat)(M_PI * 1.99));
        }];
    } completion:^(BOOL finished) {
        btn.transform = CGAffineTransformIdentity;
    }];
}

- (void)captureUrl:(NSString *)urlStr {
    if (!urlStr || ![urlStr isKindOfClass:[NSString class]] || urlStr.length < 8) {
        return;
    }
    if (![urlStr hasPrefix:@"http"]) {
        return;
    }
    if (![self isMediaUrl:urlStr]) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL urlChanged = ![self.latestMediaUrl isEqualToString:urlStr];
        self.latestMediaUrl = urlStr;

        [self setupFloatingUI];

        if (![self isSuspendedHidden]) {
            [self showButtonsWithAnimation];
        }

        if (urlChanged) {
            [self rotateRefreshIcon];
        }
    });
}

- (void)clearMedia {
    self.latestMediaUrl = nil;
    [self hideButtonsWithAnimation];
}

- (void)forceAlignRightEdge {
    if (!self.buttonsContainer || !self.buttonsContainer.superview) {
        return;
    }

    UIView *superV = self.buttonsContainer.superview;
    self.buttonsContainer.transform = CGAffineTransformIdentity;

    CGFloat pW = superV.bounds.size.width;
    CGFloat pH = superV.bounds.size.height;
    CGFloat btnW = self.buttonsContainer.bounds.size.width;
    CGFloat totalH = self.buttonsContainer.bounds.size.height;

    BOOL isLandscape = (pW > pH);
    if (!isLandscape) {
        for (UIView *sub in superV.subviews) {
            if (CGAffineTransformEqualToTransform(sub.transform, CGAffineTransformMakeRotation(M_PI_2)) ||
                CGAffineTransformEqualToTransform(sub.transform, CGAffineTransformMakeRotation(-M_PI_2))) {
                isLandscape = YES;
                break;
            }
        }
    }

    CGFloat rightPadding = isLandscape ? 44.0 : 12.0;
    if (@available(iOS 11.0, *)) {
        if (superV.safeAreaInsets.right > 0) {
            rightPadding = MAX(superV.safeAreaInsets.right + 8, rightPadding);
        }
    }

    CGFloat ratio = [self loadPositionRatio];
    CGFloat safeY = MIN(MAX(ratio * pH - totalH / 2.0, 30), pH - totalH - 30);
    CGFloat targetX = pW - btnW - rightPadding;

    self.buttonsContainer.frame = CGRectMake(targetX, safeY, btnW, totalH);
}

- (void)setupFloatingUI {
    UIWindow *hostWindow = [self findHostKeyWindow];
    if (!hostWindow) {
        return;
    }

    CGFloat btnW = 82;
    CGFloat btnH = 34;
    CGFloat spacing = 8;
    CGFloat refreshD = 28;
    CGFloat totalH = btnH * 4 + spacing * 4 + refreshD;

    if (!self.buttonsContainer) {
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, btnW, totalH)];
        container.backgroundColor = [UIColor clearColor];
        container.hidden = YES;
        container.alpha = 0.0;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanContainer:)];
        pan.delegate = self;
        [container addGestureRecognizer:pan];

        NSArray *titles = @[@"Forward", @"Fileball", @"Infuse", @"SenPlayer"];
        for (NSInteger i = 0; i < titles.count; i++) {
            NSString *title = titles[i];
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(0, i * (btnH + spacing), btnW, btnH);
            btn.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:0.94];
            btn.layer.cornerRadius = 10;
            btn.layer.masksToBounds = NO;
            btn.layer.borderWidth = 0.5;
            btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
            btn.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 2);
            btn.layer.shadowRadius = 4;
            btn.layer.shadowOpacity = 1.0;
            btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
            [btn setTitle:title forState:UIControlStateNormal];

            if ([title isEqualToString:@"Forward"]) {
                [btn setTitleColor:[UIColor colorWithRed:0.05 green:0.45 blue:0.75 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"Fileball"]) {
                [btn setTitleColor:[UIColor colorWithRed:0.15 green:0.52 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"Infuse"]) {
                [btn setTitleColor:[UIColor colorWithRed:0.5 green:0.18 blue:0.62 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"SenPlayer"]) {
                [btn setTitleColor:[UIColor colorWithRed:0.28 green:0.35 blue:0.78 alpha:1.0] forState:UIControlStateNormal];
            }

            [btn addTarget:self action:@selector(btnTouchDown:) forControlEvents:UIControlEventTouchDown];
            [btn addTarget:self action:@selector(btnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            [btn addTarget:self action:@selector(playerBtnTap:) forControlEvents:UIControlEventTouchUpInside];

            [container addSubview:btn];
        }

        UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
        refreshButton.frame = CGRectMake((btnW - refreshD) / 2.0, btnH * 4 + spacing * 4, refreshD, refreshD);
        refreshButton.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:0.94];
        refreshButton.layer.cornerRadius = 14;
        refreshButton.layer.masksToBounds = NO;
        refreshButton.layer.borderWidth = 0.5;
        refreshButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
        refreshButton.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.12].CGColor;
        refreshButton.layer.shadowOffset = CGSizeMake(0, 2);
        refreshButton.layer.shadowRadius = 4;
        refreshButton.layer.shadowOpacity = 1.0;
        refreshButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        [refreshButton setTitle:@"↻" forState:UIControlStateNormal];
        [refreshButton setTitleColor:[UIColor colorWithRed:0.3 green:0.35 blue:0.42 alpha:1.0] forState:UIControlStateNormal];
        [refreshButton addTarget:self action:@selector(btnTouchDown:) forControlEvents:UIControlEventTouchDown];
        [refreshButton addTarget:self action:@selector(btnTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [refreshButton addTarget:self action:@selector(refreshCandidateTap:) forControlEvents:UIControlEventTouchUpInside];

        UILongPressGestureRecognizer *refreshLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleRefreshLongPress:)];
        refreshLongPress.minimumPressDuration = 0.8;
        [refreshButton addGestureRecognizer:refreshLongPress];

        [container addSubview:refreshButton];
        self.refreshButton = refreshButton;
        self.buttonsContainer = container;
    }

    if (self.buttonsContainer.superview != hostWindow) {
        [self.buttonsContainer removeFromSuperview];
        [hostWindow addSubview:self.buttonsContainer];
    }

    [self forceAlignRightEdge];
    [hostWindow bringSubviewToFront:self.buttonsContainer];
}

- (void)btnTouchDown:(UIButton *)btn {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
    [UIView animateWithDuration:0.1 animations:^{
        btn.transform = CGAffineTransformMakeScale(0.92, 0.92);
    }];
}

- (void)btnTouchUp:(UIButton *)btn {
    [UIView animateWithDuration:0.1 animations:^{
        btn.transform = CGAffineTransformIdentity;
    }];
}

- (void)refreshCandidateTap:(UIButton *)sender {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    self.latestMediaUrl = nil;
    [self rotateRefreshIcon];
}

- (void)playerBtnTap:(UIButton *)btn {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    if (!self.latestMediaUrl || self.latestMediaUrl.length == 0) {
        return;
    }

    NSString *encoded = [self.latestMediaUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *scheme = nil;
    NSString *name = btn.currentTitle;

    if ([name isEqualToString:@"Forward"]) {
        scheme = [NSString stringWithFormat:@"forward://play?url=%@", encoded];
    } else if ([name isEqualToString:@"Fileball"]) {
        scheme = [NSString stringWithFormat:@"filebox://play?url=%@", encoded];
    } else if ([name isEqualToString:@"Infuse"]) {
        scheme = [NSString stringWithFormat:@"infuse://x-callback-url/play?url=%@", encoded];
    } else if ([name isEqualToString:@"SenPlayer"]) {
        scheme = [NSString stringWithFormat:@"senplayer://x-callback-url/play?url=%@", encoded];
    }

    if (scheme) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:scheme] options:@{} completionHandler:nil];
    }
}

- (void)showButtonsWithAnimation {
    UIView *container = self.buttonsContainer;
    if (!container) {
        return;
    }

    UIWindow *hostWindow = [self findHostKeyWindow];
    if (hostWindow && container.superview != hostWindow) {
        [container removeFromSuperview];
        [hostWindow addSubview:container];
    }

    [self forceAlignRightEdge];

    if (hostWindow) {
        [hostWindow bringSubviewToFront:container];
    }

    if (container.hidden || container.alpha < 0.05) {
        container.hidden = NO;
        container.transform = CGAffineTransformMakeTranslation(40, 0);
        [UIView animateWithDuration:0.3 delay:0.05 usingSpringWithDamping:0.8 initialSpringVelocity:0.6 options:0 animations:^{
            container.alpha = 1.0;
            container.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)hideButtonsWithAnimation {
    UIView *container = self.buttonsContainer;
    if (!container || container.hidden) {
        return;
    }
    [UIView animateWithDuration:0.25 animations:^{
        container.alpha = 0.0;
        container.transform = CGAffineTransformMakeTranslation(40, 0);
    } completion:^(BOOL finished) {
        container.hidden = YES;
        container.transform = CGAffineTransformIdentity;
    }];
}

- (void)onPanContainer:(UIPanGestureRecognizer *)pan {
    UIView *container = self.buttonsContainer;
    UIView *superView = container.superview;
    if (!superView) {
        return;
    }

    CGPoint translation = [pan translationInView:superView];
    CGPoint center = container.center;
    center.y += translation.y;
    container.center = center;
    [pan setTranslation:CGPointMake(0.0, 0.0) inView:superView];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat screenH = superView.bounds.size.height;
        CGFloat h = container.bounds.size.height;
        CGFloat safeY = MIN(MAX(center.y, 30 + h / 2.0), screenH - 30 - h / 2.0);

        [UIView animateWithDuration:0.2 animations:^{
            container.center = CGPointMake(container.center.x, safeY);
        } completion:^(BOOL finished) {
            CGFloat ratio = safeY / screenH;
            [self savePositionRatio:ratio];
        }];
    }
}

@end

static void SwizzleMethod(Class cls, SEL origSel, SEL swizzledSel) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
    if (!origMethod || !swizzledMethod) {
        return;
    }
    BOOL didAdd = class_addMethod(cls, origSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAdd) {
        class_replaceMethod(cls, swizzledSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizzledMethod);
    }
}

static void SwizzleClassMethod(Class cls, SEL origSel, SEL swizzledSel) {
    Method origMethod = class_getClassMethod(cls, origSel);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSel);
    if (!origMethod || !swizzledMethod) {
        return;
    }
    Class metaClass = object_getClass((id)cls);
    BOOL didAdd = class_addMethod(metaClass, origSel, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (didAdd) {
        class_replaceMethod(metaClass, swizzledSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, swizzledMethod);
    }
}

@interface NSURL (SnifferProbe)
@end

@implementation NSURL (SnifferProbe)

+ (instancetype)sniff_URLWithString:(NSString *)URLString {
    NSURL *result = [self sniff_URLWithString:URLString];
    if (result.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:result.absoluteString];
    }
    return result;
}

+ (instancetype)sniff_URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
    NSURL *result = [self sniff_URLWithString:URLString relativeToURL:baseURL];
    if (result.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:result.absoluteString];
    }
    return result;
}

- (instancetype)sniff_initWithString:(NSString *)URLString {
    NSURL *result = [self sniff_initWithString:URLString];
    if (result.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:result.absoluteString];
    }
    return result;
}

- (instancetype)sniff_initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
    NSURL *result = [self sniff_initWithString:URLString relativeToURL:baseURL];
    if (result.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:result.absoluteString];
    }
    return result;
}

@end

@interface WKWebView (Sniffer)
@end

@implementation WKWebView (Sniffer)

- (instancetype)sniff_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (configuration) {
        NSString *jsCode = @"(function(){\
            function postUrl(u){\
                try{\
                    if(!u||typeof u!=='string')return;\
                    if(u.indexOf('blob:')===0||u.indexOf('data:')===0)return;\
                    var abs=u;\
                    try{abs=new URL(u,location.href).href;}catch(e){}\
                    try{window.webkit.messageHandlers.SnifferBridge.postMessage(abs);}catch(e){}\
                }catch(e){}\
            }\
            function check(){\
                try{\
                    var els=document.querySelectorAll('video, audio, source');\
                    for(var i=0;i<els.length;i++){\
                        if(els[i].src)postUrl(els[i].src);\
                        if(els[i].currentSrc)postUrl(els[i].currentSrc);\
                    }\
                }catch(e){}\
            }\
            check();\
            setInterval(check,800);\
            var origOpen=XMLHttpRequest.prototype.open;\
            XMLHttpRequest.prototype.open=function(m,u){\
                postUrl(u);\
                return origOpen.apply(this,arguments);\
            };\
            if(window.fetch){\
                var origFetch=window.fetch;\
                window.fetch=function(input,init){\
                    try{\
                        if(typeof input==='string'){postUrl(input);}\
                        else if(input&&input.url){postUrl(input.url);}\
                    }catch(e){}\
                    return origFetch.apply(this,arguments);\
                };\
            }\
            if(window.HTMLMediaElement&&HTMLMediaElement.prototype.play){\
                var origPlay=HTMLMediaElement.prototype.play;\
                HTMLMediaElement.prototype.play=function(){\
                    try{\
                        if(this.src)postUrl(this.src);\
                        if(this.currentSrc)postUrl(this.currentSrc);\
                    }catch(e){}\
                    return origPlay.apply(this,arguments);\
                };\
            }\
        })();";

        WKUserScript *script = [[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
        [configuration.userContentController addUserScript:script];

        @try {
            [configuration.userContentController addScriptMessageHandler:[SnifferManager sharedManager].scriptBridge name:@"SnifferBridge"];
        } @catch (NSException *e) {}
    }
    return [self sniff_initWithFrame:frame configuration:configuration];
}

- (WKNavigation *)sniff_loadRequest:(NSURLRequest *)request {
    if (request.URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:request.URL.absoluteString];
    }
    return [self sniff_loadRequest:request];
}

@end

@interface AVAsset (Sniffer)
@end

@implementation AVAsset (Sniffer)

+ (instancetype)sniff_assetWithURL:(NSURL *)URL {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_assetWithURL:URL];
}

@end

@interface AVPlayer (Sniffer)
@end

@implementation AVPlayer (Sniffer)

+ (instancetype)sniff_playerWithURL:(NSURL *)URL {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_playerWithURL:URL];
}

+ (instancetype)sniff_playerWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u.absoluteString) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_playerWithPlayerItem:item];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

- (instancetype)sniff_initWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u.absoluteString) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_initWithPlayerItem:item];
}

- (void)sniff_replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u.absoluteString) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    [self sniff_replaceCurrentItemWithPlayerItem:item];
}

@end

@interface AVPlayerItem (Sniffer)
@end

@implementation AVPlayerItem (Sniffer)

+ (instancetype)sniff_playerItemWithURL:(NSURL *)URL {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_playerItemWithURL:URL];
}

+ (instancetype)sniff_playerItemWithAsset:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)asset).URL;
        if (u.absoluteString) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_playerItemWithAsset:asset];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

- (instancetype)sniff_initWithAsset:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)asset).URL;
        if (u.absoluteString) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_initWithAsset:asset];
}

@end

@interface AVURLAsset (Sniffer)
@end

@implementation AVURLAsset (Sniffer)

+ (instancetype)sniff_URLAssetWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_URLAssetWithURL:URL options:options];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL options:options];
}

@end

@interface ThirdPartySniffer : NSObject
@end

@implementation ThirdPartySniffer

- (instancetype)sniff_ijk_initWithContentURL:(NSURL *)aUrl withOptions:(id)options {
    if (aUrl.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:aUrl.absoluteString];
    }
    return [self sniff_ijk_initWithContentURL:aUrl withOptions:options];
}

- (instancetype)sniff_ijk_initWithContentURLString:(NSString *)aUrlStr withOptions:(id)options {
    if (aUrlStr) {
        [[SnifferManager sharedManager] captureUrl:aUrlStr];
    }
    return [self sniff_ijk_initWithContentURLString:aUrlStr withOptions:options];
}

- (void)sniff_ali_setUrl:(NSString *)url {
    if (url) {
        [[SnifferManager sharedManager] captureUrl:url];
    }
    [self sniff_ali_setUrl:url];
}

- (int)sniff_txvod_startPlay:(NSString *)url {
    if (url) {
        [[SnifferManager sharedManager] captureUrl:url];
    }
    return [self sniff_txvod_startPlay:url];
}

- (int)sniff_txvod_startVodPlay:(NSString *)url {
    if (url) {
        [[SnifferManager sharedManager] captureUrl:url];
    }
    return [self sniff_txvod_startVodPlay:url];
}

- (int)sniff_txlive_startPlay:(NSString *)url type:(int)playType {
    if (url) {
        [[SnifferManager sharedManager] captureUrl:url];
    }
    return [self sniff_txlive_startPlay:url type:playType];
}

+ (instancetype)sniff_pl_playerWithURL:(NSURL *)URL option:(id)option {
    if (URL.absoluteString) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_pl_playerWithURL:URL option:option];
}

@end

static void HookThirdParty(NSString *className, SEL origSel, SEL dummySel) {
    Class cls = NSClassFromString(className);
    if (!cls) {
        return;
    }
    Method dummy = class_getInstanceMethod([ThirdPartySniffer class], dummySel);
    Method orig = class_getInstanceMethod(cls, origSel);
    if (!dummy || !orig) {
        return;
    }
    class_addMethod(cls, dummySel, method_getImplementation(dummy), method_getTypeEncoding(dummy));
    SwizzleMethod(cls, origSel, dummySel);
}

static void HookThirdPartyClassMethod(NSString *className, SEL origSel, SEL dummySel) {
    Class cls = NSClassFromString(className);
    if (!cls) {
        return;
    }
    Method dummy = class_getClassMethod([ThirdPartySniffer class], dummySel);
    Method orig = class_getClassMethod(cls, origSel);
    if (!dummy || !orig) {
        return;
    }
    Class metaClass = object_getClass((id)cls);
    class_addMethod(metaClass, dummySel, method_getImplementation(dummy), method_getTypeEncoding(dummy));
    SwizzleClassMethod(cls, origSel, dummySel);
}

__attribute__((constructor)) static void SnifferInit(void) {
    SwizzleClassMethod([NSURL class], @selector(URLWithString:), @selector(sniff_URLWithString:));
    SwizzleClassMethod([NSURL class], @selector(URLWithString:relativeToURL:), @selector(sniff_URLWithString:relativeToURL:));
    SwizzleMethod([NSURL class], @selector(initWithString:), @selector(sniff_initWithString:));
    SwizzleMethod([NSURL class], @selector(initWithString:relativeToURL:), @selector(sniff_initWithString:relativeToURL:));

    SwizzleMethod([WKWebView class], @selector(initWithFrame:configuration:), @selector(sniff_initWithFrame:configuration:));
    SwizzleMethod([WKWebView class], @selector(loadRequest:), @selector(sniff_loadRequest:));

    SwizzleClassMethod([AVAsset class], @selector(assetWithURL:), @selector(sniff_assetWithURL:));

    SwizzleClassMethod([AVPlayer class], @selector(playerWithURL:), @selector(sniff_playerWithURL:));
    SwizzleClassMethod([AVPlayer class], @selector(playerWithPlayerItem:), @selector(sniff_playerWithPlayerItem:));
    SwizzleMethod([AVPlayer class], @selector(initWithURL:), @selector(sniff_initWithURL:));
    SwizzleMethod([AVPlayer class], @selector(initWithPlayerItem:), @selector(sniff_initWithPlayerItem:));
    SwizzleMethod([AVPlayer class], @selector(replaceCurrentItemWithPlayerItem:), @selector(sniff_replaceCurrentItemWithPlayerItem:));

    SwizzleClassMethod([AVPlayerItem class], @selector(playerItemWithURL:), @selector(sniff_playerItemWithURL:));
    SwizzleClassMethod([AVPlayerItem class], @selector(playerItemWithAsset:), @selector(sniff_playerItemWithAsset:));
    SwizzleMethod([AVPlayerItem class], @selector(initWithURL:), @selector(sniff_initWithURL:));
    SwizzleMethod([AVPlayerItem class], @selector(initWithAsset:), @selector(sniff_initWithAsset:));

    SwizzleClassMethod([AVURLAsset class], @selector(URLAssetWithURL:options:), @selector(sniff_URLAssetWithURL:options:));
    SwizzleMethod([AVURLAsset class], @selector(initWithURL:options:), @selector(sniff_initWithURL:options:));

    HookThirdParty(@"IJKFFMoviePlayerController", @selector(initWithContentURL:withOptions:), @selector(sniff_ijk_initWithContentURL:withOptions:));
    HookThirdParty(@"IJKFFMoviePlayerController", @selector(initWithContentURLString:withOptions:), @selector(sniff_ijk_initWithContentURLString:withOptions:));
    HookThirdParty(@"AliPlayer", @selector(setUrl:), @selector(sniff_ali_setUrl:));
    HookThirdParty(@"TXVodPlayer", @selector(startPlay:), @selector(sniff_txvod_startPlay:));
    HookThirdParty(@"TXVodPlayer", @selector(startVodPlay:), @selector(sniff_txvod_startVodPlay:));
    HookThirdParty(@"TXLivePlayer", @selector(startPlay:type:), @selector(sniff_txlive_startPlay:type:));
    HookThirdPartyClassMethod(@"PLPlayer", @selector(playerWithURL:option:), @selector(sniff_pl_playerWithURL:option:));

    [[SnifferManager sharedManager] registerNotifications];
}
