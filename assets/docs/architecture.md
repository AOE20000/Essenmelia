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

### 2.1 逻辑层：`Runtime/JS` (ExtensionJsEngine)
`ExtensionJsEngine` 负责在沙箱环境中执行扩展的业务逻辑。

- **核心职责**：
  - 初始化 `flutter_js` 运行时并注入 `essenmelia` 全局 API 对象。
  - 维护扩展的内部 `state`，并同步给 UI 渲染引擎。
  - **JS 桥接安全 (Injection Prevention)**：
    - 状态同步时，对所有键名执行 `jsonEncode` 转义，防止通过恶意键名进行 JS 注入。
    - 函数调用采用 `globalThis[jsonEncode(name)]` 模式，确保执行路径受控。
  - **异步 Promise 桥接**：实现了基于 Promise 的双向通信，JS 调用 Dart API 时会自动挂起，直到 Dart 返回结果。
  - **日志追踪**：劫持 `console.log`，通过桥接转发至 Dart 侧的“扩展控制台”。
- **状态同步机制**：
  - JS 直接修改 `state` 属性 -> Proxy 拦截 -> 发送消息给 Dart -> 更新 `ExtensionJsEngine.state` -> 触发对应键的 `ValueNotifier` -> 局部 UI 刷新。
- **代码参考**：[extension_js_engine.dart](Flutter-New/lib/extensions/runtime/js/extension_js_engine.dart)

### 2.2 渲染层：`Runtime/View` (DynamicEngine)
渲染层将 YAML 定义转换为 Flutter Widget 树。

- **MD3 令牌映射**：内置了 MD3 颜色和文字样式映射器。开发者可以使用 `primary`, `titleLarge` 等语义化名称，系统会自动根据当前应用主题（亮/暗模式、动态取色）渲染对应样式。
- **响应式渲染**：
  - 自动分析 YAML 中的 `$state.key` 插值。
  - 使用 `ValueListenableBuilder` 包装受影响的组件实现局部刷新。
- **交互绑定**：任意组件均可通过 `onTap` 属性绑定 JS 函数。
- **代码参考**：[dynamic_engine.dart](Flutter-New/lib/extensions/runtime/view/dynamic_engine.dart)

### 2.3 管理层：`Manager` & `Lifecycle`
此层负责扩展的生命周期管理、安装编排与安全性控制。

#### ExtensionManager
`ExtensionManager` 是系统的核心状态容器。
- **核心职责**：
  - **状态维护**：维护已安装扩展列表、运行时状态及可用更新。
  - **权限网关**：集成 `SecurityShield`，在 API 调用前进行权限检查。
- **代码参考**：[extension_manager.dart](Flutter-New/lib/extensions/manager/extension_manager.dart)

#### ExtensionLifecycleService
`ExtensionLifecycleService` 负责编排复杂的安装、卸载与更新流程。
- **统一安装 UI**：
  - 采用 **Callback-based UI Pattern**，将进度反馈 (`onProgress`) 与错误处理逻辑下放给 UI 层。
  - **InstallationConfirmDialog**：集成了版本对比、权限确认、下载进度展示及错误重试功能，提供一站式安装体验，避免了分散的全局弹窗或 SnackBar。
- **安装源支持**：支持 URL (GitHub/Raw)、ZIP 文件、剪贴板导入及本地文件扫描。
- **代码参考**：[extension_lifecycle_service.dart](Flutter-New/lib/extensions/services/extension_lifecycle_service.dart)

### 2.4 安全层：`Security` (SecurityShield)
`SecurityShield` 负责拦截非信任扩展的敏感操作。

- **拦截策略**：
  - **读操作**：返回由 `MockDataGenerator` 生成的随机数据。
  - **写操作**：将数据写入临时的内存沙箱。
  - **权限申请**：当扩展尝试进行敏感操作时，可能会向用户展示权限申请弹窗。
- **DoS 防护**：针对频繁的弹窗请求，内置了冷却机制（Cooldown），防止恶意扩展通过无限弹窗阻塞 UI。
- **代码参考**：[security_shield.dart](Flutter-New/lib/extensions/security/security_shield.dart)

---

## 3. 安全与权限模型

### 信任级别
1. **已信任 (Trusted)**：用户显式授予完整权限，API 调用直达真实数据。
2. **受限 (Untrusted/Restricted)**：
   - 默认级别。
   - 所有敏感 API 调用都会被 `Shield` 拦截。
   - 扩展只能看到伪造数据。
