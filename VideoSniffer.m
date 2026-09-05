#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

@class SnifferOverlayWindow;
@class SnifferScriptBridge;

@interface SnifferRootViewController : UIViewController
@end

@interface SnifferOverlayWindow : UIWindow
@property (nonatomic, strong) UIView *buttonsContainer;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, assign) BOOL isSuspendedHidden;
@end

@interface SnifferScriptBridge : NSObject <WKScriptMessageHandler>
@end

@interface SnifferManager : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *latestMediaUrl;
@property (nonatomic, assign) NSInteger latestMediaScore;
@property (nonatomic, assign) BOOL acceptsNextMediaUrl;
@property (nonatomic, strong) SnifferOverlayWindow *overlayWindow;
@property (nonatomic, strong) SnifferScriptBridge *scriptBridge;
@property (nonatomic, weak) UIViewController *lastActiveVC;
@property (nonatomic, strong) UILongPressGestureRecognizer *toggleGesture;
@property (nonatomic, strong) NSArray<UIButton *> *playerButtons;
+ (instancetype)sharedManager;
- (void)captureUrl:(NSString *)urlStr;
- (void)setupFloatingUI;
- (void)clearMedia;
- (void)registerNotifications;
- (void)handleHostPageChanged:(UIViewController *)vc;
- (void)savePositionRatio:(CGFloat)ratio;
- (CGFloat)loadPositionRatio;
@end

@implementation SnifferRootViewController
- (BOOL)shouldAutorotate {
    return YES;
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        SnifferOverlayWindow *win = (SnifferOverlayWindow *)self.view.window;
        if ([win isKindOfClass:[SnifferOverlayWindow class]]) {
            CGFloat ratio = [[SnifferManager sharedManager] loadPositionRatio];
            CGFloat targetCenterY = ratio * size.height;

            UIView *container = win.buttonsContainer;
            if (container) {
                CGFloat w = container.frame.size.width;
                CGFloat h = container.frame.size.height;
                CGFloat safeX = size.width - w - 10;
                CGFloat safeY = MIN(MAX(targetCenterY - h / 2.0, 40), size.height - h - 40);
                container.frame = CGRectMake(safeX, safeY, w, h);
            }
        }
    } completion:nil];
}
@end

@implementation SnifferOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.isSuspendedHidden || !self.buttonsContainer || self.buttonsContainer.hidden || self.buttonsContainer.alpha < 0.05) {
        return nil;
    }
    CGPoint containerPoint = [self convertPoint:point toView:self.buttonsContainer];
    if ([self.buttonsContainer pointInside:containerPoint withEvent:event]) {
        return [super hitTest:point withEvent:event];
    }
    return nil;
}
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
        inst.latestMediaScore = NSIntegerMin;
        inst.acceptsNextMediaUrl = NO;
        inst.scriptBridge = [[SnifferScriptBridge alloc] init];
    });
    return inst;
}

- (void)savePositionRatio:(CGFloat)ratio {
    [[NSUserDefaults standardUserDefaults] setDouble:ratio forKey:@"Sniffer_Buttons_PositionRatio_Y"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CGFloat)loadPositionRatio {
    double ratio = [[NSUserDefaults standardUserDefaults] doubleForKey:@"Sniffer_Buttons_PositionRatio_Y"];
    if (ratio <= 0.05 || ratio >= 0.95) {
        return 0.5;
    }
    return (CGFloat)ratio;
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIWindowDidBecomeVisibleNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIWindowDidBecomeKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIDeviceOrientationDidChangeNotification object:nil];
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UISceneDidActivateNotification object:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupFloatingUI];
        [self attachGlobalToggleGesture];
    });
}

- (void)onActive {
    [self setupFloatingUI];
    [self attachGlobalToggleGesture];
}

- (void)attachGlobalToggleGesture {
    UIWindow *targetWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *w in scene.windows) {
                if (w != self.overlayWindow && !w.hidden) {
                    targetWindow = w;
                    break;
                }
            }
        }
    }
    if (!targetWindow) {
        targetWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    if (!targetWindow || targetWindow == self.overlayWindow) {
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

- (void)handleGlobalToggleGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];

        if (self.overlayWindow.isSuspendedHidden) {
            self.overlayWindow.isSuspendedHidden = NO;
            if (self.latestMediaUrl && self.latestMediaUrl.length > 0) {
                [self showButtonsWithAnimation];
            }
        } else {
            self.overlayWindow.isSuspendedHidden = YES;
            [self hideButtonsWithAnimation];
        }
    }
}

