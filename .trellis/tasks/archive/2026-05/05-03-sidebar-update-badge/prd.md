# 任务：sidebar-update-badge

## 概述

侧边栏 Settings 导航项在检测到可用更新时显示 "NEW" 角标，用户点击后跳转到设置页并自动滚动定位到 Updates section。配合全局 mock 预览模式，可在开发环境验证完整交互流程。

## 需求

- 侧边栏 Settings 导航项监听更新状态，当 `UpdateStatus.updateAvailable` 或 `UpdateStatus.downloaded` 时显示 "NEW" 角标。
- 角标样式：accent 色小圆点或文字标签，不喧宾夺主，符合 Stitch editorial 风格。
- 点击带角标的 Settings 导航项，跳转到设置页后自动滚动到 Updates section（使用 `Scrollable.ensureVisible` 或等价机制）。
- 更新状态回到 idle / upToDate / error 时角标自动消失。
- 全局 mock 模式下开启预览数据后角标正常显示，关闭后消失。
- 跳转滚动动画应平滑，时长约 300ms。

## 验收标准

- [ ] 有可用更新时，侧边栏 Settings 项显示 NEW 角标。
- [ ] 点击 Settings 导航项后，设置页自动滚动到 Updates section。
- [ ] 更新已下载或无更新时角标行为正确（显示/消失）。
- [ ] mock 模式开启后角标正常出现，关闭后消失。
- [ ] 滚动动画平滑，不突兀。
- [ ] 角标样式符合设计系统（accent 色、紧凑、不破坏侧边栏布局）。
- [ ] `flutter analyze` 通过。

## 技术说明

- 侧边栏组件位于 `lib/app/app.dart` 或 sidebar 相关文件。
- 更新状态通过 `updateControllerProvider` 获取，可直接 watch。
- 滚动定位需要设置页内部提供 `GlobalKey` 给 Updates section 的 `SectionCard`，或通过 `ScrollController` + `ensureVisible` 实现。
- 路由跳转使用项目现有的路由方案（go_router 或 Navigator）。
- 角标可作为 `Stack` 叠加在导航项文字旁，或作为 `Row` 尾部元素。

## 相关文件

- `lib/app/app.dart`（侧边栏组件）
- `lib/features/settings/presentation/settings_page.dart`（设置页，需提供滚动定位 key）
- `lib/features/update/data/update_controller.dart`（更新状态）
- `lib/features/update/data/providers.dart`（provider 导出）
- `lib/shared/providers/mock_provider.dart`（全局 mock 开关）
- `lib/shared/theme/app_theme.dart`（设计 token）

## 非目标范围

- 不实现其他导航项的角标系统。
- 不实现角标动画（出现/消失不需要渐变，状态驱动即可）。
- 不修改更新检查或下载逻辑本身。
