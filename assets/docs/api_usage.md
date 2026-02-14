# Essenmelia API 使用文档

本文档提供 Essenmelia API 的详细调用示例，包括内部扩展调用和外部系统集成（ADB/Intent）。

---

## 0. 调用与分发

### 0.1 扩展打包格式 (.ezip)
Essenmelia 现在支持 `.ezip` (ZIP) 格式的扩展包。导出时，系统会自动将内联在 manifest 中的视图和逻辑拆分为独立文件：
- `manifest.yaml`: 元数据与权限。
- `view.yaml`: 界面定义。
- `main.js`: 业务逻辑。

这种结构更适合使用 VS Code 等外部编辑器进行开发。

### 0.2 JS 扩展内部调用
在扩展的 `main.js` 中，通过全局对象 `essenmelia` 调用：
```javascript
// 方式 A：使用助手函数
essenmelia.showSnackBar("你好");

// 方式 B：使用通用 call 方法
const events = await essenmelia.call('getEvents', {});

// 调试：输出到控制台
console.log("当前状态:", state);
```

### 0.2 局部状态同步 (Reactive State)
```javascript
// 更新状态并触发 UI 局部刷新
essenmelia.updateState("counter", state.counter);
```

---

## 1. 核心 API 方法

### 1.0 沙箱行为与调试
- **日志记录**: 所有 `console.log` 均会被拦截并展示在“扩展控制台”中，方便开发者实时追踪逻辑执行情况。
- **性能追踪**: 控制台会记录每次 API 调用的耗时与状态变更轨迹。
- **权限模拟**: 支持 `isUntrusted` 模式。当扩展未获得用户授权时：
  - **读操作**: 返回由 `MockDataGenerator` 生成的随机数据。
  - **写操作**: 数据被拦截并存储在扩展专属的 `VirtualSandbox` 内存中，重启后消失。
  - **系统操作**: 弹出权限申请弹窗，同时向扩展返回“操作成功”的假象。

---

### 1.1 `api.addEvent` (创建事件)

创建一个带有自定义属性和提醒的事件。**注意：传入的 `tags` 如果在全局库中不存在，将自动被添加。**

**参数说明：**
- `title` (String, 必填): 事件标题。
- `description` (String, 可选): 事件描述。
- `tags` (List<String>, 可选): 标签列表。
- `imageUrl` (String, 可选): 事件配图的 URL 或本地路径。
- `stepDisplayMode` (String, 可选): 步骤显示模式。可选值：`number` (默认), `firstChar` (首字)。
- `stepSuffix` (String, 可选): 步骤计数的后缀，默认为 "个步骤"。
- `reminderTime` (String/DateTime, 可选): ISO 8601 格式的提醒时间。
- `reminderRecurrence` (String, 可选): 提醒循环模式。可选值：`none` (默认), `daily` (每日), `weekly` (每周), `monthly` (每月)。
- `reminderScheme` (String, 可选): 提醒方案。
  - `notification` (默认): **应用内通知**。指发送到手机系统通知栏的本地通知，受 App 进程生命周期影响。
  - `calendar`: **系统日历**。将事件写入手机自带日历，由系统托管，稳定性最高，无需 App 后台运行。

**JSON 示例：**
```json
{
  "method": "api.addEvent",
  "params": {
    "title": "早起运动",
    "description": "每天早上晨跑 30 分钟",
    "imageUrl": "https://example.com/running.png",
    "stepDisplayMode": "firstChar",
    "stepSuffix": "次运动",
    "reminderTime": "2026-02-15T07:00:00Z",
    "reminderRecurrence": "daily",
    "reminderScheme": "calendar"
  }
}
```

---

### 1.2 `api.addTag` (添加标签)

手动添加一个全局标签。

**参数说明：**
- `tag` (String, 必填): 标签名称。

**JSON 示例：**
```json
{
  "method": "api.addTag",
  "params": {
    "tag": "新标签"
  }
}
```

---

### 1.3 `api.updateEvent` (更新事件)

更新现有事件的属性。**注意：新添加的 `tags` 会自动注册到全局库。**

**参数说明：**
- `id` (String, 必填): 目标事件的 ID。
- `reminderTime` (String/DateTime, 可选): 新的提醒时间。设置为 null 可取消提醒。
- `reminderRecurrence` (String, 可选): 新的循环模式。
- `reminderScheme` (String, 可选): 新的提醒方案（notification/calendar）。
- 其他字段 (title, description, stepDisplayMode 等) 均支持增量更新。

---

### 1.3 UI 与通知 API

这些 API 用于在界面上显示提示或发送通知。