- (void)handleHostPageChanged:(UIViewController *)vc {
    if (!vc) {
        return;
    }
    if ([vc isKindOfClass:[UIAlertController class]] || [vc isKindOfClass:[SnifferRootViewController class]]) {
        return;
    }
    NSString *className = NSStringFromClass([vc class]);
    if ([className hasPrefix:@"UIInput"] || [className hasPrefix:@"_"]) {
        return;
    }

    if (self.lastActiveVC && self.lastActiveVC != vc) {
        [self clearMedia];
    }
    self.lastActiveVC = vc;
    [self attachGlobalToggleGesture];
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
        @"chunk"
    ];
    for (NSString *key in segmentKeys) {
        if ([lower containsString:key]) {
            return YES;
        }
    }
    return NO;
}

- (NSInteger)mediaScoreForUrl:(NSString *)urlStr {
    NSString *lower = [urlStr lowercaseString];
    NSInteger score = 0;

    if ([lower containsString:@".m3u8"] || [lower containsString:@"m3u8?"]) {
        score += 1000;
    } else if ([lower containsString:@".mpd"] || [lower containsString:@"manifest"]) {
        score += 900;
    } else if ([lower containsString:@".mp4"] || [lower containsString:@"videoplayback"]) {
        score += 800;
    } else {
        score += 500;
    }

    if ([lower containsString:@"2160"] || [lower containsString:@"4k"] || [lower containsString:@"uhd"]) {
        score += 500;
    } else if ([lower containsString:@"1440"] || [lower containsString:@"2k"]) {
        score += 400;
    } else if ([lower containsString:@"1080"]) {
        score += 300;
    } else if ([lower containsString:@"720"]) {
        score += 200;
    } else if ([lower containsString:@"540"]) {
        score += 150;
    } else if ([lower containsString:@"480"]) {
        score += 100;
    } else if ([lower containsString:@"360"]) {
        score += 50;
    }

    return score;
}

- (BOOL)isMediaUrl:(NSString *)urlStr {
    NSString *lower = [urlStr lowercaseString];
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
    UIButton *btn = self.overlayWindow.refreshButton;
    if (!btn) {
        return;
    }

    [btn.layer removeAnimationForKey:@"sniffer.refresh.rotation"];
    CABasicAnimation *rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotation.fromValue = @(0.0);
    rotation.toValue = @(M_PI * 6.0);
    rotation.duration = 1.5;
    rotation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [btn.layer addAnimation:rotation forKey:@"sniffer.refresh.rotation"];
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
        NSInteger incomingScore = [self mediaScoreForUrl:urlStr];
        BOOL urlChanged = ![self.latestMediaUrl isEqualToString:urlStr];
        BOOL shouldReplace = NO;

        if (!self.latestMediaUrl || self.latestMediaUrl.length == 0) {
            shouldReplace = YES;
        } else if (self.acceptsNextMediaUrl) {
            shouldReplace = YES;
        } else if (incomingScore > self.latestMediaScore) {
            shouldReplace = YES;
        } else if (incomingScore == self.latestMediaScore && urlChanged) {
            shouldReplace = YES;
        }

        if (!shouldReplace) {
            return;
        }

        self.latestMediaUrl = urlStr;
        self.latestMediaScore = incomingScore;
        self.acceptsNextMediaUrl = NO;

        if (!self.overlayWindow) {
            [self setupFloatingUI];
        }

        if (!self.overlayWindow.isSuspendedHidden) {
            [self showButtonsWithAnimation];
        }

        [self rotateRefreshIcon];
    });
}

- (void)clearMedia {
    self.latestMediaUrl = nil;
    self.latestMediaScore = NSIntegerMin;
    self.acceptsNextMediaUrl = NO;
    [self hideButtonsWithAnimation];
}

