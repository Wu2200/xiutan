#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

@class SnifferOverlayWindow;
@class SnifferScriptBridge;
@class SnifferMiniPanelView;

@interface SnifferMediaModel : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, assign) BOOL isMedia;
@end

@implementation SnifferMediaModel
@end

@interface SnifferScriptBridge : NSObject <WKScriptMessageHandler>
@end

@interface SnifferMiniPanelView : UIView <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIButton *mediaTabBtn;
@property (nonatomic, strong) UIButton *allTabBtn;
@property (nonatomic, assign) BOOL showAll;
- (void)refreshList;
@end

@interface SnifferRootViewController : UIViewController
@end

@interface SnifferOverlayWindow : UIWindow
@property (nonatomic, strong) SnifferMiniPanelView *panelView;
@property (nonatomic, strong) UIButton *floatingButton;
@end

@interface SnifferManager : NSObject
@property (nonatomic, strong) NSMutableArray<SnifferMediaModel *> *mediaList;
@property (nonatomic, strong) NSMutableSet<NSString *> *mediaSet;
@property (nonatomic, strong) NSMutableArray<SnifferMediaModel *> *allList;
@property (nonatomic, strong) NSMutableSet<NSString *> *allSet;
@property (nonatomic, strong) SnifferOverlayWindow *overlayWindow;
@property (nonatomic, strong) SnifferScriptBridge *scriptBridge;
+ (instancetype)sharedManager;
- (void)captureUrl:(NSString *)urlStr;
- (void)importFromClipboard;
- (void)setupFloatingUI;
- (void)clearMedia;
- (void)registerNotifications;
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
            UIButton *btn = win.floatingButton;
            if (btn) {
                CGFloat btnW = btn.frame.size.width;
                CGFloat btnH = btn.frame.size.height;
                CGFloat safeX = MIN(MAX(btn.frame.origin.x, 12), size.width - btnW - 12);
                CGFloat safeY = MIN(MAX(btn.frame.origin.y, 40), size.height - btnH - 40);
                btn.frame = CGRectMake(safeX, safeY, btnW, btnH);
            }
            if (win.panelView && !win.panelView.hidden) {
                win.panelView.hidden = YES;
            }
        }
    } completion:nil];
}
@end

@implementation SnifferOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.panelView && !self.panelView.hidden) {
        CGPoint panelPoint = [self convertPoint:point toView:self.panelView];
        if ([self.panelView pointInside:panelPoint withEvent:event]) {
            return [super hitTest:point withEvent:event];
        }
        CGPoint btnPoint = [self convertPoint:point toView:self.floatingButton];
        if ([self.floatingButton pointInside:btnPoint withEvent:event]) {
            return [super hitTest:point withEvent:event];
        }
        self.panelView.hidden = YES;
        return nil;
    }
    UIView *view = [super hitTest:point withEvent:event];
    if (view == self || view == self.rootViewController.view) {
        return nil;
    }
    return view;
}
@end

@implementation SnifferScriptBridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSString class]]) {
        [[SnifferManager sharedManager] captureUrl:(NSString *)message.body];
    } else if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSString *url = message.body[@"url"];
        if (url) {
            [[SnifferManager sharedManager] captureUrl:url];
        }
    }
}
@end

@interface SnifferMiniCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *urlLabel;
@property (nonatomic, strong) UIScrollView *btnScrollView;
@property (nonatomic, strong) UIStackView *btnStack;
@property (nonatomic, copy) void (^actionBlock)(NSString *name);
- (void)updateWithModel:(SnifferMediaModel *)model index:(NSInteger)index;
@end

