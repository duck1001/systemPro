// SystemProUI.m — systemPro 设置面板（自绘高级 UI，不用 PSListController 模板）
// 设计语言：insetGrouped 卡片 + 彩色图标块 + 自定义开关行 + 编辑值子页
// + 注销二次确认 + 顶部渐变 Hero 卡 + 轻点震动反馈 + 悬浮 toast 提示
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <spawn.h>
#import "Common.h"    // 开关键名单一来源（-I.. 引入）
#import "Version.h"
// Preferences.framework 私有头（vendored 自 theos/headers，签名与真机对齐）
#import "PBHeaders/PSTableCell.h"
#import "PBHeaders/PSSpecifier.h"
#import "PBHeaders/PSViewController.h"
#import "PBHeaders/PSListController.h"

extern char **environ;
extern int notify_post(const char *name);

#pragma mark - 数据模型
typedef NS_ENUM(NSInteger, SPRowKind) {
    SPRowKindSwitch = 0,
    SPRowKindText,
    SPRowKindButton,
    SPRowKindInfo,
};

@interface SPRow : NSObject
@property (nonatomic) SPRowKind kind;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *icon;
@property (nonatomic, strong) UIColor *tint;
@property (nonatomic, copy) NSString *defValue;
@property (nonatomic) BOOL numeric;
@property (nonatomic) BOOL needsRespring;
@property (nonatomic) BOOL destructive;
@property (nonatomic, copy) NSString *actionName;
@end

@implementation SPRow
+ (instancetype)kind:(SPRowKind)kind key:(NSString *)key title:(NSString *)title
            subtitle:(NSString *)subtitle icon:(NSString *)icon tint:(UIColor *)tint {
    SPRow *r = [SPRow new];
    r.kind = kind; r.key = key; r.title = title; r.subtitle = subtitle; r.icon = icon; r.tint = tint;
    return r;
}
@end

@interface SPSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, strong) NSArray<SPRow *> *rows;
@end
@implementation SPSection @end

#pragma mark - 轻量偏好读写（直读直写 plist + Darwin 通知，和插件侧同一套协议）
static NSMutableDictionary *SPPrefsLoad(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:SP_PREFS_PATH];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}
static void SPPrefsWrite(NSString *key, id value) {
    NSMutableDictionary *d = SPPrefsLoad();
    if (value == nil) [d removeObjectForKey:key];
    else d[key] = value;
    [d writeToFile:SP_PREFS_PATH atomically:YES];
    notify_post(SP_NOTIFY_RELOAD);
}

#pragma mark - 首页 Hero 卡
@interface SPHeroView : UIView
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, strong) UILabel *countLabel;
@end

