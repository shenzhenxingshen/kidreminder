# KidReminder（小小提醒官）

一个面向幼儿家庭的 Flutter 提醒应用：
支持孩子/家长录音，自定义任务提醒（可排期）与行为提醒（快捷触发），首页按时间线展示当日计划。

**最新特性**：
- ✅ 开机自动恢复所有闹钟
- ✅ 完善的权限验证与错误提示
- ✅ 智能通知ID算法（支持无限任务）
- ✅ Android 12+ 精确闹钟支持
- ✅ iOS 通知完整配置（声音/角标）
- ✅ 录音项完整管理（编辑/删除/重新录制）
- ✅ 首页时间线拖拽排序
- ✅ 计划页拖拽排序与编辑

## 功能概览

- 自定义提醒
  - 任务提醒：如“该吃饭了”“该洗漱了”（可进入计划）
  - 行为提醒：如“好好说话”“小手轻轻”（快捷触发）
- 录音中心
  - 新建提醒并录音
  - 播放已录语音
  - 鼓励语音录制
- 计划管理
  - 为任务提醒设置时间
  - 启用/关闭任务
  - 拖拽排序任务顺序
  - 编辑/删除任务
- 首页时间线
  - 按时间排序展示任务卡（提前5分钟 + 到点）
  - 长按拖拽排序任务
  - 快速编辑/删除任务
  - 行为提醒按钮区
  - "我做到了"完成计数与鼓励语音
- 本地能力
  - 本地存储（SharedPreferences）
  - 本地通知（flutter_local_notifications）
    - 支持精确闹钟调度
    - 支持开机自启恢复
    - 完善的权限验证
  - 本地录音/播放（record + just_audio）
    - 支持重新录制
    - 支持删除录音文件

- 健壮性设计
  - 完整的错误处理与用户提示
  - 权限拒绝时的友好引导
  - 调试日志支持
  - 降级处理策略

## 技术栈

- Flutter 3.x
- Dart 3.x
- **核心依赖**
  - shared_preferences - 本地数据存储
  - flutter_local_notifications - 本地通知调度
  - record - 录音功能
  - just_audio - 音频播放
  - timezone / flutter_timezone - 时区处理
- **原生集成**
  - Android BroadcastReceiver（开机自启）
  - MethodChannel（Flutter-Android 通信）

## 项目结构

- `lib/main.dart`：主界面与页面交互逻辑、开机广播处理
- `lib/models/app_models.dart`：数据模型（任务/行为/设置）
- `lib/services/storage_service.dart`：本地存储
- `lib/services/audio_service.dart`：录音与播放
- `lib/services/notification_service.dart`：通知调度、权限管理
- `android/app/src/main/kotlin/com/example/kidreminder/BootReceiver.kt`：开机广播接收器
- `test/models/`：模型白盒测试
- `test/services/`：服务层白盒测试

## 本地运行

1. 安装依赖
```bash
flutter pub get
```

2. 启动应用
```bash
flutter run
```

## 测试与检查

```bash
flutter test
flutter analyze --no-pub
```

## 关键权限说明

### Android 权限
所有权限已在 `android/app/src/main/AndroidManifest.xml` 中配置：

- **RECORD_AUDIO** - 麦克风录音权限（用于录制提醒语音）
- **POST_NOTIFICATIONS** - 通知权限（Android 13+）
- **SCHEDULE_EXACT_ALARM** - 精确闹钟权限（Android 12+，确保准时提醒）
- **RECEIVE_BOOT_COMPLETED** - 开机自启权限（重启后自动恢复闹钟）

### iOS 权限
通过 `flutter_local_notifications` 自动处理：

- 麦克风权限说明（录音时系统弹出）
- 通知权限（首次启动时申请，包含 alert/badge/sound）

### 权限处理策略
- ✅ 启动时自动请求通知权限
- ✅ 拒绝时显示友好提示与"去设置"引导
- ✅ Android 12+ 自动检查精确闹钟权限
- ✅ 权限验证失败不阻塞应用运行（降级处理）

## Git 管理建议

已建议忽略构建产物与本地缓存；另外务必忽略密钥、签名、证书、环境配置等敏感文件（见 `.gitignore`）。

## 技术亮点

### 1. 开机自启恢复闹钟
- 使用 Android `BroadcastReceiver` 监听开机广播
- 在后台启动 Flutter 引擎重新调度所有通知
- 支持 `BOOT_COMPLETED` 和 `QUICKBOOT_POWERON` 广播
- 完成后自动清理引擎资源，无内存泄漏

### 2. 智能通知 ID 算法
- 使用任务 ID 的哈希值生成通知 ID
- 支持无限数量的任务而不冲突
- 前置提醒和主提醒使用独立 ID

### 3. 完善的录音管理
- 支持编辑提醒名称和类型（任务/行为）
- 支持重新录制录音
- 支持删除提醒及其录音文件
- 从任务切换到行为时自动清除时间设置

### 4. 拖拽排序功能
- 首页时间线支持长按拖拽排序
- 计划页支持长按拖拽排序
- 排序后自动保存到本地存储
- 排序结果影响首页展示顺序

### 5. 完善的错误处理
- 每个关键步骤都有独立的错误捕获
- 用户友好的 SnackBar 提示
- 调试模式下的详细日志输出
- 降级处理确保应用可用性

### 6. 跨平台兼容性
- Android：支持精确闹钟、开机自启、通知通道配置
- iOS：支持通知详情配置、声音、角标
- 时区自动检测与本地化处理

## 后续可迭代方向

- ~~录音项重命名/删除~~ ✅ 已完成
- 首页高亮"下一条任务"
- 行为提醒统计与家长日报
- 多孩子档案支持
- 云端数据同步
- 自定义通知音效
- 重复提醒（每周/每月）
- 推迟提醒功能（贪睡模式）