@implementation SnifferMiniCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, 286, 16)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:12];
        _titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0];

        _urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 23, 286, 14)];
        _urlLabel.font = [UIFont systemFontOfSize:10];
        _urlLabel.textColor = [UIColor colorWithRed:0.45 green:0.48 blue:0.52 alpha:1.0];
        _urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

        _btnScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(12, 40, 286, 24)];
        _btnScrollView.showsHorizontalScrollIndicator = NO;

        _btnStack = [[UIStackView alloc] initWithFrame:_btnScrollView.bounds];
        _btnStack.axis = UILayoutConstraintAxisHorizontal;
        _btnStack.spacing = 6;
        _btnStack.alignment = UIStackViewAlignmentCenter;

        [_btnScrollView addSubview:_btnStack];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_urlLabel];
        [self.contentView addSubview:_btnScrollView];

        NSArray *names = @[@"复制", @"Forward", @"Fileball", @"Infuse", @"SenPlayer"];
        for (NSString *name in names) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            [btn setTitle:name forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
            btn.layer.cornerRadius = 5;
            btn.layer.masksToBounds = YES;
            btn.contentEdgeInsets = UIEdgeInsetsMake(3, 8, 3, 8);

            if ([name isEqualToString:@"复制"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.25 green:0.26 blue:0.28 alpha:1.0] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Forward"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.86 green:0.94 blue:0.98 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.05 green:0.45 blue:0.75 alpha:1.0] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Fileball"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.88 green:0.95 blue:0.88 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.15 green:0.52 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Infuse"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.94 green:0.88 blue:0.96 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.5 green:0.18 blue:0.62 alpha:1.0] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"SenPlayer"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.9 green:0.91 blue:0.98 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.28 green:0.35 blue:0.78 alpha:1.0] forState:UIControlStateNormal];
            }

            [btn addTarget:self action:@selector(btnTap:) forControlEvents:UIControlEventTouchUpInside];
            [_btnStack addArrangedSubview:btn];
        }
    }
    return self;
}

- (void)btnTap:(UIButton *)btn {
    if (self.actionBlock) {
        self.actionBlock(btn.currentTitle);
    }
}

- (void)updateWithModel:(SnifferMediaModel *)model index:(NSInteger)index {
    NSURL *u = [NSURL URLWithString:model.url];
    NSString *host = u.host;
    if (host.length == 0) {
        host = @"未知来源";
    }
    self.titleLabel.text = [NSString stringWithFormat:@"%ld. %@", (long)(index + 1), host];
    self.urlLabel.text = model.url;
}

@end

@implementation SnifferMiniPanelView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 16;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIView *tintOverlay = [[UIView alloc] initWithFrame:self.bounds];
        tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintOverlay.backgroundColor = [UIColor colorWithRed:0.98 green:0.97 blue:0.95 alpha:0.8];
        [self addSubview:tintOverlay];

        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 36)];
        header.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.4];
        [self addSubview:header];

        _mediaTabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _mediaTabBtn.frame = CGRectMake(10, 5, 66, 26);
        _mediaTabBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        _mediaTabBtn.layer.cornerRadius = 13;
        _mediaTabBtn.layer.masksToBounds = YES;
        [_mediaTabBtn addTarget:self action:@selector(mediaTabTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:_mediaTabBtn];

        _allTabBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _allTabBtn.frame = CGRectMake(82, 5, 66, 26);
        _allTabBtn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
        _allTabBtn.layer.cornerRadius = 13;
        _allTabBtn.layer.masksToBounds = YES;
        [_allTabBtn addTarget:self action:@selector(allTabTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:_allTabBtn];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        closeBtn.frame = CGRectMake(frame.size.width - 48, 6, 40, 24);
        [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        [closeBtn setTitleColor:[UIColor colorWithRed:0.45 green:0.48 blue:0.52 alpha:1.0] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closeTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:closeBtn];

        UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        clearBtn.frame = CGRectMake(frame.size.width - 94, 6, 40, 24);
        [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
        clearBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        clearBtn.setTitleColor:[UIColor colorWithRed:0.45 green:0.48 blue:0.52 alpha:1.0] forState:UIControlStateNormal];
        [clearBtn addTarget:self action:@selector(clearTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:clearBtn];

        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 36, frame.size.width, frame.size.height - 36) style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorColor = [UIColor colorWithWhite:0.0 alpha:0.06];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.rowHeight = 70;
        [_tableView registerClass:[SnifferMiniCell class] forCellReuseIdentifier:@"Cell"];
        [self addSubview:_tableView];

        _emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 72, frame.size.width, 40)];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.textColor = [UIColor colorWithRed:0.5 green:0.52 blue:0.55 alpha:1.0];
        _emptyLabel.font = [UIFont systemFontOfSize:11];
        [self addSubview:_emptyLabel];

        _showAll = NO;
        [self refreshList];
    }
    return self;
}

