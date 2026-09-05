#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

@interface SnifferMediaModel : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *title;
@end

@implementation SnifferMediaModel
@end

@interface SnifferScriptBridge : NSObject <WKScriptMessageHandler>
@end

@interface SnifferMiniPanelView : UIView <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UILabel *titleLabel;
- (void)refreshList;
@end

@interface SnifferOverlayWindow : UIWindow
@property (nonatomic, strong) SnifferMiniPanelView *panelView;
@property (nonatomic, strong) UIButton *floatingButton;
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

@interface SnifferManager : NSObject
@property (nonatomic, strong) NSMutableArray<SnifferMediaModel *> *mediaList;
@property (nonatomic, strong) NSMutableSet<NSString *> *urlSet;
@property (nonatomic, strong) SnifferOverlayWindow *overlayWindow;
@property (nonatomic, strong) SnifferScriptBridge *scriptBridge;
+ (instancetype)sharedManager;
- (void)addMediaUrl:(NSString *)urlStr;
- (void)setupFloatingUI;
- (void)clearMedia;
- (void)registerNotifications;
@end

@implementation SnifferScriptBridge
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.body isKindOfClass:[NSString class]]) {
        [[SnifferManager sharedManager] addMediaUrl:(NSString *)message.body];
    } else if ([message.body isKindOfClass:[NSDictionary class]]) {
        NSString *url = message.body[@"url"];
        if (url) {
            [[SnifferManager sharedManager] addMediaUrl:url];
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

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 290, 16)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:12];
        _titleLabel.textColor = [UIColor whiteColor];

        _urlLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 23, 290, 14)];
        _urlLabel.font = [UIFont systemFontOfSize:10];
        _urlLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        _urlLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

        _btnScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 40, 290, 24)];
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
            btn.layer.cornerRadius = 4;
            btn.layer.masksToBounds = YES;
            btn.contentEdgeInsets = UIEdgeInsetsMake(3, 7, 3, 7);

            if ([name isEqualToString:@"复制"]) {
                btn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.8];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Forward"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:0.8 alpha:0.8];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Fileball"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.18 green:0.6 blue:0.25 alpha:0.8];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"Infuse"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.7 alpha:0.8];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else if ([name isEqualToString:@"SenPlayer"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.3 green:0.4 blue:0.85 alpha:0.8];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
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
    self.titleLabel.text = [NSString stringWithFormat:@"资源 %ld", (long)(index + 1)];
    self.urlLabel.text = model.url;
}

@end

@implementation SnifferMiniPanelView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 14;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:blurView];

        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 34)];
        header.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        [self addSubview:header];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 140, 18)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:12];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.text = @"嗅探资源";
        [header addSubview:_titleLabel];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        closeBtn.frame = CGRectMake(frame.size.width - 46, 5, 40, 24);
        [closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        [closeBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closeTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:closeBtn];

        UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        clearBtn.frame = CGRectMake(frame.size.width - 92, 5, 40, 24);
        [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
        clearBtn.titleLabel.font = [UIFont systemFontOfSize:11];
        [clearBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1.0] forState:UIControlStateNormal];
        [clearBtn addTarget:self action:@selector(clearTap) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:clearBtn];

        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 34, frame.size.width, frame.size.height - 34) style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.1];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.rowHeight = 70;
        [_tableView registerClass:[SnifferMiniCell class] forCellReuseIdentifier:@"Cell"];
        [self addSubview:_tableView];

        _emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 70, frame.size.width, 40)];
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        _emptyLabel.font = [UIFont systemFontOfSize:11];
        _emptyLabel.text = @"暂无嗅探资源";
        [self addSubview:_emptyLabel];

        [self refreshList];
    }
    return self;
}

- (void)closeTap {
    self.hidden = YES;
}

- (void)clearTap {
    [[SnifferManager sharedManager] clearMedia];
    [self refreshList];
}

- (void)refreshList {
    BOOL empty = ([SnifferManager sharedManager].mediaList.count == 0);
    self.emptyLabel.hidden = !empty;
    self.tableView.hidden = empty;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [SnifferManager sharedManager].mediaList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SnifferMiniCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    SnifferMediaModel *model = [SnifferManager sharedManager].mediaList[indexPath.row];
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
        inst.urlSet = [NSMutableSet set];
        inst.scriptBridge = [[SnifferScriptBridge alloc] init];
    });
    return inst;
}

- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIWindowDidBecomeVisibleNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onActive) name:UIWindowDidBecomeKeyNotification object:nil];
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

