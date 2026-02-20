<!-- ESSENMELIA_EXTEND {
  "id": "cn.thebearsoft.bangumi_collection",
  "name": "Bangumi 收藏",
  "description": "获取 Bangumi.tv 用户收藏数据，并以纯 Material 3 组件展示。",
  "author": "BearYe",
  "version": "1.1.0",
  "icon_code": 983057,
  "tags": ["Bangumi", "Anime", "Collection"],
  "permissions": [
    "network",
    "uiInteraction",
    "addEvents"
  ],
  "view": "view.yaml"
} -->

# Bangumi 收藏扩展

这是一个纯 MD3 组件实现的扩展，用于查看 Bangumi.tv 用户的收藏列表。

## 功能
- 输入用户名获取收藏列表
- 支持列表展示与封面预览
- 完全基于 Essenmelia Dynamic Engine 的 YAML + JS 架构

## API 参考
- https://api.bgm.tv/v0/users/{username}/collections

## 更新日志
- **v1.1.0**: 适配全新 Promise API 架构；优化 UI 响应速度。
