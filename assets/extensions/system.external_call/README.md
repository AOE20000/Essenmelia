# 指令网关 (Instruction Gateway)

指令网关是 Essenmelia 的核心系统扩展，负责管理所有来自外部的 API 调用和指令流。

## 核心功能
- **请求拦截**：拦截来自 ADB、Android Intent 或第三方应用的 API 请求。
- **安全验证**：验证请求者的身份和权限，确保系统安全。
- **状态监控**：实时统计请求成功/失败率，并记录详细的操作日志。
- **指令路由**：将经过验证的指令转发给对应的系统组件或扩展。

## 开发者说明
本扩展采用 **JS/YAML** 动态 UI 引擎构建，是 Essenmelia 动态化架构的参考实现。

### 权限需求
- `readEvents`: 读取系统事件
- `systemInfo`: 获取设备基本信息
- `notifications`: 发送网关状态通知

---
*Built-in System Extension v2.1.0*
