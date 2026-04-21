# 阶段2-WP3：Bangumi 绑定与自动同步

## 目标

实现 Bangumi 账号绑定和本地 → Bangumi 的自动同步推送。

## 前置依赖

* WP1（API 客户端）必须先完成
* WP2（搜索 UI）可并行但同步推送最好在 WP2 快捷添加之后测试

## 范围

* `flutter_secure_storage` 依赖
* Bangumi Access Token 存储与验证
* `bangumiAuthProvider` — `AsyncValue<BangumiAuth?>`
* 设置页"Bangumi 连接"区块
* 自动同步引擎
* 同步状态轻反馈
* 继续复用 `sourceIdsJson` 保存 Bangumi subject 映射

## 不包含

* Bangumi → 本地的全量拉取导入
* 独立 sync queue 表
* 显式待同步列表和专门重试入口
* 冲突副本查看
* 剧集 / 页数 / 时长进度的远端推送

## 认证流程

1. 用户在设置页找到"Bangumi 连接"区块
2. 输入 Access Token（从 `https://next.bgm.tv/demo/access-token` 获取）
3. 点击"验证并连接"
4. 调用 `GET /v0/me` 确认 token 有效
5. 成功后展示用户名和头像
6. Token 加密存储到 `flutter_secure_storage`
7. 支持断开重连

## 同步引擎

### 对外接口（供 WP2 / WP4 controller 调用）

WP3 对外只暴露一个注入式服务：

```dart
abstract class BangumiSyncService {
  /// 推送收藏状态 / 评分到 Bangumi。
  /// 未绑定、条目无 bangumi sourceId、网络失败时内部处理，调用方不需分支。
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  });
}
```

* WP2 的 `BangumiQuickAddController` 在本地写入完成后调用 `pushCollection`
* WP4 的 `DetailActionsController` 在状态 / 评分变更写入本地后调用 `pushCollection`
* 调用方 **不读取 Token、不判断绑定状态、不处理重试**，只传入本地变更后的结果
* 通过 `bangumiSyncServiceProvider` 暴露，测试时可以注入 mock 实现

### 触发时机（由调用方决定）

* 快捷添加新条目后（WP2 调用）
* 详情页修改状态后（WP4 调用）
* 详情页修改评分后（WP4 调用）

同步策略：
* 本地写入优先，同步是异步后台动作
* UI 反馈"已保存到本地"（与 WP4 一致）
* 同步成功后轻反馈"已同步到 Bangumi"
* 同步失败：只做轻提示和失败记录，不回滚本地数据
* 本阶段不引入独立 sync queue 表、待同步列表或专门重试队列

同步字段：
* 状态（`UnifiedStatus` → `CollectionType`）
* 评分（0-10 整数）
* **本阶段不同步**：剧集 / 页数 / 时长进度
* **不同步**：笔记、标签、自定义列表、review、favorite

前提条件：
* 条目 `sourceIdsJson` 包含 `"bangumi"` key
* 用户已绑定 Bangumi

## 设置页 Bangumi 连接区块

位于设置页现有内容之后：
* 未连接状态：展示说明文案 + Token 输入框 + "验证并连接"按钮
* 已连接状态：展示用户名、头像、"断开连接"按钮
* 视觉遵守现有设置页 Stitch token 规范

## 验收标准

* [ ] 设置页可输入 Token 并验证
* [ ] 验证成功后展示 Bangumi 用户信息
* [ ] Token 加密存储，应用重启后自动恢复
* [ ] 可断开并重新连接
* [ ] 绑定后快捷添加和修改状态/评分自动推送到 Bangumi
* [ ] 未绑定时同步静默跳过
* [ ] 同步失败时本地数据不受影响
* [ ] 同步失败有轻反馈但不打断操作