- (void)addMediaUrl:(NSString *)urlStr {
    if (!urlStr || ![urlStr isKindOfClass:[NSString class]] || urlStr.length == 0) {
        return;
    }
    if ([urlStr hasPrefix:@"blob:"] || [urlStr hasPrefix:@"data:"]) {
        return;
    }

    NSString *lower = [urlStr lowercaseString];
    BOOL isMedia = NO;
    NSArray *keys = @[@".m3u8", @".mp4", @".flv", @".mov", @".mkv", @".webm", @".mpd", @"m3u8?", @"mp4?", @"/playlist", @"/manifest"];
    for (NSString *key in keys) {
        if ([lower containsString:key]) {
            isMedia = YES;
            break;
        }
    }
    if (!isMedia) {
        if ([lower containsString:@"m3u8"] || [lower containsString:@"googlevideo.com"]) {
            isMedia = YES;
        }
    }
    if (!isMedia) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.urlSet containsObject:urlStr]) {
            return;
        }
        [self.urlSet addObject:urlStr];

        SnifferMediaModel *model = [[SnifferMediaModel alloc] init];
        model.url = urlStr;
        [self.mediaList insertObject:model atIndex:0];

        if (!self.overlayWindow) {
            [self setupFloatingUI];
        }

        NSString *title = [NSString stringWithFormat:@"🎬 嗅探 %lu", (unsigned long)self.mediaList.count];
        [self.overlayWindow.floatingButton setTitle:title forState:UIControlStateNormal];

        if (self.overlayWindow.panelView && !self.overlayWindow.panelView.hidden) {
            [self.overlayWindow.panelView refreshList];
        }
    });
}

- (void)clearMedia {
    [self.mediaList removeAllObjects];
    [self.urlSet removeAllObjects];
    [self.overlayWindow.floatingButton setTitle:@"🎬 嗅探 0" forState:UIControlStateNormal];
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
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 1000;
            self.overlayWindow.backgroundColor = [UIColor clearColor];

            UIViewController *rootVC = [[UIViewController alloc] init];
            rootVC.view.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = rootVC;

            CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenH = [UIScreen mainScreen].bounds.size.height;

            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(screenW - 96, screenH - 220, 86, 36);
            btn.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
            btn.layer.cornerRadius = 18;
            btn.layer.masksToBounds = YES;
            btn.layer.borderWidth = 0.5;
            btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
            btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
            [btn setTitle:@"🎬 嗅探 0" forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
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

        CGFloat targetX = (center.x > screenW / 2.0) ? (screenW - btnW / 2.0 - 8) : (btnW / 2.0 + 8);
        CGFloat targetY = MIN(MAX(center.y, 60 + btnH / 2.0), screenH - 60 - btnH / 2.0);

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
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;

        CGFloat panelX = (btnFrame.origin.x + btnFrame.size.width / 2.0 > screenW / 2.0) ? (screenW - panelW - 10) : 10;
        CGFloat panelY = btnFrame.origin.y - panelH - 8;
        if (panelY < 60) {
            panelY = btnFrame.origin.y + btnFrame.size.height + 8;
        }
        if (panelY + panelH > screenH - 40) {
            panelY = screenH - panelH - 40;
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

@interface WKWebView (Sniffer)
@end

@implementation WKWebView (Sniffer)

- (instancetype)sniff_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (configuration) {
        NSString *jsCode = @"(function(){\
            function postUrl(u){\
                if(!u||typeof u!=='string'||u.indexOf('blob:')===0||u.indexOf('data:')===0)return;\
                var l=u.toLowerCase();\
                if(l.indexOf('.m3u8')!==-1||l.indexOf('.mp4')!==-1||l.indexOf('.flv')!==-1||l.indexOf('.mov')!==-1||l.indexOf('.mkv')!==-1||l.indexOf('.mpd')!==-1||l.indexOf('m3u8')!==-1){\
                    try{window.webkit.messageHandlers.SnifferBridge.postMessage(u);}catch(e){}\
                }\
            }\
            function check(){\
                var els=document.querySelectorAll('video, audio, source');\
                for(var i=0;i<els.length;i++){\
                    if(els[i].src)postUrl(els[i].src);\
                    if(els[i].currentSrc)postUrl(els[i].currentSrc);\
                }\
            }\
            check();\
            setInterval(check,1200);\
            var origOpen=XMLHttpRequest.prototype.open;\
            XMLHttpRequest.prototype.open=function(m,u){\
                postUrl(u);\
                return origOpen.apply(this,arguments);\
            };\
            if(window.fetch){\
                var origFetch=window.fetch;\
                window.fetch=function(input,init){\
                    if(typeof input==='string'){postUrl(input);}\
                    else if(input&&input.url){postUrl(input.url);}\
                    return origFetch.apply(this,arguments);\
                };\
            }\
        })();";

        WKUserScript *script = [[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
        [configuration.userContentController addUserScript:script];

        @try {
            [configuration.userContentController addScriptMessageHandler:[SnifferManager sharedManager].scriptBridge name:@"SnifferBridge"];
        } @catch (NSException *e) {}
    }
    return [self sniff_initWithFrame:frame configuration:configuration];
}

@end

@interface AVPlayer (Sniffer)
@end

@implementation AVPlayer (Sniffer)

+ (instancetype)sniff_playerWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] addMediaUrl:URL.absoluteString];
    }
    return [self sniff_playerWithURL:URL];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] addMediaUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

