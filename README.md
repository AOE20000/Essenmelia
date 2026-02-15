# 埃森梅莉亚 (Essenmelia)

![Logo](docs/assets/Essenmelia.svg)

**埃森梅莉亚 (Essenmelia)** 是一个高度可定制、隐私安全且跨平台的个人记录与追踪工具。它不仅能帮助你记录追过的番剧、小说、电影和电视剧，更通过强大的插件化架构，允许开发者自由扩展功能与界面。

---

## ✨ 核心特性

- **🚀 强大的扩展系统**：采用 JavaScript 逻辑引擎与 YAML 声明式 UI 的混合架构，支持动态加载与双向数据绑定。
- **🛡️ 隐私保护 (Shield)**：内置“黑盒欺骗”机制。非信任扩展在未获得授权时只能访问系统伪造的 Mock 数据，确保用户真实数据绝对安全。
- **🎨 现代化 UI (Material 3)**：深度适配 MD3 规范，支持动态取色、语义化颜色令牌与文字样式。
- **📅 多维记录管理**：支持自定义步骤追踪、系统日历同步、本地通知提醒以及自动化的标签管理。
- **📦 灵活的分发**：支持 `.ezip` 格式扩展包，支持从本地文件、URL 或 GitHub 链接安装扩展。

---

## 🏗️ 系统架构

Essenmelia 采用高度解耦的分层设计：

- **逻辑层 (`ExtensionJsEngine`)**：在沙箱环境中运行 JS 脚本，处理业务逻辑并同步状态。
- **渲染层 (`DynamicEngine`)**：将 YAML 定义转换为响应式的 Flutter Widget 树，支持局部刷新。
- **框架层 (`ExtensionManager`)**：管理扩展生命周期、权限校验与安全网关。
- **隐私层 (`MockDataGenerator`)**：负责生成结构正确的伪造数据以欺骗未授权访问。

> 📖 更多架构细节请参阅：[架构设计文档](assets/docs/architecture.md)

---

## 🛠️ 扩展开发

你可以轻松编写自己的扩展来增强 Essenmelia 的功能。

### 快速开始
一个标准的扩展通常包含：
- `manifest.yaml`: 定义元数据与权限。
- `view.yaml`: 描述 MD3 界面布局。
- `main.js`: 处理逻辑与 API 调用。

### 开发资源
- 📝 [扩展开发指南](assets/docs/extensions.md) - 完整技术规范与组件库。
- 🔌 [API 使用文档](assets/docs/api_usage.md) - 详细的 API 调用示例与沙箱说明。
- 🏗️ [创建仓库指南](assets/docs/create_repository_guide.md) - 了解如何托管并分发你的扩展。
- 📂 [代码示例](assets/docs/samples/) - 浏览官方提供的扩展示例。

---
*最后更新：2026-02-15*
