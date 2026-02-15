# Essenmelia 扩展仓库创建指南

要创建一个符合 Essenmelia 要求的扩展仓库，你需要准备一个符合特定结构的 GitHub 仓库。应用通过 GitHub 全局搜索来发现和安装扩展。

---

## 1. 核心结构

仓库即扩展。一个标准的扩展仓库应在根目录下包含以下文件：

- `manifest.yaml`: **核心元数据**。定义扩展 ID、名称、作者等。
- `view.yaml`: **UI 布局**。定义扩展的交互界面。
- `main.js`: **逻辑脚本**。处理交互行为与 API 调用。
- `README.md`: 包含 HTML 元数据注释（见下文），以便应用发现仓库和检查更新。

---

## 2. 让应用发现你的扩展 (GitHub Search)

应用会通过 GitHub API 在全球范围内搜索包含特定标记的仓库。你必须在 `README.md` 中添加以下 HTML 注释：

```html
<!-- ESSENMELIA_EXTEND {
  "id": "com.example.my_extension",
  "name": "我的超级扩展",
  "author": "你的名字",
  "version": "1.0.0",
  "description": "这是扩展的简短描述",
  "tags": ["工具", "效率"]
} -->
```

**关键点：**
- 必须包含 `ESSENMELIA_EXTEND` 关键字。
- 必须是有效的 JSON 格式。
- **强制要求**：必须为仓库添加 `essenmelia-extend` 话题（Topic），否则应用将无法在在线商店中发现该扩展。

---

## 3. 部署与分发

1. **创建仓库**: 在 GitHub 上创建一个新的公开仓库。
2. **设置 Topic**: 在仓库设置中添加 `essenmelia-extend` 标签。
2. **编写代码**: 将 `manifest.yaml`, `view.yaml`, `main.js` 上传到仓库根目录。
3. **更新 README**: 添加上述 HTML 元数据注释。
4. **测试**:
   - 打开 Essenmelia 应用 -> 扩展。
   - 点击添加按钮。
   - 点击刷新按钮。
   - 点击安装，应用将自动下载整个仓库的 ZIP 并解析。

---

## 4. 常见问题

- **仓库必须是公开的吗？**: 是的，目前仅支持公开仓库的匿名下载。
- **如何更新扩展？**: 只需修改仓库README.md文件中的`version` 字段。应用会提示用户有新版本可用。
- **如何处理多语言？**: 建议在 `main.js` 中根据 `essenmelia.call('getLocale')` 返回的结果动态更新状态。
