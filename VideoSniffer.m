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
@property (nonatomic, strong) UIButton *roundIdleButton;
@property (nonatomic, strong) UIView *buttonsContainer;
@property (nonatomic, assign) BOOL isSuspendedHidden;
- (void)syncContainerPositionToIdleButton;
- (void)syncIdleButtonPositionToContainer;
@end

@interface SnifferScriptBridge : NSObject <WKScriptMessageHandler>
@end

@interface SnifferManager : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *latestMediaUrl;
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

            UIButton *idleBtn = win.roundIdleButton;
            if (idleBtn) {
                CGFloat btnW = idleBtn.frame.size.width;
                CGFloat btnH = idleBtn.frame.size.height;
                CGFloat safeX = size.width - btnW - 10;
                CGFloat safeY = MIN(MAX(targetCenterY - btnH / 2.0, 40), size.height - btnH - 40);
                idleBtn.frame = CGRectMake(safeX, safeY, btnW, btnH);
            }

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

- (void)syncContainerPositionToIdleButton {
    if (!self.roundIdleButton || !self.buttonsContainer) {
        return;
    }
    CGFloat centerY = self.roundIdleButton.center.y;
    CGFloat screenH = self.bounds.size.height;
    CGFloat h = self.buttonsContainer.frame.size.height;
    CGFloat safeY = MIN(MAX(centerY - h / 2.0, 40), screenH - h - 40);
    CGRect f = self.buttonsContainer.frame;
    f.origin.y = safeY;
    f.origin.x = self.bounds.size.width - f.size.width - 10;
    self.buttonsContainer.frame = f;
}

- (void)syncIdleButtonPositionToContainer {
    if (!self.roundIdleButton || !self.buttonsContainer) {
        return;
    }
    CGFloat centerY = self.buttonsContainer.center.y;
    CGFloat screenH = self.bounds.size.height;
    CGFloat h = self.roundIdleButton.frame.size.height;
    CGFloat safeY = MIN(MAX(centerY - h / 2.0, 40), screenH - h - 40);
    CGRect f = self.roundIdleButton.frame;
    f.origin.y = safeY;
    f.origin.x = self.bounds.size.width - f.size.width - 10;
    self.roundIdleButton.frame = f;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.isSuspendedHidden) {
        return nil;
    }

    if (self.buttonsContainer && !self.buttonsContainer.hidden && self.buttonsContainer.alpha > 0.05) {
        CGPoint containerPoint = [self convertPoint:point toView:self.buttonsContainer];
        if ([self.buttonsContainer pointInside:containerPoint withEvent:event]) {
            return [super hitTest:point withEvent:event];
        }
        return nil;
    }

    if (self.roundIdleButton && !self.roundIdleButton.hidden && self.roundIdleButton.alpha > 0.05) {
        CGPoint btnPoint = [self convertPoint:point toView:self.roundIdleButton];
        if ([self.roundIdleButton pointInside:btnPoint withEvent:event]) {
            return [super hitTest:point withEvent:event];
        }
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
        inst.scriptBridge = [[SnifferScriptBridge alloc] init];
    });
    return inst;
}

- (void)savePositionRatio:(CGFloat)ratio {
    [[NSUserDefaults standardUserDefaults] setDouble:ratio forKey:@"Sniffer_PositionRatio_Y"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (CGFloat)loadPositionRatio {
    double ratio = [[NSUserDefaults standardUserDefaults] doubleForKey:@"Sniffer_PositionRatio_Y"];
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
            } else {
                [self showIdleButtonWithAnimation];
            }
        } else {
            self.overlayWindow.isSuspendedHidden = YES;
            [self hideAllFloatingUI];
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

- (BOOL)isMediaUrl:(NSString *)urlStr {
    NSString *lower = [urlStr lowercaseString];
    NSArray *blackList = @[@".png", @".jpg", @".jpeg", @".gif", @".webp", @".css", @".js", @".svg", @".ico", @".woff", @".ttf"];
    for (NSString *b in blackList) {
        if ([lower containsString:b]) {
            return NO;
        }
    }
    NSArray *keys = @[@"m3u8", @"mp4", @"flv", @"mov", @"mkv", @"webm", @"mpd", @"f4v", @"avi", @"ts", @"playlist", @"manifest", @"videoplayback", @"stream", @"video", @"live", @"vod", @"media", @"play"];
    for (NSString *key in keys) {
        if ([lower containsString:key]) {
            return YES;
        }
    }
    return NO;
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
        self.latestMediaUrl = urlStr;

        if (!self.overlayWindow) {
            [self setupFloatingUI];
        }

        if (!self.overlayWindow.isSuspendedHidden) {
            [self showButtonsWithAnimation];
        }
    });
}

