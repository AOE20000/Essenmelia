# Essenmelia 扩展开发指南

本文档为开发者提供 Essenmelia 扩展系统的完整技术规范。Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的架构，支持动态 UI 渲染与双向数据绑定。

---

## 1. 核心架构

Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的混合架构。推荐使用 **多文件目录结构** 进行开发，并打包为 `.zip` 格式进行分发。

### 1.1 目录结构
一个标准的扩展目录（或 `.zip` 包）包含以下核心文件：

- `manifest.yaml`: **扩展元数据**。定义 ID、名称、版本、作者以及**权限申请**。
- `view.yaml`: **声明式 UI 定义**。使用 YAML 语法描述界面布局。
- `logic.yaml` (可选): 声明式逻辑流定义（已废弃，推荐使用 main.js）。
- `main.js`: **业务逻辑脚本**。处理事件、状态更新及 API 调用。

---

## 2. 开发规范

### 2.1 扩展元数据 (manifest.yaml)

| 字段 | 类型 | 说明 | 示例 |
| :--- | :--- | :--- | :--- |
| `id` | String | 唯一标识符，建议反向域名格式 | `com.example.app` |
| `name` | String | 扩展显示的名称 | `我的扩展` |
| `version` | String | 版本号 | `1.0.0` |
| `permissions`| List | 申请的系统权限列表 | `["readEvents", "network"]` |
| `view` | String | 可选。自定义视图文件路径，默认为 `view.yaml` | `ui/main.yaml` |
| `script` | String | 可选。自定义 JS 脚本路径，默认为 `main.js` | `src/index.js` |

### 2.2 权限系统 (Dynamic Permissions)

Essenmelia 采用**动态权限绑定机制**。开发者必须在 `manifest.yaml` 中使用标准 `camelCase` 格式声明权限。

- **严格格式**：系统不再支持 `snake_case` 或旧版权限别名。
- **透明展示**：在安装界面，系统会根据 `ExtensionApiRegistry` 动态列出该权限下允许扩展执行的具体操作（如“添加新任务”、“读取日历”等）。

**常用权限：**
- `readEvents`, `addEvents`, `updateEvents`, `deleteEvents`: 事件全生命周期管理。
- `readCalendar`, `writeCalendar`: 系统日历访问。
- `network`: 访问互联网。
- `notifications`: 发送系统通知。
- `systemInfo`: 获取主题颜色、语言、发送提示条。
- `navigation`: 触发界面跳转或搜索。

---

## 3. 现代化 UI 引擎 (MD3)

`DynamicEngine` 已深度适配 **Material Design 3 (MD3)** 规范。

### 3.1 颜色令牌 (Color Tokens)
在 `view.yaml` 中，`color` 或 `textColor` 属性可以使用 MD3 标准色值名称：
- **核心色**：`primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`
- **中性色**：`surface`, `onSurface`, `surfaceVariant`, `onSurfaceVariant`, `outline`
- **功能色**：`error`, `onError`, `tertiary`

### 3.2 文字样式 (Typography)
`text` 组件的 `style` 属性支持标准的 MD3 字阶：
- **标题**：`displayLarge`, `headlineMedium`, `titleLarge` (默认标题风格)
- **正文**：`bodyLarge`, `bodyMedium` (默认文本风格), `bodySmall`
- **标签**：`labelLarge`, `labelSmall`

### 2.2 响应式 UI (view.yaml)

使用 YAML 定义 Material 3 组件树。

**关键特性：**
- **状态插值**: 使用 `$state.key` 引用 JS 侧的状态。
- **双向绑定**: 使用 `stateKey: "key"` 属性实现输入组件（如 `textfield`, `switch`）与状态的自动同步。

---

## 3. UI 组件库

### 3.1 容器与布局
- `column` / `row`: 线性布局。
- `grid_view`: 网格布局。支持 `crossAxisCount` (列数), `mainAxisSpacing`, `crossAxisSpacing`, `childAspectRatio`。
- `card`: MD3 卡片。支持 `variant` (`elevated`, `filled`, `outlined`), `elevation`, `color`, `borderRadius`。
- `settings_group`: **推荐使用的配置分组容器**。支持 `title`, `items` (子组件列表)。自动处理 MD3 圆角卡片背景与子项分割线。
- `container`: 通用容器，支持 `padding`, `margin`, `color`, `borderRadius`。可作为交互区域。
- `stack` / `positioned`: 层叠布局。
- `expanded` / `spacer`: 灵活空间分配。
- `sized_box`: 固定尺寸容器。
- `wrap`: 流式布局。

### 3.2 显示组件
- `text`: 文本。支持 `fontSize`, `bold`, `textColor`, `textAlign`, `maxLines`。
- `icon`: Material 图标。使用 `icon` (16进制编码)。
- `image`: 网络图片。支持 `url`, `fit`, `borderRadius`。
- `badge`: 徽标。支持 `label` (文本), `backgroundColor`, `textColor`。
- `divider`: 分割线。
- `circular_progress` / `linear_progress`: 进度条。支持 `value`, `color`。

### 3.3 交互组件
- `button`: 按钮。支持 `variant` (`filled`, `tonal`, `outlined`), `label`, `icon`, `onTap`。
- `segmented_button`: 分段按钮。支持 `stateKey` (双向绑定), `segments` (包含 `value`, `label`, `icon` 的列表)。
- `switch`: 开关。支持 `value` (绑定 `$state.key`), `onChanged` (绑定 JS 函数)。
- `list_tile`: 列表项。支持 `title`, `subtitle`, `leading` (icon), `trailing` (widget), `onTap`。
