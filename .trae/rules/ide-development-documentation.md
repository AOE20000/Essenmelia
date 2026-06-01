---

## alwaysApply: true

# 项目构建与环境维护注意事项

## 本项目运行在 Flutter 3.41.3 环境下，由于涉及 Gradle 8.x 的 Lazy Property 特性以及 Windows 中文路径兼容性，构建环境相对敏感。后续维护请务必参考以下说明。
扩展架构文档：assets\docs\architecture.md
其他文档：assets\docs\

## 1. 核心构建环境

- **Flutter SDK**: `3.41.3` (Stable channel)
- **Dart SDK**: `3.11.1`
- **Gradle**: `8.12`
- **Android Gradle Plugin (AGP)**: `8.9.1`
- **Kotlin**: `2.1.0`
- **NDK Version**: `28.2.13676358` (必须显式指定)
- **Settings**: 使用 Groovy 版本的 `settings.gradle` 以确保 Flutter 插件加载稳定性。

---

## 2. 关键修复与注意事项

### A. Android SDK 36 兼容性

**状态**：项目已迁移至 Android SDK 36 (VanillaIceCream)。

**对策**：

- **本地环境要求**：开发环境必须安装 Android SDK 36 且包含完整的 `android.jar` 文件。
- **配置**：`compileSdk` 和 `targetSdk` 均已设为 `36`。
- **依赖管理**：已移除先前针对 SDK 35 的强制降级策略，允许使用最新版本的 AndroidX 库。

---

### B. 依赖版本维护 (Package Maintenance)

**状态**：由于 Flutter SDK 升级，部分核心包需要进行大版本更新。

**对策**：

- **Riverpod**: **严禁升级至 3.x**。锁定在 `^2.5.1` (Resolvable: `2.6.1`)。项目目前大量使用 `StateNotifier`，不支持 Riverpod 3.0 的破坏性更新。
- **建议升级的包**：
  - `android_alarm_manager_plus`: `^5.0.0` (支持最新的 Android 系统调度)
  - `file_picker`: `^10.3.10`
  - `go_router`: `^17.1.0`
  - `google_fonts`: `^8.0.2`
  - `share_plus`: `^12.0.1`
- **构建工具**: `build_runner` 由于 `hive_generator` 兼容性限制，**必须保持在 `^2.4.13`**。
- **Gradle 结构**: 项目已切换至 Flutter Gradle Plugin (FGP) 结构。如果遇到 `Cannot run Project.afterEvaluate` 错误，请确保 `settings.gradle` 使用 Groovy 编写且插件声明顺序正确。

### C. Windows 中文路径兼容性

**问题**：如果项目位于含有中文的路径下（例如用户名为 `阿哈`），Kotlin 增量编译会因路径编码问题崩溃。

**对策**：

- `android/gradle.properties` 中已配置 `kotlin.incremental=false` 以禁用增量编译。
- 强制设置了 `-Dfile.encoding=UTF-8`。
- **操作建议**：每次添加新插件或修改原生代码后，若构建失败，请先执行 `flutter clean`。

### C. 依赖版本锁定

- **Riverpod**: 锁定在 `^2.5.1`。项目目前大量使用 `StateNotifier`，不支持 Riverpod 3.0 的破坏性更新。
- **compileSdk / targetSdk**: 统一锁定在 `36`。

### D. 增强型常规提醒 (Enhanced Reminders)

**状态**：已移除先前复杂的高级提醒方案，改为增强常规提醒。

**功能**：

- **重复周期**：支持 `每天`, `每周`, `每月`, `每年` 以及 `自定义` 周期。
- **自定义频率**：支持 “每隔 X 分钟/小时/天/周/月/年” 的灵活配置。
- **实现逻辑**：
  - **轮询机制**：移除了 `AndroidAlarmManager`，改用应用内每分钟轮询检查（基于 `NotificationService` 的 `Timer`）。
  - **触发逻辑**：当应用运行时，每分钟会自动检查所有事件的提醒设置，并在匹配的时间点发送本地通知。
  - **性能优化**：系统会缓存具有提醒设置的事件，仅在数据变动时刷新缓存，避免每分钟全量扫描数据库。
  - **系统日历**：同步支持增强后的重复规则（基于 `device_calendar` 的 RecurrenceRule）。

### E. 性能与生命周期优化 (Performance & Lifecycle)

**状态**：已实施全局生命周期管理与空闲检测。

**对策**：

- **生命周期监听**：通过 `appLifecycleProvider` 监听应用前后台切换。进入后台时，会自动暂停非必要的扩展活动和高频轮询优化。
- **空闲检测**：通过 `IdleDetector` 监听用户操作。若超过 5 分钟无操作，应用进入“空闲模式”，进一步降低 CPU 占用。
- **扩展管理**：在后台或空闲时，所有运行中的扩展（JS 引擎）会收到 `onPause` 回调并停止与宿主的非必要通信。

### F. 国际化 (i18n) 维护

**状态**：项目已完成全量 ARB 国际化迁移。

**对策**：

