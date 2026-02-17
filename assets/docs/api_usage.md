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

---

## 1. 常用 API

### 1.1 `essenmelia.showSnackBar(message)`
显示底部的提示条。

- **参数**: `message` (String)
- **返回**: `Promise<void>` (显示完成后 resolve)

```javascript
await essenmelia.showSnackBar("操作成功！");
```

### 1.2 `essenmelia.showConfirmDialog(options)`
显示确认对话框。

- **参数**: 
  - `options` (Object): `{ title, message, confirmLabel, cancelLabel }`
- **返回**: `Promise<boolean>` (点击确认返回 true，点击取消返回 false)

```javascript
const confirmed = await essenmelia.showConfirmDialog({
    title: "删除确认",
    message: "你确定要删除这条记录吗？",
    confirmLabel: "删除",
    cancelLabel: "取消" // 可选
});

if (confirmed) {
    // 执行删除逻辑
}
```

### 1.3 `essenmelia.getEvents()`
获取当前数据库中的所有事件。需要 `readEvents` 权限。

- **返回**: `Promise<Array<Event>>`

```javascript
const events = await essenmelia.getEvents();
// events[0].title, events[0].id 等
```

### 1.4 `essenmelia.addEvent(eventData)`
创建一个新事件。需要 `addEvents` 权限。

- **参数**: 
  - `eventData` (Object): `{ title, description, tags, ... }`
- **返回**: `Promise<void>`

```javascript
await essenmelia.addEvent({
    title: "新任务",
    description: "这是由扩展创建的任务",
    tags: ["扩展", "自动"]
});
```

### 1.5 `essenmelia.call(method, params)`
通用 API 调用入口。用于调用那些没有封装成快捷方法的底层 API。

- **参数**:
  - `method` (String): API 方法名
  - `params` (Object): 参数对象
- **返回**: `Promise<any>`

```javascript
// 调用底层 httpGet 接口
const response = await essenmelia.call('httpGet', { 
    url: 'https://api.github.com/zen' 
});
```

---

## 2. 权限与沙箱

### 2.1 权限声明
所有 API 调用均受权限系统保护。你必须在 `README.md` 中声明所需权限，否则调用会失败或被拦截。

```json
"permissions": [
  "readEvents",
  "notifications"
]
```

### 2.2 安全盾牌 (Security Shield)
如果扩展未获得用户授权（Untrusted 状态），API 调用不会直接报错，而是会被 `SecurityShield` 拦截：

- **读操作**（如 `getEvents`）：返回伪造的随机数据（Mock Data）。
- **写操作**（如 `addEvent`）：返回成功，但数据仅写入内存沙箱，重启即丢失。
- **敏感操作**：可能会弹出系统授权对话框。

这种机制确保了即使用户运行了恶意扩展，其真实隐私数据也不会泄露。