- (void)setupFloatingUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)s;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        scene = ws;
                        break;
                    }
                    if (!scene) {
                        scene = ws;
                    }
                }
            }
        }

        if (!self.overlayWindow) {
            if (@available(iOS 13.0, *)) {
                if (scene) {
                    self.overlayWindow = [[SnifferOverlayWindow alloc] initWithWindowScene:scene];
                } else {
                    self.overlayWindow = [[SnifferOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                }
            } else {
                self.overlayWindow = [[SnifferOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            }

            self.overlayWindow.frame = [UIScreen mainScreen].bounds;
            self.overlayWindow.windowLevel = CGFLOAT_MAX - 100.0;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            self.overlayWindow.isSuspendedHidden = NO;

            SnifferRootViewController *rootVC = [[SnifferRootViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = rootVC;

            CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
            CGFloat ratioY = [self loadPositionRatio];
            CGFloat targetCenterY = ratioY * screenH;

            CGFloat btnW = 82;
            CGFloat btnH = 34;
            CGFloat spacing = 8;
            CGFloat refreshD = 28;
            CGFloat totalH = btnH * 4 + spacing * 3 + refreshD + 10;
            CGFloat containerSafeY = MIN(MAX(targetCenterY - totalH / 2.0, 40), screenH - totalH - 40);

            UIView *container = [[UIView alloc] initWithFrame:CGRectMake(screenW - btnW - 10, containerSafeY, btnW, totalH)];
            container.backgroundColor = [UIColor clearColor];
            container.hidden = YES;
            container.alpha = 0.0;

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanContainer:)];
            [container addGestureRecognizer:pan];

            NSArray *titles = @[@"Forward", @"Fileball", @"Infuse", @"SenPlayer"];
            NSMutableArray<UIButton *> *btnArray = [NSMutableArray array];

            for (NSInteger i = 0; i < titles.count; i++) {
                NSString *title = titles[i];
                UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
                btn.frame = CGRectMake(0, i * (btnH + spacing), btnW, btnH);
                btn.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:0.92];
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
                [btnArray addObject:btn];
            }

            UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
            refreshButton.frame = CGRectMake((btnW - refreshD) / 2.0, btnH * 4 + spacing * 3 + 8, refreshD, refreshD);
            refreshButton.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:0.94];
            refreshButton.layer.cornerRadius = refreshD / 2.0;
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

            [container addSubview:refreshButton];

            self.playerButtons = btnArray;
            self.overlayWindow.buttonsContainer = container;
            self.overlayWindow.refreshButton = refreshButton;
            [rootVC.view addSubview:container];
        } else {
            if (@available(iOS 13.0, *)) {
                if (scene && self.overlayWindow.windowScene != scene) {
                    self.overlayWindow.windowScene = scene;
                }
            }
        }

        self.overlayWindow.hidden = NO;
    });
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

    self.acceptsNextMediaUrl = YES;
    self.latestMediaScore = NSIntegerMin;
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
    UIView *container = self.overlayWindow.buttonsContainer;
    if (!container) {
        return;
    }

    CGFloat screenH = self.overlayWindow.bounds.size.height;
    CGFloat ratio = [self loadPositionRatio];
    CGFloat targetCenterY = ratio * screenH;
    CGFloat h = container.frame.size.height;
    CGFloat safeY = MIN(MAX(targetCenterY - h / 2.0, 40), screenH - h - 40);

    CGRect f = container.frame;
    f.origin.y = safeY;
    f.origin.x = self.overlayWindow.bounds.size.width - f.size.width - 10;
    container.frame = f;

    if (container.hidden || container.alpha < 0.05) {
        container.hidden = NO;
        container.transform = CGAffineTransformMakeTranslation(40, 0);
        [UIView animateWithDuration:0.35 delay:0.05 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:0 animations:^{
            container.alpha = 1.0;
            container.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)hideButtonsWithAnimation {
    UIView *container = self.overlayWindow.buttonsContainer;
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
    UIView *container = self.overlayWindow.buttonsContainer;
    UIView *superView = container.superview;
    CGPoint translation = [pan translationInView:superView];
    CGPoint center = container.center;
    center.y += translation.y;
    container.center = center;
    [pan setTranslation:CGPointMake(0.0, 0.0) inView:superView];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat screenH = superView.bounds.size.height;
        CGFloat h = container.frame.size.height;
        CGFloat targetY = MIN(MAX(center.y, 40 + h / 2.0), screenH - 40 - h / 2.0);

        [UIView animateWithDuration:0.25 animations:^{
            container.center = CGPointMake(container.center.x, targetY);
        } completion:^(BOOL finished) {
            CGFloat ratio = targetY / screenH;
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

@interface UIViewController (SnifferLifecycle)
@end

@implementation UIViewController (SnifferLifecycle)

- (void)sniff_viewDidAppear:(BOOL)animated {
    [self sniff_viewDidAppear:animated];
    [[SnifferManager sharedManager] handleHostPageChanged:self];
}

@end

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
    if (item && [item.asset isKindOfClass:[This request was blocked by Gemini's filters. They can occasionally trigger by mistake on safe coding, security, or biology-related queries. Please try rephrasing your prompt. You can [send feedback](https://ai.google.dev/gemini-api/docs/troubleshooting#file-bug) or read more about [our policies here](https://policies.google.com/terms/generative-ai/use-policy).
