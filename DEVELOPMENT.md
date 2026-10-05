# systemPro 开发手册（避坑 + 规范）

> 每次动代码前先扫一眼本文件。所有"血泪"条目都对应一次真实翻车。
> 目标环境（实证基准）：iPhone 14 Pro Max / iOS 16.2 / roothide 越狱。

## 0. 基本信息

| 项 | 值 |
|---|---|
| 插件名 | systemPro |
| 标识符 | com.sytem.pro（按操作方指定，勿"纠正"） |
| 作者 | D |
| 版本规则 | 首次 0.0.1-1；小改尾号 +1（0.0.2-2…）；功能轮 0.0.N-1 |
| 优先级 | **roothide 优先**，rootless 兼顾 |
| 仓库 | github.com/duck1001/systemPro（私有） |
| CI | GitHub Actions（macos-14）：push 出 Artifacts；tag `v*` 自动 Release 附双 deb |

## 1. 构建与发版

```bash
sh Scripts/bump-version.sh 0.0.2-2      # 三处同步（control / Resources/Info.plist / Version.h）+ README
git add -A && git commit -m "..." && git push
git tag v0.0.2-2 && git push origin --tags   # 触发 Release（rootless + roothide 两个 deb）
```

- Actions 里 roothide 用 **roothide/theos fork**，rootless 用官方 theos；两 job 串行防 Release 竞争。
- 装包优先测 `..._iphoneos-arm64e.deb`（roothide），rootless 机器用 `..._arm64.deb`。

## 2. 文件地图