- (void)mediaTabTap {
    self.showAll = NO;
    [self refreshList];
}

- (void)allTabTap {
    self.showAll = YES;
    [self refreshList];
}

- (void)closeTap {
    self.hidden = YES;
}

- (void)clearTap {
    [[SnifferManager sharedManager] clearMedia];
    [self refreshList];
}

- (void)refreshList {
    SnifferManager *mgr = [SnifferManager sharedManager];
    NSArray *data = self.showAll ? mgr.allList : mgr.mediaList;

    [self.mediaTabBtn setTitle:[NSString stringWithFormat:@"媒体 %lu", (unsigned long)mgr.mediaList.count] forState:UIControlStateNormal];
    [self.allTabBtn setTitle:[NSString stringWithFormat:@"全部 %lu", (unsigned long)mgr.allList.count] forState:UIControlStateNormal];

    UIColor *activeBg = [UIColor colorWithRed:0.82 green:0.9 blue:0.99 alpha:1.0];
    UIColor *activeText = [UIColor colorWithRed:0.08 green:0.4 blue:0.8 alpha:1.0];
    UIColor *idleBg = [UIColor colorWithWhite:1.0 alpha:0.45];
    UIColor *idleText = [UIColor colorWithRed:0.45 green:0.48 blue:0.52 alpha:1.0];

    self.mediaTabBtn.backgroundColor = self.showAll ? idleBg : activeBg;
    [self.mediaTabBtn setTitleColor:self.showAll ? idleText : activeText forState:UIControlStateNormal];
    self.allTabBtn.backgroundColor = self.showAll ? activeBg : idleBg;
    [self.allTabBtn setTitleColor:self.showAll ? activeText : idleText forState:UIControlStateNormal];

    BOOL empty = (data.count == 0);
    self.emptyLabel.text = self.showAll ? @"暂无任何请求记录" : @"暂无媒体资源";
    self.emptyLabel.hidden = !empty;
    self.tableView.hidden = empty;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SnifferManager *mgr = [SnifferManager sharedManager];
    return self.showAll ? mgr.allList.count : mgr.mediaList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SnifferManager *mgr = [SnifferManager sharedManager];
    NSArray *data = self.showAll ? mgr.allList : mgr.mediaList;
    SnifferMiniCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    SnifferMediaModel *model = data[indexPath.row];
    [cell updateWithModel:model index:indexPath.row];

    cell.actionBlock = ^(NSString *actionName) {
        if ([actionName isEqualToString:@"复制"]) {
            [UIPasteboard generalPasteboard].string = model.url;
            return;
        }

        NSString *encoded = [model.url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *scheme = nil;

        if ([actionName isEqualToString:@"Forward"]) {
            scheme = [NSString stringWithFormat:@"forward://play?url=%@", encoded];
        } else if ([actionName isEqualToString:@"Fileball"]) {
            scheme = [NSString stringWithFormat:@"filebox://play?url=%@", encoded];
        } else if ([actionName isEqualToString:@"Infuse"]) {
            scheme = [NSString stringWithFormat:@"infuse://x-callback-url/play?url=%@", encoded];
        } else if ([actionName isEqualToString:@"SenPlayer"]) {
            scheme = [NSString stringWithFormat:@"senplayer://x-callback-url/play?url=%@", encoded];
        }

        if (scheme) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:scheme] options:@{} completionHandler:nil];
        }
    };

    return cell;
}

@end

@implementation SnifferManager

