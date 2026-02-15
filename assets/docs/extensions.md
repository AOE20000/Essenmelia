# Essenmelia 扩展开发指南

本文档为开发者提供 Essenmelia 扩展系统的完整技术规范。Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的架构，支持动态 UI 渲染与双向数据绑定。

---

## 1. 核心架构

Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的混合架构。推荐使用 **多文件目录结构** 进行开发，并打包为 `.ezip` 格式进行分发。

### 1.1 目录结构
一个标准的扩展目录（或 `.ezip` 包）包含以下核心文件：

- `manifest.yaml`: **扩展元数据**。定义 ID、名称、版本、作者以及**权限申请**。
- `view.yaml`: **声明式 UI 定义**。使用 YAML 语法描述界面布局。
- `logic.yaml` (可选): 声明式逻辑流定义。
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
| `logic` | String | 可选。自定义 JS 脚本路径，默认为 `main.js` | `src/index.js` |

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
- `chip`: 纸片组件。支持 `variant` (`assist`, `filter`, `choice`), `label`, `icon`, `selected`, `stateKey` (双向绑定)。
- `slider`: 滑动条。支持 `stateKey` (双向绑定), `min`, `max`, `divisions`, `label`。
- `textfield`: 输入框。支持 `label`, `hint`, `stateKey` (双向绑定), `noBorder` (隐藏边框)。
- `switch` / `checkbox` / `radio`: 基础选框。支持 `stateKey` (双向绑定)。
- `list_tile`: 标准列表项。支持 `title`, `subtitle`, `icon`, `iconBgColor`, `iconColor`, `showChevron`, `trailing` (自定义尾部组件), `onTap`。
- `any`: 事实上，**所有组件**现在都支持 `onTap` 属性。

---

## 4. JavaScript API (essenmelia 对象)

逻辑引擎在全局注入了 `essenmelia` 对象，用于与主程序交互。

### 4.1 核心方法
- `essenmelia.updateState(key, value)`: 更新状态。系统会自动触发引用该状态的组件进行**局部重绘**。
- `essenmelia.call(method, params)`: 调用主程序底层 API。
- `essenmelia.showSnackBar(message)`: 显示底部提示条。
- `essenmelia.showConfirmDialog(title, message)`: 弹出确认对话框（返回 Promise）。

### 4.2 数据 API
- `essenmelia.getEvents()`: 获取当前事件列表。
- `essenmelia.getTags()`: 获取所有标签。
- `essenmelia.addEvent({title, description, tags})`: 添加新事件。

### 4.3 生命周期与事件
- `onLoad()`: 扩展启动时自动调用。
- `onEvent(name, data)`: 接收主程序分发的系统事件。

---

## 5. 调试与性能

### 5.1 扩展控制台 (Extension Console)
在开发模式下，扩展界面右下角会出现“虫子”图标。点击可打开控制台：
- **日志**: 查看 `console.log` 输出及 API 调用轨迹。
- **状态树**: 实时观察 `state` 变量的数值变化。

### 5.2 性能最佳实践
- **局部重绘**: 系统已实现细粒度绑定。只有在 YAML 中显式引用 `$state.key` 的组件才会在该状态更新时重写渲染。
- **避免大列表全量更新**: 尽量拆分状态键，减少单个 `updateState` 引起的连锁反应。

---

## 6. 示例代码

**manifest.yaml**
```yaml
id: com.example.hello
name: Hello World
version: 1.0.0
```

**view.yaml**
```yaml
type: column
props:
  padding: 16
children:
  - type: text
    props:
      text: "你好, $state.user_name!"
      fontSize: 20
  - type: textfield
    props:
      label: "请输入名字"
      stateKey: "user_name"
  - type: button
    props:
      label: "点击打招呼"
    onTap: sayHello
```

**main.js**
```javascript
var state = {
    user_name: "访客"
};

function sayHello() {
    essenmelia.showSnackBar("Hello " + state.user_name + "!");
}
```
