<!-- ESSENMELIA_EXTEND {
  "id": "com.essenmelia.event_test",
  "name": "事件列表测试",
  "description": "展示并操作系统中的事件，用于测试列表渲染、数据同步及权限管理。",
  "author": "Essenmelia Team",
  "version": "2.0.0",
  "icon_code": 57933,
  "permissions": ["readEvents", "addEvents", "deleteEvents", "systemInfo"],
  "view": "view.yaml",
  "script": "main.js"
} -->

# 事件列表测试 (Event Sandbox)

展示并操作系统中的事件，用于测试列表渲染、数据同步及权限管理。

## 功能
- **查看事件**: 列出系统中的最近事件。
- **创建事件**: 快速生成带有时间戳的测试事件。
- **清空事件**: 批量删除所有事件（需谨慎操作）。

## 权限需求
- `readEvents`: 读取事件列表。
- `addEvents`: 创建新事件。
- `deleteEvents`: 删除事件。