+ (instancetype)sharedManager {
    static SnifferManager *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[SnifferManager alloc] init];
        inst.mediaList = [NSMutableArray array];
        inst.mediaSet = [NSMutableSet set];
        inst.allList = [NSMutableArray array];
        inst.allSet = [NSMutableSet set];
        inst.scriptBridge = [[SnifferScriptBridge alloc] init];
    });
    return inst;
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
    });
}

- (void)onActive {
    [self setupFloatingUI];
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

    dispatch_async(dispatch_get_main_queue(), ^{
        if (![self.allSet containsObject:urlStr]) {
            [self.allSet addObject:urlStr];
            SnifferMediaModel *m = [[SnifferMediaModel alloc] init];
            m.url = urlStr;
            m.isMedia = [self isMediaUrl:urlStr];
            [self.allList insertObject:m atIndex:0];
            if (self.allList.count > 200) {
                SnifferMediaModel *old = self.allList.lastObject;
                if (old.url) {
                    [self.allSet removeObject:old.url];
                }
                [self.allList removeLastObject];
            }
        }

        if ([self isMediaUrl:urlStr] && ![self.mediaSet containsObject:urlStr]) {
            [self.mediaSet addObject:urlStr];
            SnifferMediaModel *m = [[SnifferMediaModel alloc] init];
            m.url = urlStr;
            m.isMedia = YES;
            [self.mediaList insertObject:m atIndex:0];
        }

        if (!self.overlayWindow) {
            [self setupFloatingUI];
        }

        NSString *title = [NSString stringWithFormat:@"🎬 %lu/%lu", (unsigned long)self.mediaList.count, (unsigned long)self.allList.count];
        [self.overlayWindow.floatingButton setTitle:title forState:UIControlStateNormal];

        if (self.overlayWindow.panelView && !self.overlayWindow.panelView.hidden) {
            [self.overlayWindow.panelView refreshList];
        }
    });
}

