#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface SnifferMediaModel : NSObject
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *title;
@end

@implementation SnifferMediaModel
@end

@interface SnifferManager : NSObject
@property (nonatomic, strong) NSMutableArray<SnifferMediaModel *> *mediaList;
@property (nonatomic, strong) NSMutableSet<NSString *> *urlSet;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIButton *floatingButton;
+ (instancetype)sharedManager;
- (void)addMediaUrl:(NSString *)urlStr;
- (void)setupFloatingWindow;
- (void)clearMedia;
@end

@interface SnifferMediaCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *urlLabel;
@property (nonatomic, strong) UIScrollView *buttonScrollView;
@property (nonatomic, strong) UIStackView *buttonStackView;
@property (nonatomic, copy) void (^actionHandler)(NSString *actionType);
- (void)configureWithModel:(SnifferMediaModel *)model index:(NSInteger)index;
@end

@implementation SnifferMediaCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont boldSystemFontOfSize:14];
        _titleLabel.textColor = [UIColor labelColor];

        _urlLabel = [[UILabel alloc] init];
        _urlLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _urlLabel.font = [UIFont systemFontOfSize:11];
        _urlLabel.textColor = [UIColor secondaryLabelColor];
        _urlLabel.numberOfLines = 2;
        _urlLabel.lineBreakMode = NSLineBreakByCharWrapping;

        _buttonScrollView = [[UIScrollView alloc] init];
        _buttonScrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _buttonScrollView.showsHorizontalScrollIndicator = NO;

        _buttonStackView = [[UIStackView alloc] init];
        _buttonStackView.translatesAutoresizingMaskIntoConstraints = NO;
        _buttonStackView.axis = UILayoutConstraintAxisHorizontal;
        _buttonStackView.spacing = 8;
        _buttonStackView.alignment = UIStackViewAlignmentCenter;

        [_buttonScrollView addSubview:_buttonStackView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_urlLabel];
        [self.contentView addSubview:_buttonScrollView];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],

            [_urlLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_urlLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15],
            [_urlLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],

            [_buttonScrollView.topAnchor constraintEqualToAnchor:_urlLabel.bottomAnchor constant:8],
            [_buttonScrollView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:15],
            [_buttonScrollView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-15],
            [_buttonScrollView.heightAnchor constraintEqualToConstant:32],
            [_buttonScrollView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],

            [_buttonStackView.topAnchor constraintEqualToAnchor:_buttonScrollView.topAnchor],
            [_buttonStackView.bottomAnchor constraintEqualToAnchor:_buttonScrollView.bottomAnchor],
            [_buttonStackView.leadingAnchor constraintEqualToAnchor:_buttonScrollView.leadingAnchor],
            [_buttonStackView.trailingAnchor constraintEqualToAnchor:_buttonScrollView.trailingAnchor],
            [_buttonStackView.heightAnchor constraintEqualToAnchor:_buttonScrollView.heightAnchor]
        ]];

        NSArray *btnTitles = @[@"复制", @"Forward", @"Fileball", @"Infuse", @"SenPlayer"];
        for (NSString *title in btnTitles) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            [btn setTitle:title forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
            btn.layer.cornerRadius = 6;
            btn.layer.masksToBounds = YES;
            btn.contentEdgeInsets = UIEdgeInsetsMake(5, 10, 5, 10);

            if ([title isEqualToString:@"复制"]) {
                btn.backgroundColor = [UIColor systemGray5Color];
                [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"Forward"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.88 green:0.97 blue:0.98 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.0 green:0.48 blue:0.76 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"Fileball"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.91 green:0.96 blue:0.91 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.18 green:0.49 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"Infuse"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.90 blue:0.96 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.42 green:0.11 blue:0.6 alpha:1.0] forState:UIControlStateNormal];
            } else if ([title isEqualToString:@"SenPlayer"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.91 green:0.92 blue:0.96 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:0.25 green:0.32 blue:0.71 alpha:1.0] forState:UIControlStateNormal];
            }

            [btn addTarget:self action:@selector(buttonClicked:) forControlEvents:UIControlEventTouchUpInside];
            [_buttonStackView addArrangedSubview:btn];
        }
    }
    return self;
}