@implementation SPHeroView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        UIView *card = [UIView new];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.layer.cornerRadius = 22;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        card.layer.masksToBounds = YES;
        [self addSubview:card];
        self.gradient = [CAGradientLayer layer];
        self.gradient.colors = @[(__bridge id)[UIColor colorWithRed:0.36 green:0.34 blue:0.92 alpha:1].CGColor,
                                 (__bridge id)[UIColor colorWithRed:0.61 green:0.28 blue:0.88 alpha:1].CGColor];
        self.gradient.startPoint = CGPointMake(0, 0);
        self.gradient.endPoint = CGPointMake(1, 1.1);
        [card.layer addSublayer:self.gradient];

        // 图标块
        UIView *iconWrap = [UIView new];
        iconWrap.translatesAutoresizingMaskIntoConstraints = NO;
        iconWrap.backgroundColor = [UIColor colorWithWhite:1 alpha:0.18];
        iconWrap.layer.cornerRadius = 14;
        iconWrap.layer.cornerCurve = kCACornerCurveContinuous;
        [card addSubview:iconWrap];
        UIImageView *icon = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"wand.and.stars" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:26 weight:UIImageSymbolWeightSemibold]]];
        icon.tintColor = [UIColor whiteColor];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [iconWrap addSubview:icon];

        UILabel *title = [UILabel new];
        title.text = @"systemPro";
        title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
        title.textColor = [UIColor whiteColor];
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:title];

        UILabel *sub = [UILabel new];
        sub.text = @"Jailbreak Toolkit";
        sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        sub.textColor = [UIColor colorWithWhite:1 alpha:0.75];
        sub.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:sub];

        self.countLabel = [UILabel new];
        self.countLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        self.countLabel.textColor = [UIColor colorWithWhite:1 alpha:0.9];
        self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:self.countLabel];

        UILabel *ver = [UILabel new];
        ver.text = [NSString stringWithFormat:@"v%@", SP_VERSION];
        ver.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
        ver.textColor = [UIColor colorWithWhite:1 alpha:0.9];
        ver.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
        ver.layer.cornerRadius = 8;
        ver.layer.masksToBounds = YES;
        ver.textAlignment = NSTextAlignmentCenter;
        ver.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:ver];

        UILabel *author = [UILabel new];
        author.text = @"by D";
        author.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        author.textColor = [UIColor colorWithWhite:1 alpha:0.65];
        author.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:author];

        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
            [card.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
            [card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
            [card.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6],
            [card.heightAnchor constraintEqualToConstant:142],

            [iconWrap.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
            [iconWrap.topAnchor constraintEqualToAnchor:card.topAnchor constant:22],
            [iconWrap.widthAnchor constraintEqualToConstant:52],
            [iconWrap.heightAnchor constraintEqualToConstant:52],
            [icon.centerXAnchor constraintEqualToAnchor:iconWrap.centerXAnchor],
            [icon.centerYAnchor constraintEqualToAnchor:iconWrap.centerYAnchor],

            [title.leadingAnchor constraintEqualToAnchor:iconWrap.trailingAnchor constant:14],
            [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:24],
            [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
            [self.countLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
            [self.countLabel.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:8],

            [author.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
            [author.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
            [ver.trailingAnchor constraintEqualToAnchor:author.leadingAnchor constant:-8],
            [ver.centerYAnchor constraintEqualToAnchor:author.centerYAnchor],
            [ver.widthAnchor constraintEqualToConstant:74],
            [ver.heightAnchor constraintEqualToConstant:22],
        ]];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIView *card = self.subviews.firstObject;
    self.gradient.frame = card.bounds;
}
@end

#pragma mark - 通用单元格
@interface SPCell : UITableViewCell
@property (nonatomic, strong) UIView *chip;
@property (nonatomic, strong) UIImageView *rowIcon;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, copy) void (^onToggle)(BOOL on);
@property (nonatomic, strong) NSLayoutConstraint *subZero;
@end

@implementation SPCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        _chip = [UIView new];
        _chip.translatesAutoresizingMaskIntoConstraints = NO;
        _chip.layer.cornerRadius = 7.5;
        _chip.layer.cornerCurve = kCACornerCurveContinuous;
        [self.contentView addSubview:_chip];

        _rowIcon = [UIImageView new];
        _rowIcon.tintColor = [UIColor whiteColor];
        _rowIcon.contentMode = UIViewContentModeCenter;
        _rowIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [_chip addSubview:_rowIcon];

        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        _titleLabel.numberOfLines = 0;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLabel];

        _subLabel = [UILabel new];
        _subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
        _subLabel.textColor = [UIColor secondaryLabelColor];
        _subLabel.numberOfLines = 0;
        _subLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subZero = [_subLabel.heightAnchor constraintEqualToConstant:0];
        [self.contentView addSubview:_subLabel];

        _toggle = [UISwitch new];
        _toggle.translatesAutoresizingMaskIntoConstraints = NO;
        _toggle.onTintColor = [UIColor colorWithRed:0.36 green:0.34 blue:0.92 alpha:1];
        [_toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_toggle];

        _valueLabel = [UILabel new];
        _valueLabel.font = [UIFont systemFontOfSize:15];
        _valueLabel.textColor = [UIColor secondaryLabelColor];
        _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_valueLabel];

        _chevron = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"chevron.right" withConfiguration:
                [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold]]];
        _chevron.tintColor = [UIColor tertiaryLabelColor];
        _chevron.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_chevron];

        [NSLayoutConstraint activateConstraints:@[
            [_chip.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_chip.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chip.widthAnchor constraintEqualToConstant:30],
            [_chip.heightAnchor constraintEqualToConstant:30],
            [_rowIcon.centerXAnchor constraintEqualToAnchor:_chip.centerXAnchor],
            [_rowIcon.centerYAnchor constraintEqualToAnchor:_chip.centerYAnchor],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_chip.trailingAnchor constant:12],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_subLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:1],
            [_subLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-8],
            [_subLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12],
            [_toggle.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_valueLabel.trailingAnchor constraintEqualToAnchor:_chevron.leadingAnchor constant:-6],
            [_valueLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_chevron.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_chevron.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        ]];
        // title 右侧避让（不压到开关/值）
        [[_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggle.leadingAnchor constant:-8] setActive:YES];
    }
    return self;
}
- (void)toggleChanged:(UISwitch *)sw {
    if (self.onToggle) self.onToggle(sw.isOn);
}
- (void)configureWithRow:(SPRow *)row value:(id)value {
    self.chip.backgroundColor = row.tint;
    self.rowIcon.image = [UIImage systemImageNamed:row.icon withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]];
    self.titleLabel.text = row.title;
    self.subLabel.text = row.subtitle;
    BOOL hasSub = (row.subtitle.length > 0);
    self.subLabel.hidden = !hasSub;
    self.subZero.active = !hasSub;

    BOOL isSwitch = (row.kind == SPRowKindSwitch);
    BOOL isText   = (row.kind == SPRowKindText);
    BOOL isInfo   = (row.kind == SPRowKindInfo);
    BOOL isButton = (row.kind == SPRowKindButton);

    self.toggle.hidden = !isSwitch;
    self.valueLabel.hidden = !(isText || isInfo);
    self.chevron.hidden = !isText;
    self.selectionStyle = (isSwitch || isText || isButton) ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    self.titleLabel.textColor = row.destructive ? [UIColor systemRedColor] : [UIColor labelColor];

    if (isSwitch) {
        self.toggle.on = [value boolValue];
    } else if (isText) {
        NSString *s = value ? [value description] : (row.defValue ?: @"");
        self.valueLabel.text = s.length ? s : @"默认";
    } else if (isInfo) {
        self.valueLabel.text = [value description];
    }
}
@end

