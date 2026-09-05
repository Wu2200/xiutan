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
    NSArray *extensions = @[@".m3u8", @".mp4", @".flv", @".mov", @".mkv", @".webm", @".ts", @".mp3", @".mThis request was blocked by Gemini's filters. They can occasionally trigger by mistake on safe coding, security, or biology-related queries. Please try rephrasing your prompt. You can [send feedback](https://ai.google.dev/gemini-api/docs/troubleshooting#file-bug) or read more about [our policies here](https://policies.google.com/terms/generative-ai/use-policy).