- **ARB 语法**：ARB 文件中的花括号 `{}` 具有特殊含义。若需显示字面量花括号，请使用单引号包裹，例如 `'{' "a": 1 '}'`。
- **生成代码**：修改 `.arb` 文件后需运行 `flutter gen-l10n` 以更新 `AppLocalizations` 类。
- **非 Context 访问**：逻辑层可通过 `ref.read(l10nProvider)` (Riverpod) 访问翻译字符串。

### E. 系统日历权限

**状态**：已添加 `device_calendar` 支持。

**对策**：

- **Android**：已在 `AndroidManifest.xml` 声明 `READ_CALENDAR` 和 `WRITE_CALENDAR`。
- **iOS**：若后续支持 iOS，需在 `Info.plist` 添加 `NSCalendarsUsageDescription`。
- **权限请求**：应用会在用户选择“系统日历”方案时动态请求权限。

### F. 动态图标 (Material 3 Dynamic Color Icon)

**问题**：`flutter_launcher_icons` 插件在当前 Windows 环境下无法直接处理 SVG 转换为 Android Vector Drawable (VD)，导致 Android 13+ 的动态取色图标无法自动生成。

**对策**：

- 在 `pubspec.yaml` 中，`monochrome_android` 指向 PNG 以通过构建。
- **手动补全**：如果需要修复动态图标，需将 SVG 转换为 Android 兼容的 Vector XML，放置在 `res/drawable/ic_launcher_monochrome.xml`，并手动创建 `res/mipmap-anydpi-v33/launcher_icon.xml` 引用它。
- 当前状态：由于环境工具链限制，动态图标需手动维护，插件仅处理标准/自适应 PNG 图标。

### G. 扩展安全性维护 (Security Hardening)

**状态**：已实施完整性校验、隐私盾强化及 JS 注入防护。

**对策**：

- **完整性哈希**：修改 `ExtensionManager` 导入逻辑时，务必确保 `manifestHash` 覆盖 `logicJs` 和 `viewYaml`。严禁改回仅校验 Manifest 的模式。
- **隐私拦截**：在任何涉及用户数据的 API Handler 中，若 `isUntrusted` 为 `true`，**严禁**调用真实 Provider 的数据。必须使用 `MockDataGenerator` 且设置 `mixReal: false`。
- **JS 桥接安全**：
  - 向 JS 注入变量或调用函数时，必须使用 `jsonEncode` 处理参数和标识符。
  - 禁止在 `ExtensionJsEngine` 中使用字符串插值拼接 JS 代码，除非内容是硬编码的。
- **DoS 防护**：权限弹窗已设置 5 分钟冷却时间。若需调整 UI 交互流，请检查 `ExtensionManager._dialogCooldowns`。

---

## 3. 常见报错排查


| 错误信息                                                 | 原因                               | 解决方法                                     |
| ---------------------------------------------------- | -------------------------------- | ---------------------------------------- |
| `Cannot query the value of this provider...`         | 环境变量中 SDK 36 损坏或缺失 `android.jar` | 重新安装 Android SDK 36 (VanillaIceCream)    |
| `NDK from ndk.dir disagrees with android.ndkVersion` | NDK 路径或版本不匹配                     | 检查 `app/build.gradle.kts` 的 `ndkVersion` |
| `Unresolved reference: StateNotifier`                | Riverpod 被错误升级到了 3.x             | 将 `flutter_riverpod` 降回 `^2.5.1`         |
| 莫名其妙的路径编码错误                                          | 中文路径下的 Kotlin 缓存冲突               | 执行 `flutter clean` 并重启编辑器                |
| `ICU Syntax Error`                                   | ARB 文件中的花括号未正确转义                 | 检查并确保非变量花括号已用单引号包裹                       |


---

## 4. 标准化打包流程

为了确保 APK 路径正确且与 GitHub Actions 脚本保持一致，请按照以下步骤打包：

1. **环境清理**（可选）：`flutter clean`
2. **依赖获取**：`flutter pub get`
3. **代码生成**：`dart run build_runner build --delete-conflicting-outputs`
4. **执行打包**：
  - **Debug**: `flutter build apk --debug`
  - **Release**: `flutter build apk --release --no-tree-shake-icons`

**注意**：

- 项目已在 `android/build.gradle.kts` 中配置 `rootProject.buildDir = file("../build")`。这是 Flutter 标准配置，确保 APK 生成在根目录的 `build/` 文件夹下，以便 Flutter 工具链和 GitHub 脚本能正确识别。
- 若需更新图标，请手动运行 `dart run flutter_launcher_icons`。该步骤未包含在 GitHub 自动打包流程中。

---
### 🏷️ 项目概况

| 项目 | 详情 |
|------|------|
| **名称** | Essenmelia（埃森梅莉亚） |
| **版本** | `4.8.2+1` |
| **定位** | 离线优先、高定制化的跨平台进度追踪器 + 扩展枢纽 |
| **Flutter SDK** | `^3.10.8` |
| **平台支持** | Android、iOS、Windows、macOS、Linux、Web |
| **Android SDK** | compileSdk 36 / targetSdk 36 / minSdk 24 |