- (void)clearMedia {
    self.latestMediaUrl = nil;
    if (!self.overlayWindow.isSuspendedHidden) {
        [self showIdleButtonWithAnimation];
    } else {
        [self hideAllFloatingUI];
    }
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

            CGFloat idleD = 38;
            CGFloat idleSafeY = MIN(MAX(targetCenterY - idleD / 2.0, 40), screenH - idleD - 40);
            UIButton *idleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            idleBtn.frame = CGRectMake(screenW - idleD - 10, idleSafeY, idleD, idleD);
            idleBtn.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:0.94];
            idleBtn.layer.cornerRadius = idleD / 2.0;
            idleBtn.layer.masksToBounds = NO;
            idleBtn.layer.borderWidth = 0.5;
            idleBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
            idleBtn.layer.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.15].CGColor;
            idleBtn.layer.shadowOffset = CGSizeMake(0, 2);
            idleBtn.layer.shadowRadius = 5;
            idleBtn.layer.shadowOpacity = 1.0;
            idleBtn.titleLabel.font = [UIFont systemFontOfSize:16];
            [idleBtn setTitle:@"🎬" forState:UIControlStateNormal];

            UIPanGestureRecognizer *idlePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPanIdleButton:)];
            [idleBtn addGestureRecognizer:idlePan];

            self.overlayWindow.roundIdleButton = idleBtn;
            [rootVC.view addSubview:idleBtn];

            CGFloat btnW = 82;
            CGFloat btnH = 34;
            CGFloat spacing = 8;
            CGFloat totalH = btnH * 4 + spacing * 3;
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

            self.playerButtons = btnArray;
            self.overlayWindow.buttonsContainer = container;
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
    UIButton *idleBtn = self.overlayWindow.roundIdleButton;
    if (!container) {
        return;
    }

    [self.overlayWindow syncContainerPositionToIdleButton];

    if (idleBtn && !idleBtn.hidden) {
        [UIView animateWithDuration:0.2 animations:^{
            idleBtn.alpha = 0.0;
            idleBtn.transform = CGAffineTransformMakeScale(0.4, 0.4);
        } completion:^(BOOL finished) {
            idleBtn.hidden = YES;
            idleBtn.transform = CGAffineTransformIdentity;
        }];
    }

    if (container.hidden || container.alpha < 0.05) {
        container.hidden = NO;
        container.transform = CGAffineTransformMakeTranslation(40, 0);
        [UIView animateWithDuration:0.35 delay:0.05 usingSpringWithDamping:0.75 initialSpringVelocity:0.6 options:0 animations:^{
            container.alpha = 1.0;
            container.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)showIdleButtonWithAnimation {
    UIView *container = self.overlayWindow.buttonsContainer;
    UIButton *idleBtn = self.overlayWindow.roundIdleButton;

    if (container && !container.hidden) {
        [UIView animateWithDuration:0.2 animations:^{
            container.alpha = 0.0;
            container.transform = CGAffineTransformMakeTranslation(30, 0);
        } completion:^(BOOL finished) {
            container.hidden = YES;
            container.transform = CGAffineTransformIdentity;
        }];
    }

    [self.overlayWindow syncIdleButtonPositionToContainer];

    if (idleBtn) {
        idleBtn.hidden = NO;
        idleBtn.transform = CGAffineTransformMakeScale(0.5, 0.5);
        [UIView animateWithDuration:0.3 delay:0.05 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
            idleBtn.alpha = 1.0;
            idleBtn.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
}

- (void)hideAllFloatingUI {
    UIView *container = self.overlayWindow.buttonsContainer;
    UIButton *idleBtn = self.overlayWindow.roundIdleButton;

    [UIView animateWithDuration:0.2 animations:^{
        if (container) {
            container.alpha = 0.0;
        }
        if (idleBtn) {
            idleBtn.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        if (container) {
            container.hidden = YES;
        }
        if (idleBtn) {
            idleBtn.hidden = YES;
        }
    }];
}

- (void)onPanIdleButton:(UIPanGestureRecognizer *)pan {
    UIView *btn = self.overlayWindow.roundIdleButton;
    UIView *superView = btn.superview;
    CGPoint translation = [pan translationInView:superView];
    CGPoint center = btn.center;
    center.y += translation.y;
    btn.center = center;
    [pan setTranslation:CGPointMake(0.0, 0.0) inView:superView];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat screenH = superView.bounds.size.height;
        CGFloat h = btn.frame.size.height;
        CGFloat targetY = MIN(MAX(center.y, 40 + h / 2.0), screenH - 40 - h / 2.0);

        [UIView animateWithDuration:0.25 animations:^{
            btn.center = CGPointMake(btn.center.x, targetY);
        } completion:^(BOOL finished) {
            CGFloat ratio = targetY / screenH;
            [self savePositionRatio:ratio];
            [self.overlayWindow syncContainerPositionToIdleButton];
        }];
    }
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
            [self.overlayWindow syncIdleButtonPositionToContainer];
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
    SwizzleMethod([UIViewController class], @selector(viewDidAppear:), @selector(sniff_viewDidAppear:));

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
