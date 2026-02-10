---
alwaysApply: true
---
# 项目构建与环境维护注意事项

本项目运行在 Flutter 预览版 (3.38.9) 环境下，由于涉及 Gradle 8.x 的 Lazy Property 特性以及 Windows 中文路径兼容性，构建环境相对敏感。后续维护请务必参考以下说明。

---

## 1. 核心构建环境
- **Flutter SDK**: `3.38.9` (Preview/Master channel)
- **Gradle**: `8.10.2`
- **Android Gradle Plugin (AGP)**: `8.7.3`
- **Kotlin**: `2.1.0`
- **NDK Version**: `28.2.13676358` (必须显式指定)

---

## 2. 关键修复与注意事项

### A. Android SDK 36 兼容性陷阱
**问题**：目前部分现代插件（如 `androidx.activity:1.12.2+`）强制要求 Android SDK 36 (Preview)。但本地 SDK 36 目录若缺失 `android.jar`，会导致 Gradle 抛出 `Cannot query the value of this provider` 错误。

**对策**：
- 项目已通过 `android/build.gradle.kts` 中的 `resolutionStrategy` 强制将 `androidx` 系列核心库降级到 SDK 35 兼容版本。
- **严禁**：在未修复 SDK 36 环境前，不要随意运行 `flutter pub upgrade --major-versions`。
- **新增插件**：如果引入新插件导致构建报错，请在根目录 `build.gradle.kts` 的 `subprojects` 块中添加相应的 `force` 降级规则。

### B. Windows 中文路径兼容性
**问题**：如果项目位于含有中文的路径下（例如用户名为 `阿哈`），Kotlin 增量编译会因路径编码问题崩溃。

**对策**：
- `android/gradle.properties` 中已配置 `kotlin.incremental=false` 以禁用增量编译。
- 强制设置了 `-Dfile.encoding=UTF-8`。
- **操作建议**：每次添加新插件或修改原生代码后，若构建失败，请先执行 `flutter clean`。

### C. 依赖版本锁定
- **Riverpod**: 锁定在 `^2.5.1`。项目目前大量使用 `StateNotifier`，不支持 Riverpod 3.0 的破坏性更新。
- **compileSdk / targetSdk**: 统一锁定在 `35`。

### D. 动态图标 (Material 3 Dynamic Color Icon)
**问题**：`flutter_launcher_icons` 插件在当前 Windows 环境下无法直接处理 SVG 转换为 Android Vector Drawable (VD)，导致 Android 13+ 的动态取色图标无法自动生成。

**对策**：
- 在 `pubspec.yaml` 中，`monochrome_android` 指向 PNG 以通过构建。
- **手动补全**：如果需要修复动态图标，需将 SVG 转换为 Android 兼容的 Vector XML，放置在 `res/drawable/ic_launcher_monochrome.xml`，并手动创建 `res/mipmap-anydpi-v33/launcher_icon.xml` 引用它。
- 当前状态：由于环境工具链限制，动态图标需手动维护，插件仅处理标准/自适应 PNG 图标。

---

## 3. 常见报错排查

| 错误信息 | 原因 | 解决方法 |
| :--- | :--- | :--- |
| `Cannot query the value of this provider...` | 依赖项强制指向了损坏的 SDK 36 | 检查根目录 `build.gradle.kts` 的降级策略 |
| `NDK from ndk.dir disagrees with android.ndkVersion` | NDK 路径或版本不匹配 | 检查 `app/build.gradle.kts` 的 `ndkVersion` |
| `Unresolved reference: StateNotifier` | Riverpod 被错误升级到了 3.x | 将 `flutter_riverpod` 降回 `^2.5.1` |
| 莫名其妙的路径编码错误 | 中文路径下的 Kotlin 缓存冲突 | 执行 `flutter clean` 并重启编辑器 |

---

## 4. 建议的开发流程
1. **添加插件**：`flutter pub add <plugin_name>`
2. **检查构建**：`flutter build apk --release`
3. **若失败**：
   - 检查控制台输出的 `dependencies` 树，找出哪个库要求了 SDK 36。
   - 在根目录 `build.gradle.kts` 拦截该库。
   - `flutter clean` 后重试。

---
*最后更新日期：2026-02-10*
