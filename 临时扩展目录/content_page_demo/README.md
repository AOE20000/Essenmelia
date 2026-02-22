<!-- ESSENMELIA_EXTEND {
  "id": "com.example.content_page_demo",
  "name": "多媒体演示",
  "description": "演示如何使用 registerEventDetailContent API 为事件详情页添加自定义多媒体内容 (视频、Markdown、阅读器)。",
  "author": "Demo User",
  "version": "1.3.0",
  "permissions": [
    "readEvents",
    "uiInteraction"
  ],
  "script": "main.js"
} -->

# 多媒体演示扩展 (Multimedia Demo Extension)

本扩展演示了如何通过 API 向事件详情页注入自定义内容，展示了 Essenmelia 引擎的多媒体支持能力。

## 核心功能 (Features)

1.  **动态内容注入**: 使用 `registerEventDetailContent` API 向事件详情页添加一个新的 Tab 页。
2.  **多媒体组件**:
    *   **Video Player**: 演示网络视频播放、自动播放、循环播放配置。
    *   **Markdown Reader**: 演示 Markdown 文本渲染。
    *   **Novel Reader**: 演示长文本阅读模式。
3.  **动态交互**:
    *   演示了如何在扩展中使用 JS 动态切换 UI 内容（Tab 切换视频/阅读模式）。
    *   使用了 `$variable` 绑定机制实现 Dart 与 JS 的 UI 同步。
4.  **多语言支持 (Multilingual)**:
    *   演示了如何通过检测 `state.locale` (en/zh) 来实现扩展内容的多语言适配。

## 使用说明 (Usage)

1.  确保您至少有一个事件（如果没有，请先创建一个）。
2.  加载此扩展。
3.  点击任意事件的封面图片进入详情页。
4.  向下滑动或点击底部的页面指示器进入第二页（扩展内容页）。
5.  点击 "Video Mode" (视频模式) 和 "Reader Mode" (阅读模式) 按钮体验动态切换。
