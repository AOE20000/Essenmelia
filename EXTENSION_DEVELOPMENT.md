# Essenmelia 扩展开发指南

本文档介绍如何为 Essenmelia 编写自定义扩展。

---

## 1. 统一标准：Dart 开发，JSON 分发

为了兼顾开发体验与分发灵活性，Essenmelia 采用了 **“Dart 编写源码，JSON 打包分发”** 的统一模式。

-   **开发态 (Source)**：使用 **Dart** 编写。利用 IDE 的语法提示、类型检查和内置模板。
-   **分发态 (Package)**：统一为 **JSON** 格式。这是应用唯一正式支持的远程安装与分发格式。

### 为什么统一为 JSON？
1.  **动态更新**：JSON 可以在不重新打包 App 的情况下，通过网络下载实现功能更新。
2.  **安全受控**：主程序通过 `DynamicEngine` 严格限制 JSON 扩展能访问的 API 范围，保护用户隐私。
3.  **跨平台**：无需考虑 AOT 编译限制，一套 JSON 逻辑在所有端均可运行。

---

## 2. 开发流程

### 第一步：基于模板编写逻辑
在项目根目录提供了两个高质量的 Dart 扩展源码，您可以直接修改它们：
-   [external_call_extension_source.dart](file:///d:/untitled/Essenmelia/Flutter-New/external_call_extension_source.dart)：展示外部集成与 MD3 动效。
-   [stats_extension_source.dart](file:///d:/untitled/Essenmelia/Flutter-New/stats_extension_source.dart)：展示数据读取与持久化配置。

同时也提供了对应的 JSON 分发版本参考：
-   [外部调用入口扩展.json](file:///d:/untitled/Essenmelia/Flutter-New/外部调用入口扩展.json)
-   [数据洞察扩展.json](file:///d:/untitled/Essenmelia/Flutter-New/数据洞察扩展.json)

### 第二步：测试与预览
将您的 `.dart` 扩展文件拷贝到手机存储，在 App 的“添加扩展”界面选择“从本地文件导入”。
> **提示**：App 支持直接预览 `.dart` 模板的元数据（ID、名称、权限等），方便开发者快速迭代。

### 第三步：打包导出
1.  在 App 中进入您的扩展详情页。
2.  点击 **“导出扩展包 (.json)”**。
3.  系统将自动将您的 Dart 逻辑（Path C 视图与 Path B 逻辑）序列化为标准的 `.json` 格式。

### 第四步：发布
将生成的 `.json` 文件上传到您的 GitHub 仓库，或分享给其他用户。

---

## 3. 扩展清单规范 (JSON)

扩展以 JSON 文件形式分发，包含基本信息、权限声明以及动态逻辑。

```json
{
  "id": "my_unique_id",
  "name": "我的统计",
  "author": "Essenmelia Lab",
  "version": "1.0.0",
  "icon_code": 58565,
  "icon_font": "MaterialIcons",
  "permissions": ["read_events", "read_tags"],
  "view": {
    "type": "column",
    "children": [
      { "type": "text", "value": "欢迎使用 ${state.name}" }
    ]
  },
  "logic": {
    "onLoad": [
      { "state.set": { "name": "统计扩展" } }
    ]
  }
}
```

---

## 4. 权限管理 (Permission Management)

系统使用强类型权限控制。JSON 中支持 `snake_case` 自动转换。

| 权限 ID | 标签 | 说明 |
| :--- | :--- | :--- |
| `read_events` | 读取事件 | 访问用户的历史记录与当前事件 |
| `write_events` | 修改事件 | 创建、编辑或删除事件 |
| `read_tags` | 读取标签 | 查看所有已定义的分类标签 |
| `notifications` | 通知权限 | 发送系统级通知与弹窗提示 |
| `manage_db` | 数据库管理 | 导出、备份或重置数据库 |
| `file_system` | 文件访问 | 保存数据到本地存储 |
| `network` | 网络访问 | 允许扩展访问网络 API |

---

## 5. 安全机制：受限访问 (Restricted Access)

为了保护用户隐私，所有扩展默认运行在沙箱中：
-   **事后授权**：扩展调用敏感 API 时，系统会弹出授权框。
-   **受限模式**：开启“受限访问”后，扩展每次获取敏感数据都需要用户手动确认。
-   **沙箱隔离**：每个扩展拥有独立的存储空间。可以通过“沙箱组 ID”实现扩展间的数据共享。

---

## 6. API 参考 (`ExtensionApi`)

逻辑引擎 (Path B) 支持以下指令：

| 指令 | 说明 | 权限要求 |
| :--- | :--- | :--- |
| `api.getEvents` | 获取事件列表 | `read_events` |
| `api.addEvent` | 创建新任务 | `write_events` |
| `api.httpGet` | 网络请求 | `network` |
| `api.openUrl` | 外部跳转 | `network` |
| `api.publishEvent` | 全局事件 | 无 |
| `api.exportFile` | 分享文件 | `file_system` |
| `api.pickFile` | 读取文件 | `file_system` |
| `state.set` | 更新内部状态 | 无 |

---

## 7. UI 组件参考 (Path C)

支持以下 Material 3 组件：
-   **容器类**：`container`, `card`, `column`, `row`, `listview`
-   **显示类**：`text`, `icon`, `divider`
-   **交互类**：`button`, `segmentedButton`, `switchListTile`
-   **布局类**：`expanded`, `flexible`, `spacer`, `padding`, `center`

---

## 8. 最佳实践 (Material 3)

-   使用 `surfaceContainerLow` 作为卡片背景。
-   标题建议使用 `headlineSmall` 或 `titleMedium`。
-   操作反馈优先使用 `showSnackBar` 或 `showConfirmDialog`。

---

*最后更新：2026-02-14*