#pragma mark - 编辑值子页
@interface SPEditController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) SPRow *row;
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, copy) void (^onSaved)(NSString *newValue);
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) NSString *initialValue;
@end

@implementation SPEditController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.title = self.row.title;

    UIView *card = [UIView new];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:card];

    UILabel *cap = [UILabel new];
    cap.text = self.row.subtitle.length ? self.row.subtitle : @"留空则恢复默认值";
    cap.font = [UIFont systemFontOfSize:12];
    cap.textColor = [UIColor secondaryLabelColor];
    cap.numberOfLines = 0;
    cap.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:cap];

    self.field = [UITextField new];
    self.field.translatesAutoresizingMaskIntoConstraints = NO;
    self.field.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightRegular];
    self.field.placeholder = self.row.defValue ?: @"";
    self.field.text = self.initialValue.length ? self.initialValue : @"";
    self.field.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.field.autocorrectionType = UITextAutocorrectionTypeNo;
    self.field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    if (self.row.numeric) self.field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.field.delegate = self;
    [card addSubview:self.field];

    [NSLayoutConstraint activateConstraints:@[
        [card.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [card.heightAnchor constraintEqualToConstant:52],
        [self.field.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [self.field.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [self.field.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [cap.topAnchor constraintEqualToAnchor:card.bottomAnchor constant:10],
        [cap.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [cap.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone
                                         target:self action:@selector(save)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.field becomeFirstResponder];
}

- (void)save {
    NSString *v = [self.field.text stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (self.row.numeric && v.length) {
        NSScanner *sc = [NSScanner scannerWithString:v];
        double d = 0;
        if (![sc scanDouble:&d] || !sc.isAtEnd) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"数值无效"
                message:@"请输入数字（可带小数）。" preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
            return;
        }
    }
    if (self.onSaved) self.onSaved(v.length ? v : nil);
    [self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self save];
    return YES;
}
@end

#pragma mark - 主控制器
// 基类直接来自 vendored 的 Preferences 私有头（PBHeaders/PSListController.h），
// 与 SystemX 同款：面板控制器必须挂在 PSListController 上。
// 表格用框架原生 specifier 模型驱动（分节 = group specifier，行 = cell specifier），
// 只重写 cellForRow 自定义样式 —— 这是社区验证过的标准姿势；
// 切记不要自己接管 numberOfSections/numberOfRows（会撞 PSListController 内部缓存，iOS 16 直接抛 NSRangeException）。
@interface SystemProRootController : PSListController
@property (nonatomic, strong) UITableView *contentTable;
@property (nonatomic, strong) NSMutableArray<SPSection *> *model;
@property (nonatomic, strong) NSMutableDictionary *prefs;
@property (nonatomic, strong) SPHeroView *hero;
@end

@implementation SystemProRootController

#pragma mark specifier 模型

- (void)spEnsureModel { if (!self.model) [self buildModel]; }

- (NSMutableArray *)specifiers {
    [self spEnsureModel];
    if (!_specifiers) _specifiers = [self spBuildSpecifiers];
    return _specifiers;
}

- (NSMutableArray *)spBuildSpecifiers {
    NSMutableArray *arr = [NSMutableArray array];
    for (SPSection *sec in self.model) {
        // group specifier：优先用工厂方法，缺失时手工构造（都对 iOS 16 安全）
        PSSpecifier *g = nil;
        if ([PSSpecifier respondsToSelector:@selector(groupSpecifierWithName:)]) {
            g = [PSSpecifier groupSpecifierWithName:sec.title];
        } else {
            g = [[PSSpecifier alloc] init];
            [g setName:sec.title];
            [g setCellType:PSGroupCell];
            [g setProperty:sec.title forKey:@"label"];
        }
        if (sec.footer.length) [g setProperty:sec.footer forKey:@"footerText"];
        [arr addObject:g];

        for (SPRow *row in sec.rows) {
            PSCellType ct = PSStaticTextCell;
            if (row.kind == SPRowKindSwitch)      ct = PSSwitchCell;
            else if (row.kind == SPRowKindButton) ct = PSButtonCell;
            else if (row.kind == SPRowKindText)   ct = PSLinkCell;

            PSSpecifier *sp = nil;
            if ([PSSpecifier respondsToSelector:@selector(preferenceSpecifierNamed:target:set:get:detail:cell:edit:)]) {
                sp = [PSSpecifier preferenceSpecifierNamed:row.title
                                                    target:self
                                                       set:NULL
                                                       get:NULL
                                                    detail:nil
                                                      cell:ct
                                                      edit:nil];
            } else {
                sp = [[PSSpecifier alloc] init];
                [sp setName:row.title];
                [sp setCellType:ct];
            }
            [sp setProperty:row forKey:@"spRow"];
            if (row.key) [sp setProperty:row.key forKey:@"key"];
            [arr addObject:sp];
        }
    }
    return arr;
}

// 行数据直接走我们的模型（与 specifier 数组逐一对应；不依赖 iOS 16 上未验证的选择器）
- (SPRow *)spRowAtIndexPath:(NSIndexPath *)indexPath {
    [self spEnsureModel];
    if (indexPath.section >= (NSInteger)self.model.count) return nil;
    SPSection *sec = self.model[indexPath.section];
    if (indexPath.row >= (NSInteger)sec.rows.count) return nil;
    return sec.rows[indexPath.row];
}

- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleInsetGrouped;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self spEnsureModel];
    self.title = @"systemPro";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.prefs = SPPrefsLoad();

    // 只使用 iOS 16 上确有实现的选择器：PSListController 的 -table（SystemX 同款、实证可用）。
    // 绝不要再碰 -tableView（iOS 16 未实现 → unrecognized selector 闪退）。
    UITableView *tv = self.table;
    if (!tv && [self.view isKindOfClass:[UITableView class]]) tv = (UITableView *)self.view;
    self.contentTable = tv;
    if (tv) {
        tv.backgroundColor = [UIColor systemGroupedBackgroundColor];
        self.hero = [[SPHeroView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, 158)];
        tv.tableHeaderView = self.hero;
    }
}

// 自定义读值/写值：直接读写我们的 plist + Darwin 通知（绕开 cfprefsd 缓存）
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return nil;
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:SP_PREFS_PATH];
    return d[key];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key.length) return;
    SPPrefsWrite(key, value);
    self.prefs = SPPrefsLoad();
}

// 自绘行高全部交给 Auto Layout
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 58;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.prefs = SPPrefsLoad();
    [self.contentTable reloadData];
    [self updateHeroCount];
}

