# Essenmelia 扩展开发指南

本文档介绍如何为 Essenmelia 编写自定义扩展。扩展通过受控的 `ExtensionApi` 与主程序交互，实现功能增强。

---

## 1. 核心架构

- **纯壳框架**：主程序仅作为容器，不预装任何扩展 ID。扩展通过导入 JSON 清单安装。
- **声明式权限**：扩展需在元数据中声明所需的权限，主程序根据权限声明控制 API 访问。
- **动态权限流**：支持多种授权模式（如永久允许或单次允许），扩展应在权限状态变化时通过回调重新获取数据。

---

## 2. 快速开始

### 第一步：创建扩展类
继承 `BaseExtension`。构造函数必须接收 `metadata` 以支持动态清单。

```dart
class MyStatsExtension extends BaseExtension {
  MyStatsExtension(super.metadata);

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    // 构建 UI...
  }
}
```

### 第二步：注册逻辑提供者
在 `ExtensionManager` 中将逻辑类与 `ID` 绑定。

```dart
_registerLogic('my_unique_id', (meta) => MyStatsExtension(meta));
```

### 第三步：分发 JSON 清单
扩展以 JSON 文件形式分发，包含基本信息、图标以及可选的元数据字段。

```json
{
  "id": "my_unique_id",
  "name": "我的统计",
  "description": "提供深度数据分析与可视化报表。",
  "author": "Essenmelia Lab",
  "version": "1.0.0",
  "icon_code": 58565,
  "icon_font": "MaterialIcons",
  "permissions": ["readEvents", "readTags"],
  "features": ["月度趋势图", "标签热力分析"],
  "homepage": "https://github.com/example/repo"
}
```

---

## 3. 权限管理 (Permission Management)

系统使用强类型权限控制，支持以下权限标识符（JSON 中支持 `snake_case` 自动转换）：

| 权限 ID | 标签 | 说明 |
| :--- | :--- | :--- |
| `readEvents` | 读取事件 | 访问用户的历史记录与当前事件 |
| `writeEvents` | 修改事件 | 创建、编辑或删除事件 |
| `readTags` | 读取标签 | 查看所有已定义的分类标签 |
| `notifications` | 通知权限 | 发送系统级通知与弹窗提示 |
| `manageDb` | 数据库管理 | 导出、备份或重置数据库 |
| `fileSystem` | 文件访问 | 保存数据到本地存储 |

---

## 4. 安全与限制

### 导入限制
- **文件大小**：JSON 清单建议不超过 **1MB**。超过此大小将触发安全警告。
- **格式校验**：导入时会严格校验 JSON 格式，解析失败将显示详细错误堆栈。

### 存储占用
- 扩展通过 `api.saveSetting` 存储的数据会占用本地数据库。
- 用户可以在扩展详情页查看“存储占用”实时数据。
- 扩展被卸载时，其关联的数据库文件将被彻底物理删除。

---

## 4. API 参考 (`ExtensionApi`)

| 方法 | 说明 | 权限要求 |
| :--- | :--- | :--- |
| `getEvents()` | 获取所有事件列表 | `readEvents` |
| `getTags()` | 获取所有标签 | `readTags` |
| `exportFile(content, name)` | 导出文件并调起分享 | `fileSystem` |
| `saveSetting(key, val)` | 存储扩展专用设置 | 无 |
| `getSetting(key)` | 读取扩展专用设置 | 无 |

---

## 5. 生命周期钩子

- `onInit(api)`：扩展初始化。
- `onDispose()`：清理资源。
- `onEventAdded(event)`：新事件实时推送。
- `onPermissionGranted(permission)`：**重要**：当用户在弹窗中允许权限后触发，应在此重读数据。

---

## 7. 动态引擎 (Path B & C)

Essenmelia 支持通过 JSON 直接定义扩展的 **UI (View)** 与 **逻辑 (Logic)**，实现无需重新编译的动态功能载入。

### 7.1 动态 UI (Path C)
在 JSON 的 `view` 字段中定义组件树。支持以下类型：

#### 布局组件
- `container`: 容器 (padding, margin, color, decoration, alignment, width, height)
- `column` / `row`: 线性布局 (mainAxisAlignment, crossAxisAlignment, mainAxisSize)
- `padding`: 快捷边距包裹
- `center`: 居中包裹
- `expanded` / `flexible`: 弹性布局（必须在 row/column 中使用）
- `sizedbox`: 固定尺寸占位
- `spacer`: 自动占据剩余空间
- `divider`: 分隔线

#### 基础组件
- `text`: 文本显示 (value, fontSize, bold, italic, color, textAlign)
- `icon`: 图标显示 (icon: "home", "settings", "event" 等, size, color)
- `button`: 按钮 (onTap, color)
- `card`: 卡片容器 (elevation, borderRadius, padding, margin)

### 7.2 动作逻辑 (Path B)
在 `logic` 字段中定义状态与动作。
- `onLoad`: 扩展启动时执行的动作序列。
- `actions`: 命名的动作序列定义。
- **支持指令**：
  - `api.getEvents`: 获取数据并存储到 state。
  - `api.getTags`: 获取标签列表。
  - `api.showSnackBar`: 弹出系统提示。
  - `api.navigateTo`: 页面跳转。
  - `api.exportFile`: 导出并分享文件。
  - `list.length`: 计算列表长度。
  - `state.set`: 更新本地状态。

### 7.3 变量引用
在字符串中使用 `${state.myKey}` 引用逻辑引擎中的实时状态。

---

## 8. 最佳实践
1. **防抖与延迟**：UI 渲染应考虑数据加载状态，使用 `FutureBuilder` 或 `CircularProgressIndicator`。
2. **错误处理**：对于 API 调用失败应有妥善处理。
3. **元数据复用**：尽量从 `metadata` 中读取信息，而不是硬编码。
