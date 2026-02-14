# Essenmelia 扩展系统架构设计

本文档详细说明了 Essenmelia 扩展系统的架构设计、安全性模型以及 API 分层逻辑，旨在为后续维护提供参考。

## 1. 系统概览

Essenmelia 扩展系统旨在提供一个高度解耦、隐私安全且易于扩展的插件化框架。系统采用 **JavaScript (JS) 逻辑引擎** 与 **YAML 声明式 UI** 的混合架构。

### 核心设计原则
- **最小权限原则**：扩展默认无权访问任何敏感数据。权限被细化为读、增、改、删等独立项。
- **隐私欺骗 (Shield)**：非信任扩展在未获得授权时，看到的不是“错误”，而是由系统伪造的“假数据”。
- **双向数据绑定**：通过 JS `state` 对象与 YAML 中的 `$state` 占位符，实现 UI 与逻辑的实时响应。
- **解耦分层**：逻辑执行在独立的 JS 隔离环境中，通过消息网关与 Flutter 通信。

---

## 2. 分层架构

### 2.1 逻辑层：`ExtensionJsEngine` (JS Runtime)
`ExtensionJsEngine` 负责在沙箱环境中执行扩展的业务逻辑。

- **核心职责**：
  - 初始化 `flutter_js` 运行时并注入 `essenmelia` 全局 API 对象。
  - 维护扩展的内部 `state`，并同步给 UI 渲染引擎。
  - **性能优化 (Fine-grained Binding)**：为每个状态键维护独立的 `ValueNotifier`。UI 组件仅监听其引用的特定状态，避免全量重绘。
  - **日志追踪**：劫持 `console.log`，通过桥接转发至 Dart 侧的“扩展控制台”。
  - 监听主程序的系统事件并触发 `onEvent` 回调。
- **非阻塞初始化**：引擎在脚本评估完成后立即标记为 `initialized`。扩展的 `onLoad` 钩子会在后台异步执行，确保 UI 能够即时响应，不会因逻辑耗时而卡在加载界面。
- **状态同步机制**：
  - JS 调用 `updateState(key, value)` -> 发送消息给 Dart -> 更新 `ExtensionJsEngine.state` -> 触发对应键的 `ValueNotifier` -> 局部 UI 刷新。