- `showSnackBar(message: String)`: **Flutter 通知条**。在应用界面底部弹出的临时消息（如“保存成功”），仅在应用打开时可见。
- `showNotification(title: String, body: String, ...)`: **系统级通知**。发送到手机顶部状态栏的通知，支持横幅弹出和声音。
  - `title`: 通知标题。
  - `body`: 通知内容。
  - `id` (可选): 通知 ID，用于更新或取消。
  - `payload` (可选): 点击通知时传递的数据。
- `showConfirmDialog(params: Object)`: 弹出确认对话框，返回 `true` (确定) 或 `false` (取消)。
  - **参数对象字段**:
    - `title` (String): 对话框标题。
    - `message` (String): 对话框内容。
    - `okText` (String, 可选): 确认按钮文字，默认“确定”。
    - `cancelText` (String, 可选): 取消按钮文字，默认“取消”。
  - **兼容性**: 同时也支持旧版的 `showConfirmDialog(title, message)` 调用方式。

- `getSystemInfo()`: 获取系统信息（如版本号、平台、是否为平板等）。
- `getSettings()`: 获取应用全局设置。

---

## 2. 外部集成 (External Integration)

Essenmelia 支持通过 ADB 和 Android Intent 进行外部集成，允许第三方应用或自动化脚本控制主程序。

### 2.1 通过 ADB 调用 (调试专用)

利用 Flutter 的 `Service Extension` 机制，可以在连接电脑的情况下直接触发 API。

**命令格式：**
```bash
adb shell "vmservice-hook ext.essenmelia.invokeApi '{\"method\":\"<方法名>\",\"params\":\"<JSON参数字符串>\",\"isUntrusted\":\"<true/false>\"}'"
```

**示例：创建一个 ADB 提醒事件**
```bash
adb shell "vmservice-hook ext.essenmelia.invokeApi '{\"method\":\"addEvent\",\"params\":\"{\\\"title\\\":\\\"来自ADB的提醒\\\",\\\"reminderTime\\\":\\\"2026-02-14T20:00:00Z\\\"}\",\"isUntrusted\":\"false\"}'"
```

---

### 2.2 通过 Android Intent 调用

第三方应用（如 Tasker、自动化助手）可以通过发送隐式 Intent 来与 Essenmelia 交互。

#### A. 调用参数 (Intent Extras)
- **Action**: `com.example.essenmelia.INVOKE_API`
- **Extra `method`** (String): 调用的 API 方法名。
- **Extra `params`** (String): 参数的 JSON 字符串。
- **Extra `isUntrusted`** (Boolean, 可选): 是否以受限模式运行。默认 `false`。
- **Extra `requestId`** (String, 可选): 如果提供，App 将在完成操作后返回 Result。

#### B. 获取返回结果 (Result)
如果调用时携带了 `requestId`，Essenmelia 会通过 `setResult` 返回数据：
- **`requestId`**: 调用时传入的 ID。
- **`success`** (Boolean): 执行是否成功。
- **`result`** (String): 成功时的返回结果（JSON 字符串）。
- **`error`** (String): 失败时的错误信息。

**示例代码 (Android Kotlin):**
```kotlin
val intent = Intent("com.example.essenmelia.INVOKE_API").apply {
    putExtra("method", "addEvent")
    putExtra("params", "{\"title\": \"Intent 快速创建\"}")
    putExtra("requestId", "unique_request_123")
}
startActivityForResult(intent, 1001)
```

---

## 3. 动态引擎逻辑 (Path B)

在扩展的 `logic` 部分使用 API：

```json
{
  "logic": {
    "onTap": [
      {
        "api.addEvent": {
          "title": "从扩展创建",
          "stepDisplayMode": "firstChar",
          "reminderTime": "2026-02-20T12:00:00",
          "reminderRecurrence": "weekly",
          "reminderScheme": "calendar"
        }
      },
      { "state.set": { "last_action": "event_created" } }
    ]
  }
}
```

---

## 4. 常见问题 (FAQ)

**Q: `reminderTime` 必须是 UTC 吗？**
A: 推荐使用 UTC ISO 8601 格式（带 `Z`），但系统也支持解析带时区偏移的字符串。

**Q: 如何取消已经设置的提醒？**
A: 调用 `updateEvent` 并将 `reminderTime` 设置为空字符串或在 JSON 中明确设为 `null`。

**Q: `notification` 和 `calendar` 方案有什么区别？**
A: 
- `notification`: 应用内部调度。优点是支持应用内的自定义交互（如点击按钮完成任务），缺点是如果 App 进程被系统彻底杀死且没有自启动权限，提醒可能会失效。
- `calendar`: 注册到系统日历。优点是由系统服务托管，无需 App 后台运行也能准时提醒，稳定性极高。缺点是不支持复杂的 App 内交互按钮。

---
*最后更新：2026-02-14*