@end

@interface AVPlayerItem (Sniffer)
@end

@implementation AVPlayerItem (Sniffer)

- (instancetype)sniff_initWithURL:(NSURL *)URL {
    if (URL) {
        [[SnifferManager sharedManager] addMediaUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL];
}

- (instancetype)sniff_initWithAsset:(AVAsset *)asset {
    if ([asset isKindOfClass:[AVURLAsset class]]) {
        NSURL *url = ((AVURLAsset *)asset).URL;
        if (url) {
            [[SnifferManager sharedManager] addMediaUrl:url.absoluteString];
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
        [[SnifferManager sharedManager] addMediaUrl:URL.absoluteString];
    }
    return [self sniff_URLAssetWithURL:URL options:options];
}

- (instancetype)sniff_initWithURL:(NSURL *)URL options:(NSDictionary<NSString *,id> *)options {
    if (URL) {
        [[SnifferManager sharedManager] addMediaUrl:URL.absoluteString];
    }
    return [self sniff_initWithURL:URL options:options];
}

@end

@interface NSURLSession (Sniffer)
@end

@implementation NSURLSession (Sniffer)

- (NSURLSessionDataTask *)sniff_dataTaskWithRequest:(NSURLRequest *)request {
    if (request.URL) {
        [[SnifferManager sharedManager] addMediaUrl:request.URL.absoluteString];
    }
    return [self sniff_dataTaskWithRequest:request];
}

- (NSURLSessionDataTask *)sniff_dataTaskWithURL:(NSURL *)url {
    if (url) {
        [[SnifferManager sharedManager] addMediaUrl:url.absoluteString];
    }
    return [self sniff_dataTaskWithURL:url];
}

- (NSURLSessionDataTask *)sniff_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (request.URL) {
        [[SnifferManager sharedManager] addMediaUrl:request.URL.absoluteString];
    }
    return [self sniff_dataTaskWithRequest:request completionHandler:completionHandler];
}

- (NSURLSessionDataTask *)sniff_dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (url) {
        [[SnifferManager sharedManager] addMediaUrl:url.absoluteString];
    }
    return [self sniff_dataTaskWithURL:url completionHandler:completionHandler];
}

@end

__attribute__((constructor)) static void SnifferInit(void) {
    SwizzleMethod([WKWebView class], @selector(initWithFrame:configuration:), @selector(sniff_initWithFrame:configuration:));
    SwizzleClassMethod([AVPlayer class], @selector(playerWithURL:), @selector(sniff_playerWithURL:));
    SwizzleMethod([AVPlayer class], @selector(initWithURL:), @selector(sniff_initWithURL:));
    SwizzleMethod([AVPlayerItem class], @selector(initWithURL:), @selector(sniff_initWithURL:));
    SwizzleMethod([AVPlayerItem class], @selector(initWithAsset:), @selector(sniff_initWithAsset:));
    SwizzleClassMethod([AVURLAsset class], @selector(URLAssetWithURL:options:), @selector(sniff_URLAssetWithURL:options:));
    SwizzleMethod([AVURLAsset class], @selector(initWithURL:options:), @selector(sniff_initWithURL:options:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithRequest:), @selector(sniff_dataTaskWithRequest:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithURL:), @selector(sniff_dataTaskWithURL:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithRequest:completionHandler:), @selector(sniff_dataTaskWithRequest:completionHandler:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithURL:completionHandler:), @selector(sniff_dataTaskWithURL:completionHandler:));

    [[SnifferManager sharedManager] registerNotifications];
}