#pragma mark 模型
- (SPSection *)section:(NSString *)title footer:(NSString *)footer rows:(NSArray *)rows {
    SPSection *s = [SPSection new];
    s.title = title; s.footer = footer; s.rows = rows;
    return s;
}
- (SPRow *)sw:(NSString *)key title:(NSString *)t sub:(NSString *)sub icon:(NSString *)icon tint:(UIColor *)tint respring:(BOOL)rp {
    SPRow *r = [SPRow kind:SPRowKindSwitch key:key title:t subtitle:sub icon:icon tint:tint];
    r.needsRespring = rp;
    return r;
}
- (SPRow *)tx:(NSString *)key title:(NSString *)t icon:(NSString *)icon def:(NSString *)def numeric:(BOOL)num {
    SPRow *r = [SPRow kind:SPRowKindText key:key title:t subtitle:nil icon:icon tint:[UIColor systemGrayColor]];
    r.defValue = def; r.numeric = num;
    return r;
}

- (void)buildModel {
    UIColor *indigo = [UIColor colorWithRed:0.36 green:0.34 blue:0.92 alpha:1];
    UIColor *orange = [UIColor systemOrangeColor];
    UIColor *blue   = [UIColor systemBlueColor];
    UIColor *green  = [UIColor systemGreenColor];
    UIColor *pink   = [UIColor systemPinkColor];
    UIColor *teal   = [UIColor systemTealColor];
    UIColor *purple = [UIColor systemPurpleColor];
    UIColor *red    = [UIColor systemRedColor];

    SPSection *sb = [self section:@"状态栏"
        footer:@"日期显示在状态栏时间下方；静音小图标开启时会自动把响铃切到静音。"
        rows:@[
            [self sw:kStatusBarDateTime title:@"显示日期时间" sub:@"时间下方一行日期，可自定义格式与字号" icon:@"calendar.badge.clock" tint:orange respring:NO],
            [self tx:kSBCDateTimeTimeFormat title:@"时间格式" icon:@"clock" def:@"HH:mm" numeric:NO],
            [self tx:kSBCDateTimeDateFormat title:@"日期格式" icon:@"calendar" def:@"E MM/dd" numeric:NO],
            [self tx:kSBCDateTimeTimeFontSize title:@"时间字号" icon:@"textformat.size" def:@"15" numeric:YES],
            [self tx:kSBCDateTimeDateFontSize title:@"日期字号" icon:@"textformat.size" def:@"10" numeric:YES],
            [self tx:kSBCDateTimeOffsetY title:@"整体上下偏移" icon:@"arrow.up.and.down" def:@"0" numeric:YES],
            [self sw:kSBCDateTimeEnglishDate title:@"英文日期" sub:nil icon:@"character" tint:teal respring:NO],
            [self sw:kSilentStatusBarIcon title:@"静音小图标" sub:@"打开即切换静音并在状态栏显示图标" icon:@"bell.slash.fill" tint:purple respring:NO],
            [self tx:kSilentStatusBarIconSymbol title:@"图标符号名" icon:@"square.grid.3x1.folder.badge.plus" def:@"bell.slash.fill" numeric:NO],
            [self sw:kForce5GAStatusBar title:@"蜂窝显示 5GA" sub:@"仅改状态栏文字，不改网络制式" icon:@"antenna.radiowaves.left.and.right" tint:green respring:NO],
            [self tx:kFakeBatteryPercent title:@"伪装电量（1-100，0=关）" icon:@"battery.75" def:@"0" numeric:YES],
        ]];

    SPSection *dt = [self section:@"桌面与 Dock"
        footer:@"Dock 布局类修改建议注销后生效。手势在桌面空白区域触发。"
        rows:@[
            [self sw:kFiveIconDock title:@"Dock 五图标" sub:@"首次开启请注销" icon:@"dock.rectangle" tint:blue respring:YES],
            [self sw:kTransparentDock title:@"透明 Dock 背景" sub:nil icon:@"square.on.square.dashed" tint:blue respring:NO],
            [self sw:kDoubleTapToLock title:@"双击桌面锁屏" sub:nil icon:@"hand.tap.fill" tint:indigo respring:NO],
            [self sw:kLongPressToLock title:@"长按桌面锁屏" sub:nil icon:@"hand.point.up.left.fill" tint:indigo respring:NO],
            [self sw:kHideHomeBar title:@"隐藏 Home Bar" sub:nil icon:@"rectangle.bottomhalf.filled" tint:purple respring:NO],
            [self sw:kHideHomePageDots title:@"隐藏翻页点" sub:nil icon:@"ellipsis" tint:teal respring:NO],
            [self sw:kHideHomeIconLabels title:@"隐藏图标名称" sub:nil icon:@"textformat" tint:teal respring:NO],
            [self sw:kHideWidgetLabels title:@"隐藏小组件名称" sub:nil icon:@"square.grid.2x2" tint:teal respring:NO],
            [self sw:kHideHomeIconLabelShadow title:@"隐藏名称阴影" sub:nil icon:@"shadow" tint:teal respring:NO],
        ]];

    SPSection *fd = [self section:@"文件夹"
        footer:@"文件夹布局属于注册期配置，首次开关请注销。"
        rows:@[
            [self sw:kFolder4x4 title:@"文件夹 4×4 布局" sub:@"首次开启请注销" icon:@"folder.fill" tint:orange respring:YES],
        ]];

    SPSection *dis = [self section:@"禁用与隐藏"
        footer:@"分隔线按 App 分别生效（设置/电话/信息）。"
        rows:@[
            [self sw:kDisableTodayView title:@"禁用负一屏" sub:nil icon:@"rectangle.split.3x1" tint:red respring:NO],
            [self sw:kDisableAppLibrary title:@"禁用 App 资源库" sub:nil icon:@"square.grid.2x2.fill" tint:red respring:NO],
            [self sw:kDisableHomePullDownSearch title:@"禁用下拉搜索" sub:nil icon:@"magnifyingglass" tint:red respring:NO],
            [self sw:kDisableSeparators title:@"禁用设置分隔线" sub:nil icon:@"minus" tint:pink respring:NO],
            [self sw:kDisablePhoneSeparators title:@"禁用电话分隔线" sub:nil icon:@"minus" tint:pink respring:NO],
            [self sw:kDisableMessagesSeparators title:@"禁用信息分隔线" sub:nil icon:@"minus" tint:pink respring:NO],
            [self sw:kNotificationNoWake title:@"通知不亮屏" sub:nil icon:@"bell.slash" tint:purple respring:NO],
            [self sw:kChargingWakeDisabled title:@"充电不亮屏" sub:nil icon:@"bolt.slash.fill" tint:purple respring:NO],
            [self sw:kNoLockAfterRespring title:@"注销不锁屏" sub:@"注销/重启后直接进入桌面" icon:@"lock.open.fill" tint:green respring:NO],
        ]];

    SPSection *ph = [self section:@"相册"
        footer:@"仅作用于照片 App。"
        rows:@[
            [self sw:kSkipDeleteConfirmation title:@"跳过删除确认" sub:nil icon:@"trash.slash.fill" tint:red respring:NO],
            [self sw:kHideZoomLevelControl title:@"隐藏年月日控件" sub:nil icon:@"calendar.day.timeline.left" tint:teal respring:NO],
            [self sw:kAllowSelectAll title:@"允许全选" sub:nil icon:@"checkmark.circle.fill" tint:green respring:NO],
            [self sw:kMarkAlbumNotUserCreated title:@"隐藏「我的相簿」分组" sub:nil icon:@"rectangle.stack.badge.minus" tint:orange respring:NO],
        ]];

    SPRow *respring = [SPRow kind:SPRowKindButton key:nil title:@"注销 SpringBoard"
                          subtitle:@"让所有更改生效（有二次确认）" icon:@"arrow.clockwise" tint:indigo];
    respring.actionName = @"respring";
    SPRow *reset = [SPRow kind:SPRowKindButton key:nil title:@"恢复默认设置"
                          subtitle:@"清空全部开关（有二次确认）" icon:@"arrow.counterclockwise" tint:red];
    reset.actionName = @"reset";
    reset.destructive = YES;

    SPSection *maint = [self section:@"维护"
        footer:@"切换即时保存并通过 com.sytem.pro.prefschanged 通知插件热重载；个别布局项需注销。"
        rows:@[respring, reset]];

    SPRow *v = [SPRow kind:SPRowKindInfo key:nil title:@"版本" subtitle:nil icon:@"tag" tint:[UIColor systemGrayColor]];
    v.defValue = SP_VERSION;
    SPRow *au = [SPRow kind:SPRowKindInfo key:nil title:@"作者" subtitle:nil icon:@"person" tint:[UIColor systemGrayColor]];
    au.defValue = @"D";
    SPRow *idr = [SPRow kind:SPRowKindInfo key:nil title:@"标识" subtitle:nil icon:@"number" tint:[UIColor systemGrayColor]];
    idr.defValue = @"com.sytem.pro";
    SPRow *link = [SPRow kind:SPRowKindInfo key:nil title:@"状态" subtitle:nil icon:@"bolt.fill" tint:[UIColor systemGrayColor]];
    link.defValue = @"热重载已启用";
    SPSection *about = [self section:@"关于"
        footer:@"systemPro · 手搓实现的越狱功能套件。改动即时保存，误操作可在「维护」里恢复默认。"
        rows:@[v, au, idr, link]];

    self.model = [@[sb, dt, fd, dis, ph, maint, about] mutableCopy];
}