- (void)buttonClicked:(UIButton *)sender {
    if (self.actionHandler) {
        self.actionHandler(sender.currentTitle);
    }
}

- (void)configureWithModel:(SnifferMediaModel *)model index:(NSInteger)index {
    self.titleLabel.text = [NSString stringWithFormat:@"媒体资源 %ld", (long)(index + 1)];
    self.urlLabel.text = model.url;
}

@end

@interface SnifferListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation SnifferListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"嗅探媒体列表";

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(closeAction)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearAction)];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.estimatedRowHeight = 90;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    [_tableView registerClass:[SnifferMediaCell class] forCellReuseIdentifier:@"SnifferCell"];
    [self.view addSubview:_tableView];

    _emptyLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    _emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.textColor = [UIColor secondaryLabelColor];
    _emptyLabel.font = [UIFont systemFontOfSize:14];
    _emptyLabel.text = @"暂未嗅探到有效流媒体链接";
    [self.view addSubview:_emptyLabel];

    [self updateState];
}

- (void)updateState {
    BOOL isEmpty = [SnifferManager sharedManager].mediaList.count == 0;
    self.emptyLabel.hidden = !isEmpty;
    self.tableView.hidden = isEmpty;
    [self.tableView reloadData];
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearAction {
    [[SnifferManager sharedManager] clearMedia];
    [self updateState];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [SnifferManager sharedManager].mediaList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SnifferMediaCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SnifferCell" forIndexPath:indexPath];
    SnifferMediaModel *model = [SnifferManager sharedManager].mediaList[indexPath.row];
    [cell configureWithModel:model index:indexPath.row];

    __weak typeof(self) weakSelf = self;
    cell.actionHandler = ^(NSString *actionType) {
        [weakSelf handleAction:actionType url:model.url];
    };
    return cell;
}

- (void)handleAction:(NSString *)actionType url:(NSString *)urlStr {
    if ([actionType isEqualToString:@"复制"]) {
        [UIPasteboard generalPasteboard].string = urlStr;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"链接已复制到剪贴板" preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
        return;
    }

    NSString *encodedUrl = [urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *scheme = nil;

    if ([actionType isEqualToString:@"Forward"]) {
        scheme = [NSString stringWithFormat:@"forward://play?url=%@", encodedUrl];
    } else if ([actionType isEqualToString:@"Fileball"]) {
        scheme = [NSString stringWithFormat:@"filebox://play?url=%@", encodedUrl];
    } else if ([actionType isEqualToString:@"Infuse"]) {
        scheme = [NSString stringWithFormat:@"infuse://x-callback-url/play?url=%@", encodedUrl];
    } else if ([actionType isEqualToString:@"SenPlayer"]) {
        scheme = [NSString stringWithFormat:@"senplayer://x-callback-url/play?url=%@", encodedUrl];
    }

    if (scheme) {
        NSURL *targetUrl = [NSURL URLWithString:scheme];
        [[UIApplication sharedApplication] openURL:targetUrl options:@{} completionHandler:nil];
    }
}

@end

@implementation SnifferManager

+ (instancetype)sharedManager {
    static SnifferManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SnifferManager alloc] init];
        instance.mediaList = [NSMutableArray array];
        instance.urlSet = [NSMutableSet set];
    });
    return instance;
}

