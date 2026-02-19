# Essenmelia 扩展仓库创建指南

Essenmelia通过GitHub Topic搜索和安装扩展。

---

## 结构

仓库即扩展。一个常规的扩展仓库应在根目录下包含以下文件：

- `view.yaml`: **UI 布局**。定义扩展的交互界面。
- `main.js`: **逻辑脚本**。处理交互行为与 API 调用。
- `README.md`: **信息**。包含包名、扩展名、描述、作者、版本、标签、权限申请。

---

## 让应用发现你的扩展 (GitHub Search)

应用通过 GitHub API 搜索包含`essenmelia-extend`GitHub Topic的仓库。
通过`README.md`获取扩展的信息与权限声明：

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
---

## 部署与分发

1. **创建仓库**: 在 GitHub 上创建一个新的公开仓库。
2. **设置 Topic**: 为仓库添加 `essenmelia-extend` GitHub Topic。
2. **编写代码**: 将 `view.yaml`, `main.js` 上传到仓库根目录。
3. **更新 README**: 添加上述 HTML 格式。
4. **搜索并安装**:
   - 打开 Essenmelia 应用 -> 扩展。
   - 点击添加按钮。
   - 应用仅会自动搜索一次，直到下次冷启动。
   - 搜索并点击你的扩展。
   - 点击安装：
     - 系统将弹出 **统一安装确认窗口**。
     - 窗口内展示详细权限列表、版本信息及完整性校验状态。
     - 点击确认后，直接在当前窗口显示下载与安装进度。
     - 若安装失败，可在窗口内直接查看错误原因并重试。

---

## 更新扩展

修改仓库**README.md**中的`version` 字段，应用会提示用户有新版本可用。