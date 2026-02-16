# Essenmelia 扩展开发指南

本文档将指导你从零开始开发一个 Essenmelia 扩展。

## 1. 扩展结构

一个标准的扩展包（或 GitHub 仓库）包含以下核心文件：

- `manifest.yaml`: **配置清单**。定义扩展 ID、名称、权限等元数据。
- `view.yaml`: **界面布局**。使用声明式 YAML 语法构建 UI。
- `main.js`: **业务逻辑**。使用 JavaScript 处理交互和 API 调用。

---

## 2. 快速开始：Hello World (计数器)

为了帮助你快速上手，我们在内置仓库中提供了一个 `demo.counter` 示例。请参考 `assets/extensions/demo.counter` 目录。

### 第一步：创建 manifest.yaml

这是扩展的身份证。

```yaml
id: my.first.extension
name: 我的第一个扩展
description: 这是一个简单的计数器演示。
version: 1.0.0
author: Me
icon_code: 0xe87f # face (Material Symbols 代码点)
permissions:
  - notifications # 申请通知权限
view: view.yaml
script: main.js
```

### 第二步：编写界面 (view.yaml)

Essenmelia 使用 YAML 来描述 Flutter 组件树。关键点是使用 `$state.key` 语法绑定 JS 中的数据。

```yaml
type: Column
children:
  - type: Text
    text: "当前计数: $state.count" # 绑定 count 状态
    style: displayMedium
    
  - type: Row
    children:
      - type: FilledButton
        text: "增加"
        icon: 0xe145 # add 图标
        onTap: "increment" # 绑定 JS 函数
```

**常用组件**:
- 容器: `Container`, `Padding`, `Column`, `Row`, `Stack`, `Card`
- 内容: `Text`, `Icon`, `Image`
- 交互: `FilledButton`, `OutlinedButton`, `IconButton`, `TextField`

### 第三步：编写逻辑 (main.js)

JavaScript 运行在沙箱中，你可以使用现代的 `async/await` 语法调用系统 API，并通过直接修改 `state` 对象来更新界面。

```javascript
// 初始化钩子
function onLoad() {
    // 初始化状态，界面会自动更新
    state.count = 0;
}

// 对应 view.yaml 中的 onTap: "increment"
function increment() {
    // 直接修改 state 属性，无需手动调用 updateState
    state.count++;
    
    // 调用系统 API (支持 async/await)
    if (state.count === 5) {
        showNotification();
    }
}

async function showNotification() {
    // 调用 API
    await essenmelia.showSnackBar("加油！你已经点击了 5 次");
    
    // 也可以调用更复杂的 API，如弹窗
    const confirmed = await essenmelia.showConfirmDialog({
        title: "继续吗？",
        message: "你已经点击了很多次了。"
    });
    
    if (confirmed) {
        console.log("用户选择继续");
    }
}
```

---

## 3. 调试与安装

### 本地调试
1. 将扩展文件夹放入手机/模拟器的 `Essenmelia/extensions/` 目录（如果支持文件管理）。
2. 或者将文件夹压缩为 `.zip`，在应用中选择 "从文件安装"。
3. **推荐**：在开发模式下，可以直接在 `assets/extensions/` 目录下创建扩展文件夹，重启应用即可自动加载。

### 发布到 GitHub
1. 创建 GitHub 仓库。
2. 上传上述文件。
3. 在仓库设置中添加 topic: `essenmelia-extend`。
4. 在 `README.md` 中添加发现元数据（详见 [create_repository_guide.md](create_repository_guide.md)）。
5. 在应用中搜索你的 GitHub 用户名即可安装。

---

## 4. API 参考

### 全局对象 `essenmelia`

- `state`: 响应式状态对象。修改 `state.prop = value` 会自动更新 UI。
- `essenmelia.call(method, params)`: 通用 API 调用方法，返回 Promise。
- `essenmelia.showSnackBar(message)`: 显示提示条。
- `essenmelia.showConfirmDialog(options)`: 显示确认对话框。
- `essenmelia.getEvents()`: 获取事件列表（需权限）。
- `essenmelia.addEvent(event)`: 添加事件（需权限）。

### 生命周期
- `onLoad()`: 扩展加载完成时调用。
- `onEvent(event)`: 收到系统事件时调用。