- (void)addMediaUrl:(NSString *)urlStr {
    if (!urlStr || urlStr.length == 0 || [urlStr hasPrefix:@"blob:"]) {
        return;
    }

    NSString *lower = [urlStr lowercaseString];
    BOOL isMedia = NO;
    NSArray *extensions = @[@".m3u8", @".mp4", @".flv", @".mov", @".mkv", @".webm", @".ts", @".mp3", @".m4a", @".aac"];
    for (NSString *ext in extensions) {
        if ([lower containsString:ext]) {
            isMedia = YES;
            break;
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
            [self setupFloatingWindow];
        }

        NSString *btnTitle = [NSString stringWithFormat:@"嗅探 %lu", (unsigned long)self.mediaList.count];
        [self.floatingButton setTitle:btnTitle forState:UIControlStateNormal];
    });
}

- (void)clearMedia {
    [self.mediaList removeAllObjects];
    [self.urlSet removeAllObjects];
    [self.floatingButton setTitle:@"嗅探 0" forState:UIControlStateNormal];
}

- (void)setupFloatingWindow {
    UIWindowScene *activeScene = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            activeScene = (UIWindowScene *)scene;
            break;
        }
    }

    if (!activeScene) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                activeScene = (UIWindowScene *)scene;
                break;
            }
        }
    }

    if (activeScene) {
        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:activeScene];
    } else {
        self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }

    self.overlayWindow.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 90, [UIScreen mainScreen].bounds.size.height - 200, 75, 36);
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 100;
    self.overlayWindow.backgroundColor = [UIColor clearColor];

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = rootVC;

    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = self.overlayWindow.bounds;
    self.floatingButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:1.0 alpha:0.85];
    self.floatingButton.layer.cornerRadius = 18;
    self.floatingButton.layer.masksToBounds = YES;
    self.floatingButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [self.floatingButton setTitle:@"嗅探 0" forState:UIControlStateNormal];
    [self.floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.floatingButton addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.floatingButton addGestureRecognizer:pan];

    [rootVC.view addSubview:self.floatingButton];
    self.overlayWindow.hidden = NO;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.overlayWindow];
    CGRect frame = self.overlayWindow.frame;
    frame.origin.x += translation.x;
    frame.origin.y += translation.y;
    self.overlayWindow.frame = frame;
    [pan setTranslation:CGPointZero inView:self.overlayWindow];

    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        CGFloat targetX = (frame.origin.x + frame.size.width / 2.0 > screenWidth / 2.0) ? (screenWidth - frame.size.width - 10) : 10;
        CGFloat targetY = MIN(MAX(frame.origin.y, 50), screenHeight - frame.size.height - 50);

        [UIView animateWithDuration:0.25 animations:^{
            CGRect finalFrame = frame;
            finalFrame.origin.x = targetX;
            finalFrame.origin.y = targetY;
            self.overlayWindow.frame = finalFrame;
        }];
    }
}

- (void)openPanel {
    SnifferListViewController *listVC = [[SnifferListViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:listVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    UIViewController *topVC = [self topViewController];
    if (topVC) {
        [topVC presentViewController:nav animated:YES completion:nil];
    }
}

- (UIViewController *)topViewController {
    UIViewController *root = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow && window != self.overlayWindow) {
                    root = window.rootViewController;
                    break;
                }
            }
        }
    }
    if (!root) {
        root = [UIApplication sharedApplication].windows.firstObject.rootViewController;
    }
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
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

@end

__attribute__((constructor)) static void SnifferInit(void) {
    SwizzleMethod([AVPlayerItem class], @selector(initWithURL:), @selector(sniff_initWithURL:));
    SwizzleMethod([AVPlayerItem class], @selector(initWithAsset:), @selector(sniff_initWithAsset:));
    SwizzleClassMethod([AVURLAsset class], @selector(URLAssetWithURL:options:), @selector(sniff_URLAssetWithURL:options:));
    SwizzleMethod([AVURLAsset class], @selector(initWithURL:options:), @selector(sniff_initWithURL:options:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithRequest:), @selector(sniff_dataTaskWithRequest:));
    SwizzleMethod([NSURLSession class], @selector(dataTaskWithURL:), @selector(sniff_dataTaskWithURL:));

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[SnifferManager sharedManager] setupFloatingWindow];
    });
}
