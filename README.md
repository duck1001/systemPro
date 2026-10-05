# systemPro

标识符 `com.sytem.pro` · 作者 **D** · 当前版本 **0.0.2-2**

systemPro 是一套手搓的越狱功能增强插件：功能面参考 SystemX（com.wkk.systembox）的逆向分析
成果（挂钩点均为实测验证过的位置），**代码全部自研**，设置界面为自绘的高级 UI，并通过
GitHub Actions（macOS 工作流）自动打包。

---

## 特性（v0.0.1 首批）

**状态栏**
- 状态栏日期时间：时间下方一行日期；时间/日期格式自定义、独立字号、整体上下偏移、英文日期
- 静音小图标：开启时自动切静音并在状态栏显示图标（支持自定义 SF Symbol 名）
- 蜂窝显示 5GA（仅文字，不改网络制式）
- 伪装电量（1–100，0 恢复）

**桌面与 Dock**
- Dock 五图标（首次开启建议注销）
- 透明 Dock 背景
- 双击桌面锁屏 / 长按桌面锁屏（桌面空白区域触发）
- 隐藏 Home Bar / 翻页点 / 图标名称 / 小组件名称 / 名称阴影

**文件夹**
- 文件夹 4×4 布局（首次开启建议注销）

**禁用与隐藏**
- 禁用负一屏 / App 资源库 / 桌面下拉搜索
- 禁用分隔线（设置 / 电话 / 信息 分别控制）
- 通知不亮屏、充电不亮屏
- 注销不锁屏（注销/重启后直接进桌面）

**相册**
- 跳过删除确认、隐藏年月日缩放控件、允许全选、隐藏「我的相簿」分组

## 设置界面（自绘 · 分页版）

进入 设置 → systemPro：

- 首页：渐变 Hero 卡（图标 + 标题 + 实时「已启用 N / M 项功能」+ 版本角标）+ 分页入口
- 分页：状态栏 / 桌面与 Dock / 文件夹 / 禁用与隐藏 / 相册，各子页独立导航
- 卡片式分组：彩色图标块 + 标题/副标题 + 圆角开关；点行也能切换
- 编辑值子页：自定义格式/字号/符号名，带数值校验
- 轻点震动反馈；切换即保存并通过 Darwin 通知让插件**热重载**（个别布局项提示需注销）
- 「注销」在**导航栏左上角**（保留返回键）：二次确认 → sbreload / killall 多路降级，
  候选目录含 rootless `/var/jb`、老式 `/usr`、roothide `.jbroot-*`；失败有指引弹窗
- 「恢复默认设置」二次确认 + 一键清空

## 仓库结构

```
systemPro/
├── Makefile                 # 越狱插件主工程（rootless 默认；CI 可切 roothide）
├── control                  # 包信息（0.0.1-1）
├── systemPro.plist          # 注入过滤：SpringBoard/设置/相册/电话/信息
├── Tweak.x                  # 主入口：进程判定 + 可选自检门禁 + 初始化
├── Common.h                 # 开关键名（单一来源）/ 进程判定 / 工具
├── Prefs.h / Prefs.m        # 开关读取（plist 直读 + CFPreferences 回退 + 热重载）
├── PrivateHeaders.h         # 需要 hook 的私有类声明
├── Features_StatusBar.x     # 状态栏功能
├── Features_Desktop.x       # 桌面 / Dock / 文件夹 / 手势
├── Features_Disable.x       # 禁用 / 唤醒 / 注销
├── Features_Photos.x        # 相册功能
├── prefs/                   # 设置面板（自绘 UI）
│   ├── SystemProUI.m        #   全部界面代码（Hero 卡/卡片/子页/注销）
│   ├── Version.h            #   版本号单一来源
│   ├── Info.plist / entry.plist / Makefile
├── Scripts/bump-version.sh  # 一键同步版本号
└── .github/workflows/build.yml  # GitHub Actions 打包（macOS）
```

## 构建

### 本地（设备或 macOS，Theos 环境）

```bash
make package FINALPACKAGE=1              # 默认 rootless
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide   # roothide 越狱
make install                             # 装到设备并注销
```

### GitHub Actions（macOS 工作流，推荐）

推送到 GitHub 后：

1. **push / PR** → Actions 自动构建，产物在 Artifacts：
   `systemPro-rootless-deb`、`systemPro-roothide-deb`
2. **打 tag 发布**：
   ```bash
   sh Scripts/bump-version.sh 0.0.1-2
   git add -A && git commit -m "bump 0.0.1-2"
   git tag v0.0.1-2 && git push origin main --tags
   ```
   → 自动创建 GitHub Release，附带两个 scheme 的 deb

工作流要点：`macos-14` runner + `brew install ldid xz` + Theos（含 theos/sdks）,矩阵构建
`rootless` / `roothide` 两个包。

## 版本规则

- 首次 `0.0.1-1`；**小改尾号 +1**（0.0.1-2、0.0.1-3 …）；**功能轮** 0.0.N-1。
- 出包前三处同步（脚本已代劳）：`control` 的 Version、`prefs/Info.plist` 两个 string、
  `prefs/Version.h`；设置面板与 Release 页显示的版本均取自这里。

## 上机先验清单（首装建议逐条过）

1. 手势锁屏：确认系统里有可用的锁屏入口（代码多路降级，失败会静默跳过）
2. 静音小图标：不同 iOS 版本的专注/静音 item 显示条件不同，若不显示需要按系统版本微调强制显示
3. 伪装电量：改完可等系统刷新或注销；个别版本需补 `updateBatteryState:` 刷新
4. 资源库禁用：目前拦回调；若入口仍在，需要补手势层拦截
5. 分隔线类名在个别版本为 `_UITableViewCellSeparatorView`（两个都挂了）

## 开发注意（踩坑记录）

- **面板控制器基类**：PreferenceLoader 的 detail 控制器必须挂在 `PSViewController` / `PSListController`
  系上。纯 `UIViewController` 会在 Settings 点击入口时崩在 `PSListController controllerForSpecifier:`。
  本工程 = `PSListController` 子类 + vendored 私有头（`prefs/PBHeaders/`）+ `-Wl,-undefined,dynamic_lookup` 链接。
- **面板表格必须走框架 specifier 模型**：分节 = group specifier、行 = cell specifier，只重写
  `tableView:cellForRowAtIndexPath:` 自定义样式。自己接管 numberOfSections/numberOfRows 会在
  iOS 16 崩在 `PSListController _tableView:heightForCustomInSection:`（NSRangeException）。
- **bundle 的资源文件必须放 `prefs/Resources/`**：theos 只把这个目录装进 `.bundle`；
  Info.plist 放错位置会导致面板根本无法加载（点了就闪退）。
- **ARC 指针**：`id *` / `T **` 强转与出参在 ARC 下会编译失败，用 `void **` + `(__bridge id)` 或显式所有权限定绕开。
- **logos 文件完整性**：每次批量编辑后跑一遍括号配平 + `%hook`/`%end` 计数再推 CI。

## 与 SystemX 的关系

- 功能面/挂钩点来自 `/var/minis/workspace/sysbox/`（RE 分析包：468 个 hook 全表 +
  三份域报告）。实现思路参考，**代码为本工程自研**。
- 想要继续扩功能（Dock 倒影阴影、图标更换、角标体系、液态玻璃 Dock 等），
  打开 `sysbox_re_full.tar.gz` 里的 `hooks_final.tsv` 与域报告，按「待移植」流程加
  `%hook` + 开关即可。