---

### 🏗️ 核心架构

```
lib/
├── main.dart                          # 应用入口 + GoRouter 路由 + Material 3 主题
├── models/
│   └── event.dart                     # 核心数据模型 (Hive)
├── providers/                         # Riverpod 状态管理
│   ├── events_provider.dart           # 事件 CRUD (StateNotifier)
│   ├── db_provider.dart               # 数据库生命周期管理
│   ├── settings_provider.dart         # 应用设置
│   ├── theme_provider.dart            # 亮/暗/跟随系统 主题
│   ├── locale_provider.dart           # 中/英文国际化
│   ├── tags_provider.dart             # 标签管理
│   └── app_lifecycle_provider.dart    # 应用前后台/空闲检测
├── screens/                           # 页面（HomePage、EventDetail、Settings 等）
├── widgets/                           # 可复用组件（FilterChips、TagInput 等）
├── services/                          # 基础设施服务
│   ├── notification_service.dart      # 本地通知（分钟轮询）
│   ├── calendar_service.dart          # 系统日历集成
│   ├── storage_service.dart           # 文件/图片存储
│   └── app_initialization_service.dart
├── extensions/                        # 🧩 插件扩展系统（核心亮点）
│   ├── core/                          # 基类、元数据、权限定义
│   ├── manager/                       # ExtensionManager（生命周期 + 安全网关）
│   ├── runtime/                       # JS 引擎 + YAML UI 动态渲染
│   ├── security/                      # SecurityShield（隐私欺骗 + 沙箱）
│   └── services/                      # 10+ 个扩展 API 服务
├── l10n/                              # ARB 国际化（中文/英文）
└── features/                          # 快速操作（OCR + 轮廓识别）
```

---

### 🔑 六大核心特性

#### 1. **事件进度追踪**（核心数据模型）
- [Event](file:///d:/untitled/Essenmelia/Flutter-New/lib/models/event.dart) 模型基于 **Hive** 本地数据库，支持：
  - 多步骤管理（自由排序、拖拽、模板复用）
  - 标签系统（空格自动转标签）
  - 图片/封面附件（自动下载远程图片）
  - 置顶、排序、筛选、批量操作

#### 2. **增强型提醒系统**
- [NotificationService](file:///d:/untitled/Essenmelia/Flutter-New/lib/services/notification_service.dart) 使用 **每分钟轮询** 替代 AndroidAlarmManager
- 支持每日/每周/每月/每年 和自定义周期
- 双通道：**本地通知** + **系统日历**（`device_calendar`）
- 前后台状态感知，后台时仍可触发通知

#### 3. **🧩 插件扩展系统**（核心竞争力）
- **JS 逻辑引擎** + **YAML 声明式 UI** 的混合架构
- **隐私欺骗 (SecurityShield)**：非信任扩展看到的是伪造假数据，而非错误
- 通过 GitHub API 发现和安装扩展
- 完整性哈希校验（覆盖 `logicJs` + `viewYaml`）
- JS 注入防护（`jsonEncode` 转义、Promise 桥接）
- 前后台生命周期联动（后台/空闲自动暂停扩展）

#### 4. **Material 3 + Dynamic Color**
- 支持 Android 12+ 动态取色
- 亮/暗/跟随系统 三模式
- 自定义字体（Google Fonts / 系统字体）

#### 5. **国际化 (i18n)**
- ARB 文件驱动，支持中文 + 英文
- Riverpod 提供非 Context 访问（`l10nProvider`）

#### 6. **开放 API (Beta)**
- Deep Link 支持 (`esml://` / `essenmelia://`)
- ADB 命令行操作
- Quick Settings Tile（快速记录磁贴）

---

### ⚠️ 关键约束（来自项目规则文件）

| 约束 | 说明 |
|------|------|
| **Riverpod** | 锁定 `^2.5.1`，禁止升级到 3.x（依赖 StateNotifier） |
| **Android SDK** | compileSdk/targetSdk 统一 36 |
| **中文路径** | 禁用 Kotlin 增量编译（`kotlin.incremental=false`） |
| **build_runner** | 锁定 `^2.4.13`（hive_generator 兼容性） |
| **ARB 花括号** | 字面量需单引号包裹，如 `'{' "a": 1 '}'` |

---

### 📦 主要依赖一览

| 分类 | 核心包 |
|------|--------|
| **状态管理** | `flutter_riverpod ^2.5.1` |
| **数据库** | `hive ^2.2.3` + `hive_flutter` |
| **路由** | `go_router ^17.1.0` |
| **UI** | `flutter_staggered_grid_view`, `flutter_animate`, `google_fonts` |
| **通知** | `flutter_local_notifications ^18.0.1` |
| **日历** | `device_calendar ^4.3.3` |
| **JS 引擎** | `flutter_js ^0.8.4` |
| **ML Kit** | `google_mlkit_text_recognition` + `object_detection` |
| **视频** | `video_player` + `chewie` |
| **平台** | `package_info_plus`, `share_plus`, `file_picker`, `url_launcher` |

*最后更新日期：2026-03-04*