#pragma mark - 表格数据源 / 交互（分节与行序由框架 specifier 模型负责）

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SPRow *row = [self spRowAtIndexPath:indexPath];
    if (!row) {
        return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    }
    SPCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[SPCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    id value = (row.kind == SPRowKindInfo) ? row.defValue : self.prefs[row.key];
    [cell configureWithRow:row value:value];
    __weak typeof(self) weakSelf = self;
    if (row.kind == SPRowKindSwitch) {
        cell.onToggle = ^(BOOL on) {
            [weakSelf setPref:row.key value:@(on) row:row];
        };
    } else {
        cell.onToggle = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SPRow *row = [self spRowAtIndexPath:indexPath];
    if (!row) return;
    if (row.kind == SPRowKindSwitch) {
        SPCell *cell = (SPCell *)[tableView cellForRowAtIndexPath:indexPath];
        BOOL on = !cell.toggle.isOn;
        [cell.toggle setOn:on animated:YES];
        [self setPref:row.key value:@(on) row:row];
    } else if (row.kind == SPRowKindText) {
        SPEditController *e = [SPEditController new];
        e.row = row;
        id cur = self.prefs[row.key];
        e.initialValue = cur ? [cur description] : @"";
        __weak typeof(self) weakSelf = self;
        e.onSaved = ^(NSString *v) {
            [weakSelf setPref:row.key value:v row:row];
        };
        [self.navigationController pushViewController:e animated:YES];
    } else if (row.kind == SPRowKindButton) {
        if ([row.actionName isEqualToString:@"respring"]) [self confirmRespring];
        else if ([row.actionName isEqualToString:@"reset"]) [self confirmReset];
    }
}

#pragma mark - 写值 / 反馈
- (void)setPref:(NSString *)key value:(id)value row:(SPRow *)row {
    SPPrefsWrite(key, value);
    if (value == nil) [self.prefs removeObjectForKey:key];
    else self.prefs[key] = value;

    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [h impactOccurred];

    if (row.needsRespring) [self showToast:@"已保存 · 该项需注销后生效"];
    [self.contentTable reloadData];
    [self updateHeroCount];
}

- (void)updateHeroCount {
    NSInteger on = 0, total = 0;
    for (SPSection *s in self.model) {
        for (SPRow *r in s.rows) {
            if (r.kind == SPRowKindSwitch) {
                total++;
                if ([self.prefs[r.key] boolValue]) on++;
            }
        }
    }
    self.hero.countLabel.text = [NSString stringWithFormat:@"已启用 %ld / %ld 项功能", (long)on, (long)total];
}

- (void)showToast:(NSString *)text {
    UILabel *toast = [UILabel new];
    toast.text = text;
    toast.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.82];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.numberOfLines = 0;
    toast.layer.cornerRadius = 15;
    toast.layer.cornerCurve = kCACornerCurveContinuous;
    toast.layer.masksToBounds = YES;
    toast.alpha = 0;

    CGSize bound = [text boundingRectWithSize:CGSizeMake(self.view.bounds.size.width - 96, 80)
                                      options:NSStringDrawingUsesLineFragmentOrigin
                                   attributes:@{ NSFontAttributeName: toast.font } context:nil].size;
    CGFloat w = MAX(bound.width + 34, 140);
    CGFloat h = bound.height + 16;
    toast.frame = CGRectMake((self.view.bounds.size.width - w) / 2, self.view.bounds.size.height - 130, w, h);
    toast.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:toast];

    [UIView animateWithDuration:0.22 animations:^{ toast.alpha = 1; } completion:^(BOOL f) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{ toast.alpha = 0; } completion:^(BOOL f2) {
                [toast removeFromSuperview];
            }];
        });
    }];
}

