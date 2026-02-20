# Essenmelia API 使用文档

本文档提供 Essenmelia API 的详细调用示例。所有 API 调用均通过全局对象 `essenmelia` 进行。

---

## 0. 核心概念

### 0.1 异步调用 (Async/Await)
Essenmelia 的 JS 引擎已全面升级为 Promise 架构。推荐使用 `async/await` 语法来编写逻辑，避免回调地狱。

```javascript
// ✅ 推荐写法
async function refreshData() {
    try {
        const events = await essenmelia.getEvents();
        console.log("获取到 " + events.length + " 个事件");
    } catch (e) {
        console.error("获取失败: " + e);
    }
}
```

### 0.2 响应式状态 (Reactive State)
全局对象 `state` 是一个 Proxy。**直接给属性赋值**即可触发 UI 的自动更新。无需手动调用 `updateState`（虽然该方法仍被保留用于兼容性）。

```javascript
// ✅ 推荐写法：直接赋值
state.counter = 1; 
state.isLoading = true;

// 界面中绑定了 $state.counter 的文本会自动变为 "1"
```

### 0.3 参数自动转换 (Type Coercion)
得益于宿主环境的 `ApiParams` 升级，API 调用时的参数类型更加宽松。系统会自动尝试将字符串转换为所需的类型。

```javascript
// ✅ 即使后端需要 int，传入 string 也能自动转换
await essenmelia.call('setVolume', { value: "50" }); // 自动转为 50

// ✅ 布尔值转换
await essenmelia.call('enableFeature', { active: "true" }); // 自动转为 true
```

---

## 1. API 参考手册

### 1.1 系统与网络 (System & Network)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `httpGet` | `network` | 发送 GET 请求 | `{ url: "https://api.example.com/data", headers: { "Authorization": "Bearer..." } }` |
| `httpPost` | `network` | 发送 POST 请求 | `{ url: "...", headers: {}, body: JSON.stringify(data) }` |
| `httpPut` | `network` | 发送 PUT 请求 | `{ url: "...", body: ... }` |
| `httpDelete` | `network` | 发送 DELETE 请求 | `{ url: "..." }` |
| `openUrl` | `network` | 在系统浏览器中打开链接 | `{ url: "https://google.com" }` |
| `getSystemInfo` | `systemInfo` | 获取系统信息 (平台, 版本, 语言) | 无 |
| `getDbSize` | `manageDb` | 获取扩展数据库占用大小 | `{ extensionId: "..." }` |

### 1.2 文件操作 (File System)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `exportFile` | `fileSystem` | 导出文件并调起系统分享 | `{ content: "Hello World", fileName: "note.txt" }` |
| `pickFile` | `fileSystem` | 选择并读取本地文件 | `{ allowedExtensions: ["txt", "md", "json"] }` |

### 1.3 任务事件 (Events)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `getEvents` | `readEvents` | 获取所有任务事件 | 无 |
| `addEvent` | `addEvents` | 添加新任务 | `{ title: "买牛奶", description: "记得买脱脂的", tags: ["生活"] }` |
| `deleteEvent` | `deleteEvents` | 删除任务 | `{ id: "event-uuid-123" }` |
| `updateEvent` | `updateEvents` | 更新任务详情 | `{ event: eventObject }` |
| `addStep` | `updateEvents` | 为任务添加子步骤 | `{ eventId: "...", description: "第一步..." }` |
| `setSearchQuery` | `navigation` | 触发全局搜索过滤 | `{ query: "关键字" }` |
| `publishEvent` | `systemInfo` | 发送系统广播 (跨扩展通信) | `{ name: "custom_event", data: {}, extensionId: "..." }` |

### 1.4 标签管理 (Tags)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `getTags` | `readTags` | 获取所有标签 | 无 |
| `addTag` | `manageTags` | 添加新标签 | `{ tag: "工作" }` |
| `deleteTag` | `manageTags` | 删除标签 | `{ tag: "工作" }` |

### 1.5 界面交互 (UI & Interaction)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `showSnackBar` | `uiInteraction` | 显示底部提示条 | `{ message: "操作成功" }` |
| `showConfirmDialog` | `uiInteraction` | 弹出确认对话框 | `{ title: "确认", message: "是否继续？", confirmLabel: "是", cancelLabel: "否" }` |
| `showNotification` | `notifications` | 发送系统通知 | `{ title: "提醒", body: "该喝水了", payload: "route://water" }` |
| `navigateTo` | `navigation` | 跳转应用内路由 | `{ route: "/settings" }` |
| `getThemeMode` | `systemInfo` | 获取当前主题 ('light'/'dark') | 无 |
| `getLocale` | `systemInfo` | 获取当前语言代码 (如 'zh') | 无 |

### 1.6 扩展存储 (Settings)

| 方法名 | 权限 | 说明 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `getSetting` | `systemInfo` | 读取扩展私有配置 | `{ key: "apiKey" }` |
| `saveSetting` | `systemInfo` | 保存扩展私有配置 | `{ key: "apiKey", value: "123456" }` |

---

## 2. 调用示例

### 通用调用方式
除了部分常用方法 (如 `getEvents`) 被直接挂载在 `essenmelia` 对象上外，所有方法均可通过 `call` 接口调用：

```javascript
// 调用 httpGet
const html = await essenmelia.call('httpGet', { 
    url: 'https://example.com' 
});

// 调用 showSnackBar
await essenmelia.call('showSnackBar', { 
    message: 'Hello World' 
});
```

### 快捷方法
为了方便开发，以下方法可直接调用：
- `essenmelia.getEvents()`
- `essenmelia.addEvent(data)`
- `essenmelia.showSnackBar(msg)`
- `essenmelia.showConfirmDialog(opts)`

---

## 3. 权限与沙箱

### 3.1 权限声明
所有 API 调用均受权限系统保护。你必须在 `README.md` 中声明所需权限，否则调用会失败或被拦截。

```json
"permissions": [
  "readEvents",
  "notifications"
]
```

### 3.2 安全盾牌 (Security Shield)
如果扩展未获得用户授权（Untrusted 状态），API 调用不会直接报错，而是会被 `SecurityShield` 拦截：

- **读操作**（如 `getEvents`）：返回伪造的随机数据（Mock Data）。
- **写操作**（如 `addEvent`）：返回成功，但数据仅写入内存沙箱，重启即丢失。
- **敏感操作**：可能会弹出系统授权对话框。

这种机制确保了即使用户运行了恶意扩展，其真实隐私数据也不会泄露。
