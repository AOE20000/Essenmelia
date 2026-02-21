# Essenmelia 扩展开发指南

本文档为开发者提供 Essenmelia 扩展系统的完整技术规范。Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的架构，支持动态 UI 渲染与双向数据绑定。

---

## 1. 核心架构

Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的混合架构。推荐使用 **多文件目录结构** 进行开发，并打包为 `.zip` 格式进行分发。

### 1.1 目录结构
一个常规的扩展目录（或 `.zip` 包）包含以下文件：

- `view.yaml`: **UI 布局**。定义扩展的交互界面。
- `main.js`: **逻辑脚本**。处理交互行为与 API 调用。
- `README.md`: **信息**。包含包名、扩展名、描述、作者、版本、标签、权限申请。

---

## 2. 开发规范

### 2.1 扩展信息 (README.md)

开发者需在 `README.md` 的**第一行**插入一个包含 JSON 配置的 HTML 注释块：
---
<!-- ESSENMELIA_EXTEND {
  "id": "system.external_call",
  "name": "指令网关",
  "description": "系统级外部请求监控中心。负责拦截、验证并处理来自 ADB、Intent 或第三方应用的 API 调用。",
  "author": "System",
  "version": "2.1.0",
  "icon_code": 984613,
  "tags": ["System", "Gateway", "API"],
  "permissions": [
    "readEvents",
    "addEvents",
    "updateEvents",
    "deleteEvents",
    "readTags",
    "manageTags",
    "notifications",
    "systemInfo",
    "navigation",
    "network",
    "fileSystem",
    "readCalendar",
    "writeCalendar"
  ]
} -->

# 我的扩展标题
这里是扩展的详细说明文档...
```

| 字段 | 类型 | 说明 | 示例 |
| :--- | :--- | :--- | :--- |
| `id` | String | 唯一标识符，建议反向域名格式 | `com.example.app` |
| `name` | String | 扩展显示的名称 | `我的扩展` |
| `version` | String | 版本号 | `1.0.0` |
| `author` | String | 作者名称 | `Alice` |
| `permissions`| List | 申请的系统权限列表 | `["readEvents", "network"]` |
| `view` | String | 可选。自定义视图文件路径，默认为 `view.yaml` | `ui/main.yaml` |
| `script` | String | 可选。自定义 JS 脚本路径，默认为 `main.js` | `src/index.js` |
```
### 2.2 权限系统 (Dynamic Permissions)

Essenmelia 采用**动态权限绑定机制**。开发者必须在 `README.md` 中声明权限。

- **透明展示**：在安装界面 (`InstallationConfirmDialog`)，系统会：
  - 动态列出该权限下允许扩展执行的具体操作（如“添加新任务”、“读取日历”等）。
  - 提供完整的安装进度反馈（下载、校验、解压）。
  - 统一展示错误信息与重试选项，不再依赖分散的全局提示。

**常用权限：**
- `readEvents`, `addEvents`, `updateEvents`, `deleteEvents`: 事件全生命周期管理。
- `readCalendar`, `writeCalendar`: 系统日历访问。
- `network`: 访问互联网。
- `notifications`: 发送系统通知。
- `systemInfo`: 获取主题颜色、语言、发送提示条。
- `navigation`: 触发界面跳转或搜索。

---

## 3. UI 引擎 (DynamicEngine)

`DynamicEngine` 支持 **YAML** 与 **HTML** 两种开发模式，并深度适配 **Material Design 3 (MD3)** 规范。

### 3.1 开发模式选择

#### 模式 A: 混合开发 (推荐)
使用 YAML 定义结构，结合原生组件与 HTML 内容。适合需要高性能列表、复杂交互或 MD3 风格一致性的场景。

```yaml
type: column
children:
  - type: text
    props: { text: "Title", style: headlineMedium }
  - type: html
    props:
      content: "<p>富文本内容 <a href='js:openDetail'>查看详情</a></p>"
```

#### 模式 B: 纯 HTML 模式
直接使用 HTML 字符串作为视图定义。适合文档展示、简单工具或从 Web 迁移的项目。

**配置方式** (在 `README.md` 的 JSON 配置块中)：
```json
"view": "<div style='padding:16px'><h1>Hello</h1><button onclick='location.href=\"js:handleClick\"'>Click Me</button></div>"
```

### 3.2 HTML 支持与 JS 桥接
无论是混合模式还是纯 HTML 模式，HTML 内容均支持以下特性：

- **标签支持**：`div`, `span`, `p`, `h1-h6`, `img`, `ul/ol`, `table`, `a` 等。
- **样式继承**：自动适配当前主题的文字颜色与大小。
- **JS 桥接协议**：
  使用 `js:函数名` 协议调用扩展中的 JavaScript 函数。
  
  ```html
  <!-- 调用无参函数 -->
  <a href="js:refreshData">刷新</a>
  
  <!-- 调用带参函数 (需在 JS 中解析 URL 参数，暂未完全支持自动解包，建议通过状态传递复杂数据) -->
  <a href="js:showDetail">详情</a>
  ```

### 3.3 CSS 样式支持
扩展支持**内联样式 (Inline Styles)** 与**嵌入式样式表 (<style>)**，但受限于 Flutter 渲染机制，仅支持部分 CSS 属性：

- **文本样式**：`color`, `font-size`, `font-weight`, `font-style`, `text-decoration`, `line-height`
- **布局**：`margin`, `padding`, `text-align`, `vertical-align`
- **背景**：`background-color`
- **边框**：`border` (支持 `solid`, `dashed`, `dotted`), `border-radius`
- **显示**：`display: none`, `display: block`, `display: inline`, `display: inline-block`

**注意：**
- 不支持复杂的 CSS 选择器（如 `div > p` 或 `:hover`）。
- 不支持 Flexbox / Grid 布局（建议使用原生 YAML 组件实现布局）。
- 不支持 `position: absolute / fixed`。

### 3.4 颜色令牌 (Color Tokens)
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

---

## 4. 最佳实践 (Best Practices)

### 4.1 任务进度反馈
对于耗时较长的操作（如批量网络请求、数据处理），**强烈建议**使用 `updateProgress` API 向用户反馈进度，而不是频繁更新 UI 或发送 Toast。

```javascript
// ✅ 推荐写法
async function syncData() {
  await essenmelia.updateProgress(0, "开始同步...");
  for (let i = 0; i < items.length; i++) {
    // ... 处理逻辑 ...
    // 更新进度条 (0.0 - 1.0)
    await essenmelia.updateProgress((i + 1) / items.length, `已处理 ${i + 1} 项`);
  }
  // 完成
  await essenmelia.updateProgress(1.0, "同步完成");
}
```

- **优势**：
  - 显示在系统通知栏，不干扰用户当前操作。
  - 避免因频繁 `render` 导致的 UI 卡顿。
  - 进度完成后自动消失。

### 4.2 避免高频 API 调用
系统会对扩展的 API 调用频率进行监测。
- **警告阈值**：
  - UI 操作（如 `showSnackBar`）：约 30次/分
  - 网络请求：约 60次/分
- **后果**：
  - 触发阈值后，系统会弹出**警告通知**。
  - 用户可在通知中点击**“阻止”**，该扩展将被永久屏蔽。
- **建议**：
  - 避免在循环中直接调用 `showSnackBar` 或 `render`。
  - 使用 `updateProgress` 替代频繁的 UI 反馈。
  - 批量处理数据，减少细碎的 API 调用。