#pragma mark - 注销（二次确认 + 多路降级 + 失败提示）
- (void)confirmRespring {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"注销 SpringBoard？"
        message:@"所有更改已保存，注销后生效。部分布局类修改（Dock / 文件夹）必须注销。"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"立即注销" style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *x) { [self spawnRespring]; }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)spawnRespring {
    NSArray *tools = @[
        @[@"/var/jb/usr/bin/sbreload", @[]],
        @[@"/usr/bin/sbreload",       @[]],
        @[@"/var/jb/usr/bin/killall", @[@"-9", @"SpringBoard"]],
        @[@"/usr/bin/killall",        @[@"-9", @"SpringBoard"]],
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSArray *entry in tools) {
        NSString *path = entry[0];
        NSArray *args = entry[1];
        if (![fm fileExistsAtPath:path]) continue;
        const char *argv[4] = {0};
        argv[0] = path.UTF8String;
        for (NSUInteger i = 0; i < args.count && i < 3; i++) argv[i + 1] = ((NSString *)args[i]).UTF8String;
        pid_t pid = 0;
        int rc = posix_spawn(&pid, path.UTF8String, NULL, NULL, (char *const *)argv, environ);
        if (rc == 0) {
            [self showToast:@"正在注销…"];
            return;
        }
    }
    UIAlertController *f = [UIAlertController alertControllerWithTitle:@"未能自动注销"
        message:@"没有找到可用的 sbreload / killall。\n可手动运行 “sbreload”，或在越狱工具里选择「重启 SpringBoard」。"
        preferredStyle:UIAlertControllerStyleAlert];
    [f addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:f animated:YES completion:nil];
}

#pragma mark - 恢复默认（二次确认）
- (void)confirmReset {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"恢复默认设置？"
        message:@"将清空 systemPro 的全部开关。此操作不可撤销。"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *x) {
        [[NSFileManager defaultManager] removeItemAtPath:SP_PREFS_PATH error:nil];
        notify_post(SP_NOTIFY_RELOAD);
        self.prefs = SPPrefsLoad();
        [self.contentTable reloadData];
        [self updateHeroCount];
        [self showToast:@"已恢复默认 · 建议注销"];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