- (void)clearMedia {
    [self.mediaList removeAllObjects];
    [self.mediaSet removeAllObjects];
    [self.allList removeAllObjects];
    [self.allSet removeAllObjects];
    [self.overlayWindow.floatingButton setTitle:@"🎬 0/0" forState:UIControlStateNormal];
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

            SnifferRootViewController *rootVC = [[SnifferRootViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = rootVC;

            CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenH = [UIScreen mainScreen].bounds.size.height;

            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(screenW - 102, screenH - 220, 92, 36);
            btn.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.97 alpha:0.92];
            btn.layer.cornerRadius = 18;
            btn.layer.masksToBounds = YES;
            btn.layer.borderWidth = 0.5;
            btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
            btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
            [btn setTitle:@"🎬 0/0" forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor colorWithRed:0.2 green:0.22 blue:0.25 alpha:1.0] forState:UIControlStateNormal];
            [btn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
            [btn addGestureRecognizer:pan];

            self.overlayWindow.floatingButton = btn;
            [rootVC.view addSubview:btn];

            SnifferMiniPanelView *panel = [[SnifferMiniPanelView alloc] initWithFrame:CGRectMake(screenW - 322, screenH - 470, 312, 240)];
            panel.hidden = YES;
            self.overlayWindow.panelView = panel;
            [rootVC.view addSubview:panel];
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

- (void)onPan:(UIPanGestureRecognizer *)pan {
    UIView *btn = self.overlayWindow.floatingButton;
    UIView *superView = btn.superview;
    CGPoint translation = [pan translationInView:superView];
    CGPoint center = btn.center;
    center.x += translation.x;
    center.y += translation.y;
    btn.center = center;
    [pan setTranslation:CGPointMake(0.0, 0.0) inView:superView];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat screenW = superView.bounds.size.width;
        CGFloat screenH = superView.bounds.size.height;
        CGFloat btnW = btn.frame.size.width;
        CGFloat btnH = btn.frame.size.height;

        CGFloat targetX = (center.x > screenW / 2.0) ? (screenW - btnW / 2.0 - 10) : (btnW / 2.0 + 10);
        CGFloat targetY = MIN(MAX(center.y, 40 + btnH / 2.0), screenH - 40 - btnH / 2.0);

        [UIView animateWithDuration:0.25 animations:^{
            btn.center = CGPointMake(targetX, targetY);
        }];
    }
}

- (void)togglePanel {
    SnifferMiniPanelView *panel = self.overlayWindow.panelView;
    if (!panel) {
        return;
    }

    if (panel.hidden) {
        CGRect btnFrame = self.overlayWindow.floatingButton.frame;
        CGFloat panelW = panel.frame.size.width;
        CGFloat panelH = panel.frame.size.height;
        CGFloat screenW = self.overlayWindow.rootViewController.view.bounds.size.width;
        CGFloat screenH = self.overlayWindow.rootViewController.view.bounds.size.height;

        CGFloat panelX = (btnFrame.origin.x + btnFrame.size.width / 2.0 > screenW / 2.0) ? (screenW - panelW - 10) : 10;
        CGFloat panelY = btnFrame.origin.y - panelH - 8;
        if (panelY < 40) {
            panelY = btnFrame.origin.y + btnFrame.size.height + 8;
        }
        if (panelY + panelH > screenH - 30) {
            panelY = screenH - panelH - 30;
        }

        panel.frame = CGRectMake(panelX, panelY, panelW, panelH);
        [panel refreshList];
        panel.alpha = 0.0;
        panel.hidden = NO;
        [UIView animateWithDuration:0.2 animations:^{
            panel.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            panel.alpha = 0.0;
        } completion:^(BOOL finished) {
            panel.hidden = YES;
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
    if (URLString) {
        [[SnifferManager sharedManager] captureUrl:URLString];
    }
    return [self sniff_URLWithString:URLString];
}

+ (instancetype)sniff_URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
    if (URLString) {
        [[SnifferManager sharedManager] captureUrl:URLString];
    }
    return [self sniff_URLWithString:URLString relativeToURL:baseURL];
}

- (instancetype)sniff_initWithString:(NSString *)URLString {
    if (URLString) {
        [[SnifferManager sharedManager] captureUrl:URLString];
    }
    return [self sniff_initWithString:URLString];
}

- (instancetype)sniff_initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
    if (URLString) {
        [[SnifferManager sharedManager] captureUrl:URLString];
    }
    return [self sniff_initWithString:URLString relativeToURL:baseURL];
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
    if (request.URL) {
        [[SnifferManager sharedManager] captureUrl:request.URL.absoluteString];
    }
    return [self sniff_loadRequest:request];
}

@end

@interface AVAsset (Sniffer)
@end

@implementation AVAsset (Sniffer)

+ (instancetype)sniff_assetWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_assetWithURL:URL];
}

@end

@interface AVPlayer (Sniffer)
@end

@implementation AVPlayer (Sniffer)

+ (instancetype)sniff_playerWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_playerWithURL:URL];
}

+ (instancetype)sniff_playerWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_playerWithPlayerItem:item];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

- (instancetype)sniff_initWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_initWithPlayerItem:item];
}

- (void)sniff_replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {
    if (item && [item.asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)item.asset).URL;
        if (u) {
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
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_playerItemWithURL:URL];
}

+ (instancetype)sniff_playerItemWithAsset:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)asset).URL;
        if (u) {
            [[SnifferManager sharedManager] captureUrl:u.absoluteString];
        }
    }
    return [self sniff_playerItemWithAsset:asset];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

- (instancetype)sniff_initWithAsset:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *u = ((AVURLAsset *)asset).URL;
        if (u) {
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
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_URLAssetWithURL:URL options:options];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    if (URL) {
        [[SnifferManager sharedManager] captureUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL options:options];
}

@end

@interface ThirdPartySniffer : NSObject
@end

@implementation ThirdPartySniffer

- (instancetype)sniff_ijk_initWithContentURL:(NSURL *)aUrl withOptions:(id)options {
    if (aUrl) {
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
    if (URL) {
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