- **代码参考**：[logic_engine.dart](file:///d:/untitled/Essenmelia/Flutter-New/lib/extensions/logic_engine.dart)

### 2.2 渲染层：`DynamicEngine` (UI Renderer)
渲染层将 YAML 定义转换为 Flutter Widget 树。

- **MD3 令牌映射**：内置了 MD3 颜色和文字样式映射器。开发者可以使用 `primary`, `titleLarge` 等语义化名称，系统会自动根据当前应用主题（亮/暗模式、动态取色）渲染对应样式。
- **响应式渲染**：
  - 自动分析 YAML 中的 `$state.key` 插值。
  - 使用 `ValueListenableBuilder` 包装受影响的组件实现局部刷新。
  - 支持 `Stack`, `Positioned`, `Wrap` 等复杂布局。
- **交互绑定**：任意组件均可通过 `onTap` 属性绑定 JS 函数，由 `GestureDetector` 实现底层拦截。
- **调试支持**：内置“扩展控制台”悬浮窗，可实时查看 JS 日志和内存状态树。
- **代码参考**：[dynamic_engine.dart](file:///d:/untitled/Essenmelia/Flutter-New/lib/extensions/dynamic_engine.dart)

### 2.3 框架层：`ExtensionManager` (核心中枢)
`ExtensionManager` 是整个系统的中枢，负责扩展的生命周期与安全性。

- **职责**：
  - **多文件架构支持**：支持从 Assets 或 ZIP 中加载分离的 `manifest.yaml`, `view.yaml`, `logic.yaml/main.js` 文件。系统会自动在 `assets/extensions/<id>/` 目录下查找这些文件。
  - **权限别名映射 (Permission Aliasing)**：为了兼容旧版扩展，系统会自动将 `write_events` 等旧权限名映射到新版细分权限（如 `addEvents`），并统一处理 `snake_case` 到 `camelCase` 的转换。
  - **安全性校验**：所有扩展在加载时均会进行 SHA-256 完整性校验。内置扩展通过静态哈希比对，外部扩展则通过安装时的哈希锁定来防止篡改。
  - **外部调用路由**：拦截 ADB/Intent 请求，并将其转发给 `system.external_call` 扩展处理。
  - **权限网关**：在 JS API 调用进入业务 Service 前执行权限校验。
- **稳定性保护**：
  - **执行超时**：所有扩展触发的网络请求强制 15 秒超时，防止恶意逻辑挂起主线程。
  - **递归深度限制**：逻辑引擎（Path B）与渲染引擎（Path C）均设置了 50 层的最大递归深度，防止死循环导致应用崩溃。
  - **异常捕获**：所有 API 执行均包裹在 `try-finally` 块中，确保即使逻辑出错，加载状态（Spinning）也能被正确关闭。
- **代码参考**：[extension_manager.dart](file:///d:/untitled/Essenmelia/Flutter-New/lib/extensions/extension_manager.dart)

### 2.2 功能层：Feature Services (API 提供者)
具体的功能 API 由各个业务模块的 Service 提供。

- **实现类**：
  - `EventsExtensionService`：处理事件读写（细分为 Add/Update/Delete）、提醒。
  - `CalendarExtensionService`：对接系统日历 (Read/Write Calendar)。
  - `NotificationExtensionService`：发送系统级通知。
  - `SettingsExtensionService`：访问系统偏好设置、系统信息 (SystemInfo)。
  - `UIExtensionService`：控制动态 UI 交互、界面导航 (Navigation)。
- **分发机制**：`ExtensionApiRegistry` 维护了一个指令集映射表。当框架层通过指令名路由调用时，对应的 Service 会被触发。
- **信任感知**：Service 在执行逻辑时会接收到一个 `isUntrusted` 布尔值。
  - `isUntrusted == false`：执行真实数据库操作。
  - `isUntrusted == true`：调用 `MockDataGenerator` 返回伪造数据。

### 2.3 隐私层：`MockDataGenerator` (盾牌)
这是黑盒欺骗方案的核心实现。

- **职责**：根据数据模型（如 `Event`, `EventStep`）生成随机但结构正确的伪造数据。
- **意义**：确保即使是恶意扩展，在未授权情况下也只能在沙箱中“自嗨”，无法触及用户真实数据。
- **代码参考**：[mock_data_generator.dart](file:///d:/untitled/Essenmelia/Flutter-New/lib/extensions/utils/mock_data_generator.dart)

---

## 3. 安全与权限模型

### 信任级别
1. **已信任 (Trusted)**：用户显式授予完整权限，API 调用直达真实数据。
2. **受限 (Untrusted/Restricted)**：
   - 默认级别。
   - 所有敏感 API 调用都会被 `Shield` 拦截。
   - 扩展只能看到伪造数据。

### 授权流程 (事后授权模式)
1. 扩展发起 `getEvents` 调用。
2. 框架拦截，发现是受限扩展。
3. 框架立即返回 `MockDataGenerator` 生成的假列表。
4. 同时，框架在 UI 层面弹出通知/对话框，告知用户“某扩展正在尝试访问数据”，并提供“本次允许”、“始终允许”等选项。
5. 这种模式保证了扩展逻辑的连续性，同时将最终控制权交还用户。

---

## 4. API 调用数据流

1. **发起**：扩展逻辑代码调用 `api.addEvent({...})`。
2. **路由**：`ExtensionManager` 的 `_invokeApi` 接收请求。
3. **拦截**：执行 `_shieldIntercept` 检查权限。
4. **分发**：根据指令名从 `ExtensionApiRegistry` 找到 Handler。
5. **执行**：
   - `EventsExtensionService` 收到请求。
   - 若 `isUntrusted` 为 `true`，返回 `true`（模拟成功）但不写入数据库。
   - 若 `isUntrusted` 为 `false`，写入真实数据库并返回结果。
6. **响应**：结果经由框架层返回给扩展逻辑。

---

## 5. 维护注意事项

- **添加新 API**：
  1. 在 `ExtensionApi` 接口中添加方法定义。
  2. 在对应的业务 Service 中实现逻辑，务必处理 `isUntrusted` 分支。
  3. 在 `MockDataGenerator` 中确保新字段有对应的伪造逻辑。
  4. 在 `ExtensionManager` 的 `ExtensionApiImpl` 中包装调用。
- **UI 引擎更新**：
  - `DynamicEngine` 负责将 JSON 转换为 Flutter Widget。更新组件支持时，需同时更新 `Path C` 的解析逻辑。

---
*最后更新：2026-02-14*
