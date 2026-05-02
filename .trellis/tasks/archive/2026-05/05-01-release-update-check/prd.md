# 任务：release-update-check

## 概述

为 The Archivist 添加“检查更新、下载并由用户确认安装”能力。应用应从 GitHub Releases 获取最新发布信息，基于当前运行平台选择对应的 release asset，并在启动自动检查与设置页手动检查两种入口中提示用户有可用新版本。用户确认后，应用在内部展示下载进度；下载完成后提供“立即安装”入口，由用户主动触发平台安装流程：Windows 拉起 Inno Setup 安装器，Android 拉起系统 APK 安装器。

本任务范围以此 PRD 为准。安装入口和拉起平台安装器属于本次范围；静默安装、绕过系统确认、自动退出当前应用并完成覆盖安装、Android release 签名策略调整不属于本次范围。

## 需求

- 从 GitHub Releases 检查最新版本，解析 release tag、发布时间、更新说明和 assets。
- 当前应用版本必须从运行时版本信息读取（例如 `package_info_plus` / 平台包信息），不能继续在设置页硬编码版本号。
- 版本比较需要兼容 release tag 的 `v` 前缀，例如 `v0.1.0` 与本地 `0.1.0+1`。
- 根据运行平台选择下载资源：
  - Windows 选择 `TheArchivist-*-setup.exe`。
  - Android 选择 `TheArchivist-*.apk`。
- 应用启动后自动检查更新，并在发现新版本时显示非阻塞提示或对话框。
- 设置页提供“检查更新”按钮，用户可手动触发检查。
- 有新版本时，UI 显示最新版本号、当前版本号、更新说明摘要和下载入口。
- 用户选择下载后，在应用内显示下载进度、已下载大小或百分比，并能清楚展示完成、失败、取消等状态。
- 下载完成后提供“立即安装”入口。
- Windows 点击“立即安装”后，应拉起下载好的 Inno Setup `.exe` 安装器；如覆盖安装需要退出当前应用，应在 UI 中提前说明。
- Android 点击“立即安装”后，应拉起系统 APK 安装器；如设备未允许安装未知来源应用，应给出明确提示或引导。
- Android 安装实现需处理必要的 Manifest 权限、`FileProvider` 或等价安全文件暴露机制，以及 Flutter 到原生安装 Intent 的桥接。
- Windows 与 Android 的安装动作都必须由用户显式点击触发，应用不能在后台自动启动安装器。
- 下载功能应使用项目现有网络/状态管理分层，不允许 presentation 层直接调用底层 HTTP 客户端。
- 无新版本、网络失败、GitHub API 失败、未找到当前平台 asset、下载失败、安装器拉起失败时，应给出可理解的用户反馈。
- 更新 UI 必须使用 `SectionCard` 组件承载，与 BangumiConnection、SyncTarget 等设置 section 视觉风格一致。
- 更新卡片从 `_AboutSection` 中提取为独立 section，放置在 About section 之后。
- 按钮统一使用 `FilledButton` / `OutlinedButton` / `TextButton`，不使用自定义 `_DataButton`。
- checking 状态下系统更新图标使用 `AnimatedRotation` 持续旋转。
- 状态文本切换使用 `AnimatedSwitcher` + fade，过渡时长约 200ms。
- updateInfo 面板和下载进度区域的出现/消失使用 `AnimatedSize` + fade，时长约 250ms。
- 版本对比信息应清晰展示当前版本 → 最新版本，最新版本以 accent 色高亮。
- 当前状态以彩色 badge 标签展示（参考 Sync section 的 status badge），区分 checking / upToDate / updateAvailable / downloading / downloaded / installing / error / cancelled 等状态。
- 下载进度条右侧应同时展示百分比和已下载/总大小信息。

## 验收标准