| 文件 | 职责 |
|---|---|
| `Tweak.x` | 构造：进程判定（5 进程）+（可选）dpkg 门禁 + 初始化 |
| `Common.h` | 开关键名（**单一来源**）/ 进程标志 / 工具宏 |
| `Prefs.m` | 开关读取：plist 直读 + CFPreferences 回退 + Darwin 热重载 |
| `Features_StatusBar.x` | 日期时间 / 静音图标 / 5GA / 伪装电量 |
| `Features_Desktop.x` | Dock / 桌面 / 文件夹 / 手势锁屏 / 隐藏项 |
| `Features_Disable.x` | 负一屏 / 资源库 / 分隔线 / 唤醒 / 注销锁屏 |
| `Features_Photos.x` | 相册四项 |
| `prefs/SystemProUI.m` | 全部设置界面（分页 + 自绘卡片 + 滑块 + 注销） |
| `prefs/PBHeaders/` | vendored Preferences 私有头（theos/headers） |
| `prefs/Resources/Info.plist` | **必须在 Resources/**（见避坑 1） |
| `DEVELOPMENT.md` | 本文件 |

## 3. 血泪避坑（每条都真翻过车）

1. **bundle 资源必须放 `prefs/Resources/`**：theos 只把该目录 rsync 进 `.bundle`。
   Info.plist 放错位置 → Settings 点入口直接闪退（bundle 加载失败）。且 INFO.plist subdir
   处理依赖 Resources 路径。
2. **面板控制器必须挂 `PSListController`**（用 `PBHeaders/` 真头 + `-Wl,-undefined,dynamic_lookup`）。
   纯 UIViewController 会在 `controllerForSpecifier:` 崩（收 setSpecifier:/setRootController: 时转发）。
3. **表格必须由框架 specifier 模型驱动**：分节 = group specifier、行 = cell specifier，
   **只重写** `tableView:cellForRowAtIndexPath:` / `didSelectRow` / 高度。
   自己接管 numberOfSections/numberOfRows → iOS 16 崩
   `PSListController _tableView:heightForCustomInSection:`（NSRangeException）。
   行数据用我们自己的 model 直取（与 specifier 数组 1:1），别依赖未验证的 `specifierAtIndexPath:`。
4. **表访问器只有 `-table`**（iOS 16 实证；SystemX 同款）。**没有 `-tableView`** → 用了就是
   unrecognized selector 崩 viewDidLoad。找不到就退化 `self.view`（PSListController 把 view 重声明为 UITableView）。
5. **ARC 指针雷**：`id *` / `T **` 强转与出参在 ARC 下编译失败。
   读对象型 ivar 用 `void **slot = ...; (__bridge id)(*slot)`；出参用显式 `__strong *` 局部。
6. **数值读写的类型陷阱**：面板以字符串存数字（如 "50"）。读取端必须走 `integerValue` /
   `doubleValue`；`NSString` **没有** `longValue`（曾导致伪装电量整组失效）。
7. **手势过滤器别用 `containsString:@"Icon"`**：会把 `SBIconListView`（列表背景）也拦掉，
   桌面空白区手势永远收不到触摸。只拦 `SBIconView`（精确）/ Badge / Widget / IconImage /
   IconLabel / IconAccessory。
8. **roothide 路径**：工具在 `/var/containers/Bundle/Application/.jbroot-*/usr/bin`（随机的 .jbroot-*）。
   respring 工具查找顺序：`/var/jb/usr/bin` → `/usr/bin` → `/usr/local/bin` → 扫描 `.jbroot-*`；
   工具链 `sbreload` → `killall -9 SpringBoard`。
9. **状态栏日期**：
   - 前景色必须从系统当前 `attributedText/textColor` 继承（否则不吃壁纸自适应，黑白不分）。
   - 上下偏移**不要**在 applyUpdate 里 setTransform（会被系统重算顶回，来回跳）；
     按 SystemX 做法挂 `STUIStatusBarDisplayItem/_UIStatusBarDisplayItem._updateComputedTransform`，
     之后 `CGAffineTransformTranslate`；用 associated object 标记"是我们的时间项"。
   - 未验证选择器别用：先看 SystemX 二进制的字符串表确认真机选择器名。
10. **静音小图标靠 focusName 标记上屏**：
    `_UIStatusBarDataQuietModeEntry` 的选择器全名
    `initFromData:type:focusName:maxFocusLength:imageName:maxImageLength:boolValue:`（7 参，实证自 SystemX），
    静音时 `setValue:@"!Mute" forKey:@"focusName"`，item 侧 `systemImageNameForUpdate:` 换符号。
    静音状态读 `SBRingerControl.isRingerMuted`（KVC 容错，取不到默认 YES）。
11. **UI 交互约定（产品决定）**：
    - 开关**只能点开关本体**切换；点文字/行不切换（行无选中高亮）。
    - 行 kind 决定交互：text/button/link 有选中高亮；switch/slider/info 无。
    - 拖动滑块时**不能整表 reloadData**（会打断拖拽）；写值绕过 reload。
12. **logos/编辑纪律**：改完任何文件跑"括号配平 + %hook/%end 计数 + grep 残片"三连；
    **同一文件不要在一个批次里放多个 edit**（曾两次把文件尾搞进重复残片，被 logos 报 '}' 错）。
13. **编辑后自查命令**（复制即用）：
    ```sh
    o=$(grep -o '{' prefs/SystemProUI.m | wc -l); c=$(grep -o '}' prefs/SystemProUI.m | wc -l); echo "{ $o } $c"
    grep -c '%hook' Features_*.x; grep -c '%end' Features_*.x
    grep -n 'self\.tableView\|specifierAtIndexPath\|registerClass' prefs/SystemProUI.md   # 应为空
    ```
14. **私有方法签名铁律（安全模式实锤）**：任何 `%hook` 的私有方法，参数类型必须与真机一致
    （去反汇编/repo 找真签名）。非对象参数（`id *` / `const char *` / 指针 / 整数）
    **绝不能声明成 `id`**：ARC 会在 `@try` 等场景为本该"保活"的对象参数插入 `objc_retain`，
    对非对象指针直接 SIGSEGV（SpringBoard 进安全模式）。
    实例：`_UIStatusBarDataQuietModeEntry initFromData:(id *)type:(int)focusName:(const char *)
    maxFocusLength:(int)imageName:(const char *)maxImageLength:(int)boolValue:(BOOL)`。
    选择器拼写/大小写也要对齐（`boolValue:` vs `BOOLValue:` 视系统版本，以 SystemX 二进制字符串为准）。

## 4. 加新功能标准流程（照 hooks_final.tsv 施工）

1. 逆向资料：`/var/minis/workspace/sysbox/`（468 hook 全表 + 三份域报告 + CFString 表）。
2. `hooks_final.tsv` 找类/selector → `r2 pd` 看 SystemX 实现 → 先在 SystemX 二进制 `strings`
   核对选择器/类名真实存在（iOS 16 验证），再写 `%hook`。
3. 开关走 `SPBool(@"键")`；键名加进 `Common.h`（单一来源）+ 面板加行。
4. 面板行：switch 用 `sw:`、文本编辑用 `tx:`、滑块用 `sl:`、分页入口用 `lk:`；需要注销的加 `respring:YES`。
5. 登录/布局类改动默认提示"需注销生效"；能在钩子内实时判断的（`SPBool`）即热生效。

## 5. 每轮测试清单

- [ ] 设置面板能打开、分页能进、开关只能点本体切换
- [ ] 注销按钮（左上角）能自动注销（roothide 路径扫描生效）
- [ ] 状态栏：日期显示 / 颜色随壁纸 / 偏移滑块拖动不跳
- [ ] 手势：桌面空白双击、长按锁屏
- [ ] 伪装电量：设 1-100 后生效（等系统刷新或注销）
- [ ] 静音小图标：开开关 → 自动静音 + 状态栏出图标
- [ ] Dock 五图标 / 文件夹 4×4（注销后复查）

## 6. iOS 16.2 实证选择器/API 白名单（可放心用）

`table`（PSListController）· `setProperty:forKey:` · `groupSpecifierWithName:`（有 responds 守卫）·
`preferenceSpecifierNamed:target:set:get:detail:cell:edit:`（有守卫）· `reloadSpecifiers` ·
`readPreferenceValue:` / `setPreferenceValue:specifier:` · `_updateComputedTransform` ·
`systemImageNameForUpdate:` · `initFromData:type:focusName:maxFocusLength:imageName:maxImageLength:boolValue:` ·
`SBRingerControl.isRingerMuted`（KVC）· `SBLockScreenManager lockUIFromSource:withOptions:` ·
`turnOnScreenFullyWithBacklightSource:` · `SBBootDefaults dontLockAfterCrash` · `px_isUserCreated` 等。

**黑名单（反面清单，勿用）**：`-tableView`（PSListController 上不存在）· 自行接管表格分区 ·
未验证的多参 `%orig` 超集（宁可先从 SystemX 二进制 strings 查全名）。

## 7. 与逆向工程的衔接

功能/挂钩点来源：`sysbox_re_full.tar.gz`（hooks_final.tsv / cfstrings.txt / 三份域报告）。
新增功能时在报告里找"实现要点"段落，按第 4 节流程落地。
