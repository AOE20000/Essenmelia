# 指令网关 (Instruction Gateway)

指令网关是 Essenmelia 的核心系统扩展，负责管理所有来自外部的 API 调用和指令流。

## 核心功能
- **请求拦截**：拦截来自 ADB、Android Intent 或第三方应用的 API 请求。
- **安全验证**：验证请求者的身份 and 权限，确保系统安全。
- **状态监控**：实时统计请求成功/失败率，并记录详细的操作日志。
- **指令路由**：将经过验证的指令转发给对应的系统组件或扩展。

## 开发者说明
本扩展采用 **JS/YAML** 动态 UI 引擎构建，是 Essenmelia 动态化架构的参考实现。

## 权限说明
- `readEvents`: 读取系统事件
- `systemInfo`: 获取设备基本信息
- `notifications`: 发送网关状态通知

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
*Built-in System Extension v2.1.0*