- [ ] 设置页显示的当前版本来自运行时包信息，而不是硬编码字符串。
- [ ] 设置页存在手动“检查更新”入口，点击后会查询 GitHub Releases。
- [ ] 应用启动后会自动执行一次更新检查，并避免在无更新时打扰用户。
- [ ] 当 GitHub Releases 中存在高于当前版本的新版本时，用户能看到当前版本、最新版本和更新说明。
- [ ] Windows 运行时能匹配 `.exe` installer asset；Android 运行时能匹配 `.apk` asset。
- [ ] 用户点击下载后，UI 能展示下载进度，并在下载完成后提示文件已下载。
- [ ] Windows 下载完成后，用户点击“立即安装”能拉起下载的 `.exe` 安装器。
- [ ] Android 下载完成后，用户点击“立即安装”能拉起系统 APK 安装器，或在权限受限时显示可理解的失败/引导提示。
- [ ] 安装动作必须由用户确认触发，不能在后台静默安装。
- [ ] 网络错误、版本解析失败、无匹配 asset、下载失败等场景有明确错误提示。
- [ ] 代码符合 Trellis 中 frontend/backend/architecture 相关分层规范。
- [ ] `flutter analyze` 与现有测试通过，或记录无法运行的原因。
- [ ] 更新 UI 使用 `SectionCard`，与设置页其他 section 视觉风格一致。
- [ ] 按钮使用标准 `FilledButton` / `OutlinedButton`，风格统一。
- [ ] checking 状态下图标持续旋转，状态文本切换有 fade 过渡动画。
- [ ] updateInfo 面板和下载进度区域有 `AnimatedSize` + fade 出现/消失动画。
- [ ] 版本对比清晰展示当前版本与最新版本，最新版本以 accent 色高亮。
- [ ] 状态 badge 使用彩色背景标签区分不同状态。
- [ ] 下载进度条旁显示百分比和字节信息。

## 技术说明

- 当前版本主来源为 `pubspec.yaml` 的 `version: 0.1.0+1`，运行时读取可参考项目已有的 `PackageInfo.fromPlatform()` 用法。
- 项目已有依赖可复用：`dio` 用于请求与下载，`path_provider` 用于保存下载文件，`package_info_plus` 用于读取当前版本，必要时可复用现有 provider 注入模式。
- Release 产物现状：`.github/workflows/release.yml` 在 tag `v*` 时创建 GitHub Release，上传 Windows `TheArchivist-*-setup.exe` 和 Android `TheArchivist-*.apk`。
- 建议新增独立 update feature/data 层，按 `ApiClient → Service/Repository → Provider/Controller → UI` 分层组织。
- 设置页当前存在 `Version 0.1.0` 硬编码，需要改为异步读取当前版本。
- Android 安装 APK 需要额外 Manifest 权限、`FileProvider`、签名策略和原生安装 Intent。实现时需确认当前 release 使用 debug signing 的风险，并在代码或文档中避免误导为“静默自动安装”。
- Windows 启动 Inno Setup 安装器需要处理当前应用进程与覆盖安装的关系；本任务只要求拉起安装器并提示用户按安装器要求关闭当前应用，不要求自动退出当前应用。
- 更新 UI 重构应复用 `SectionCard` 组件，避免再次自定义 Container + border 组合。
- 动画遵循 Motion Contract（~200ms ease-out），不引入重型动画依赖。
- `_DataButton` 在此任务后可考虑从 `settings_page.dart` 移除（其他 section 均不使用），但不在本次范围内。
- `_AboutSection` 重构后只保留 app icon、名称、运行时版本号、版权信息，不再嵌入更新逻辑。

## 相关文件

- `pubspec.yaml`
- `.github/workflows/release.yml`
- `CHANGELOG.md`
- `lib/features/settings/presentation/settings_page.dart`
- `lib/shared/network/bangumi_api_client.dart`
- `lib/features/bangumi/data/providers.dart`
- `windows/installer/setup.iss`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/thearchivist/app/MainActivity.kt`
- `.trellis/spec/architecture/system-boundaries.md`
- `.trellis/spec/backend/directory-structure.md`
- `.trellis/spec/backend/error-handling.md`
- `.trellis/spec/frontend/network-guidelines.md`
- `.trellis/spec/frontend/state-management.md`
- `.trellis/spec/frontend/design-system.md`
- `lib/shared/widgets/section_card.dart`

## 非目标范围

- 不实现 Windows 静默安装或绕过用户确认的安装。
- 不实现 Android 静默安装或绕过系统安装确认。
- 不调整 Android release 签名策略。
- 不改变 GitHub Release workflow 的产物命名或发布流程，除非实现过程中发现当前命名无法被可靠识别。
- 不接入 Play Store、Microsoft Store 或任何第三方更新服务。
