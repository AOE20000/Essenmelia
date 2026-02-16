![Logo](docs/assets/Essenmelia.svg)
# 埃森梅莉亚 (Essenmelia)

**埃森梅莉亚 (Essenmelia)** 是一个高度可定制、隐私安全且跨平台的个人记录与追踪工具。它不仅能帮助你记录追过的番剧、小说、电影和电视剧，更通过强大的插件化架构，允许开发者自由扩展功能与界面。

---

## ✨ 核心特性

- **🚀 强大的扩展系统**：采用 JavaScript 逻辑引擎与 YAML 声明式 UI 的混合架构，支持动态加载、双向数据绑定以及 `async/await` 异步编程。
- **🛡️ 隐私保护 (Security Shield)**：内置安全盾牌。非信任扩展在未获得授权时，所有敏感操作（如读取数据）都会被自动拦截或返回伪造数据，确保用户隐私绝对安全。
- **🎨 现代化 UI (Material 3)**：深度适配 MD3 规范，支持动态取色、语义化颜色令牌与文字样式。
- **📅 多维记录管理**：支持自定义步骤追踪、系统日历同步、本地通知提醒以及自动化的标签管理。
- **📦 灵活的分发**：支持 `.zip` 格式扩展包，支持从本地文件、URL 或 GitHub 链接安装扩展。内置扩展开箱即用。

---

## 🏗️ 系统架构

Essenmelia 采用模块化分层设计：

- **Core (核心层)**：定义扩展元数据 (`ExtensionMetadata`) 与权限模型。
- **Runtime (运行时)**：
  - `ExtensionJsEngine`: 基于 Promise 的异步 JS 桥接引擎，支持现代 JS 语法。
  - `DynamicEngine`: 将 YAML 定义渲染为原生 Flutter 组件的 UI 引擎。
- **Manager (管理层)**：负责扩展的自动发现、安装、生命周期管理与更新。
- **Security (安全层)**：`SecurityShield` 负责实时拦截权限请求，提供非阻塞的隐私保护。

> 📖 更多架构细节请参阅：[架构设计文档](assets/docs/architecture.md)

---

## 🛠️ 扩展开发

你可以轻松编写自己的扩展来增强 Essenmelia 的功能。

### 快速开始
一个标准的扩展通常包含：
- `manifest.yaml`: 定义元数据与权限（必须使用标准 camelCase 格式）。
- `view.yaml`: 描述 MD3 界面布局。
- `main.js`: 处理逻辑与 API 调用（支持 `async/await`）。

### 开发资源
- 📝 [扩展开发指南](assets/docs/extensions.md) - 完整技术规范与组件库。
- 🔌 [API 使用文档](assets/docs/api_usage.md) - 详细的 API 调用示例与沙箱说明。
- 🏗️ [创建仓库指南](assets/docs/create_repository_guide.md) - 了解如何托管并分发你的扩展。
- 📂 [代码示例](assets/docs/samples/) - 浏览官方提供的扩展示例。

---
*最后更新：2026-02-16*
