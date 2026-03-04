# Essenmelia 扩展开发指南

本文档为开发者提供 Essenmelia 扩展系统的完整技术规范。Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的架构，支持动态 UI 渲染与双向数据绑定。

---

## 1. 核心架构

Essenmelia 扩展采用 **JavaScript (JS) + YAML** 的混合架构。推荐使用 **多文件目录结构** 进行开发，并打包为 `.zip` 格式进行分发。

### 1.1 目录结构
一个常规的扩展目录（或 `.zip` 包）包含以下文件：

- `view.yaml`: **UI 布局**。定义扩展的交互界面。
- `main.js`: **逻辑脚本**。处理交互行为与 API 调用。
- `README.md`: **信息**。包含包名、扩展名、描述、作者、版本、标签、权限申请。

---

## 2. 开发规范

### 2.1 扩展信息 (README.md)

开发者需在 `README.md` 的**第一行**插入一个包含 JSON 配置的 HTML 注释块：

```html
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
    "addEvents",
    "readEvents",
    "updateEvents"
  ],
  "view": "view.yaml"
} -->

# Bangumi 收藏扩展
这里是扩展的详细说明文档...
```

| 字段 | 类型 | 说明 | 示例 |
| :--- | :--- | :--- | :--- |
| `id` | String | 唯一标识符，建议反向域名格式 | `com.example.app` |
| `name` | String | 扩展显示的名称 | `我的扩展` |
| `version` | String | 版本号 | `1.0.0` |
| `author` | String | 作者名称 | `Alice` |
| `permissions`| List | 申请的系统权限列表 | `["readEvents", "network"]` |
| `view` | String | 可选。自定义视图文件路径，默认为 `view.yaml` | `ui/main.yaml` |
| `script` | String | 可选。自定义 JS 脚本路径，默认为 `main.js` | `src/index.js` |

### 2.2 权限系统 (Dynamic Permissions)

Essenmelia 采用**动态权限绑定机制**。开发者必须在 `README.md` 中声明权限。

- **透明展示**：在安装界面 (`InstallationConfirmDialog`)，系统会：
  - 动态列出该权限下允许扩展执行的具体操作（如“添加新任务”、“读取日历”等）。
  - 提供完整的安装进度反馈（下载、校验、解压）。
  - 统一展示错误信息与重试选项，不再依赖分散的全局提示。

**常用权限：**
- `readEvents`, `addEvents`, `updateEvents`, `deleteEvents`: 事件全生命周期管理。
- `readCalendar`, `writeCalendar`: 系统日历访问。
- `network`: 访问互联网。
- `notifications`: 发送系统通知。
- `systemInfo`: 获取主题颜色、语言、发送提示条。
- `navigation`: 触发界面跳转或搜索。

---

## 3. UI 引擎 (DynamicEngine)

`DynamicEngine` 支持 **YAML** 与 **HTML** 两种开发模式，并深度适配 **Material Design 3 (MD3)** 规范。

### 3.1 开发模式选择

#### 模式 A: 混合开发 (推荐)
使用 YAML 定义结构，结合原生组件与 HTML 内容。适合需要高性能列表、复杂交互或 MD3 风格一致性的场景。

```yaml
type: column
children:
  - type: text
    props: { text: "Title", style: headlineMedium }
  - type: html
    props:
      content: "<p>富文本内容 <a href='js:openDetail'>查看详情</a></p>"
```

#### 模式 B: 纯 HTML 模式
直接使用 HTML 字符串作为视图定义。适合文档展示、简单工具或从 Web 迁移的项目。

**配置方式** (在 `README.md` 的 JSON 配置块中)：
```json
"view": "<div style='padding:16px'><h1>Hello</h1><button onclick='location.href=\"js:handleClick\"'>Click Me</button></div>"
```

### 3.2 组件库 (Components)
支持的组件包括：

#### 3.2.1 布局组件 (Layout)
- **column / row**: 垂直/水平布局
  - `mainAxisAlignment`: 主轴对齐 (`start`, `end`, `center`, `spaceBetween`, `spaceAround`, `spaceEvenly`)
  - `crossAxisAlignment`: 交叉轴对齐 (`start`, `end`, `center`, `stretch`)
  - `padding`: 内边距 (数字或 [top, left, bottom, right])
- **wrap**: 流式布局
  - `spacing`: 子组件间距
  - `runSpacing`: 行间距
- **container**: 通用容器
  - `width / height`: 尺寸
  - `color`: 背景颜色 (十六进制如 `0xFF...` 或预定义颜色名如 `primary`)
  - `borderRadius`: 圆角大小
  - `padding / margin`: 边距
- **card**: 卡片容器
  - `variant`: 样式 (`elevated`, `filled`, `outlined`)
  - `elevation`: 阴影高度
- **center**: 居中容器
- **padding**: 专门的边距容器
  - `padding`: 必须提供，定义内部边距
- **sized_box**: 固定尺寸占位
  - `width / height`: 尺寸

#### 3.2.2 基础组件 (Basic)
- **text**: 文本展示
  - `text`: 文本内容 (支持 `$state.key` 绑定)
  - `textStyle`: 预定义样式名 (如 `titleLarge`, `bodyMedium`, `labelSmall`)
  - `bold`: 是否加粗
  - `fontSize`: 字体大小
  - `textColor`: 文本颜色
- **icon**: 图标
  - `icon`: Material Icons 代码 (整数)
  - `size`: 图标大小
  - `color`: 图标颜色
- **image**: 图片
  - `url`: 图片链接
  - `borderRadius`: 圆角
  - `fit`: 缩放模式 (`cover`, `contain`, `fill`)
- **button**: 按钮
  - `label`: 按钮文字
  - `icon`: 图标代码 (可选)
  - `variant`: 样式 (`filled`, `tonal`, `outlined`, `text`)
  - `onTap`: 点击触发的 JS 函数名
- **ink_well**: 点击水波纹容器
  - `onTap`: 点击事件
  - `borderRadius`: 点击反馈的圆角范围
- **circular_progress_indicator**: 圆形加载进度条
  - `size`: 控件尺寸

#### 3.2.3 多媒体与阅读组件 (Multimedia & Reader)
- **video**: 视频播放器
  - `url`: 视频链接 (支持网络 URL)
  - `autoPlay`: 是否自动播放 (默认 false)
  - `looping`: 是否循环播放 (默认 false)
  - `aspectRatio`: 宽高比 (如 1.77)
- **markdown**: Markdown 渲染器
  - `data`: Markdown 文本内容
  - `selectable`: 是否可选中 (默认 false)
- **novel**: 小说/长文阅读器
  - `text`: 文本内容
  - `fontSize`: 字体大小 (默认 18)
  - `lineHeight`: 行高 (默认 1.8)
  - `backgroundColor`: 背景颜色
  - `padding`: 内边距

#### 3.2.4 输入组件 (Input)
- **text_field**: 文本输入框
  - `label`: 标签文字
  - `hintText`: 占位提示
  - `stateKey`: **核心功能**。双向绑定到 JS `state` 中的指定键值。输入内容会实时同步，无需手动处理事件。
  - `onChanged`: 可选。内容改变时的回调函数。

### 3.3 状态绑定与上下文注入 (State & Context)

#### 3.3.1 状态绑定
- **$variable**: 在 YAML 中通过前缀 `$` 引用 JS `state` 中的变量。例如 `text: "$title"`。
- **Reactive UI**: 当 JS 中的 `state` 发生改变时，绑定了该变量的 UI 组件会自动触发局部刷新和动画过渡。

#### 3.3.2 自动上下文注入 (Context Injection)
在特定场景下，系统会自动向扩展的 `state` 中注入上下文信息，开发者可直接使用：

- **事件详情页 (Event Detail Page)**:
  - `eventId`: 当前正在查看的事件 ID。
  - `locale`: 当前应用的语言代码 (如 `zh_CN`, `en_US`)。
- **onContextChanged(params)**: 仅适用于全局内容页（`eventId: "*"`）。当用户在详情页间切换时调用。
  - `params.eventId`: 新进入的事件 ID。
- **onPause()**: 当应用进入后台、屏幕关闭或系统进入“空闲模式”（长时间无操作）时调用。建议在此处暂停定时器、网络轮询等高耗能任务。
- **onResume()**: 当应用恢复到前台或用户恢复操作时调用。

> **示例**：在 Bangumi 预览扩展中，通过 `state.eventId` 即可知道当前需要为哪个任务搜索信息，而无需用户手动输入。

### 3.4 交互处理
- **onTap**: 支持直接指定 JS 函数名。
- **参数传递**: 在 `onTap` 中支持传递 Map 参数。
  ```yaml
  onTap:
    call: "handleAction"
    params: { id: 123, type: "update" }
  ```

## 4. 性能优化 (Performance Optimization)

### 4.1 智能生命周期管理
系统会自动管理扩展的活跃状态。当应用处于后台或用户长时间未操作（空闲）时，JS 引擎会进入“挂起”状态：
- 所有的 `essenmelia_bridge` 消息将被忽略。
- 系统会触发扩展的 `onPause` 钩子。
- 开发者应主动在 `onPause` 中清理 `setInterval` 或未完成的请求，以降低 CPU 和内存占用。

### 4.2 避免高频 API 调用
系统会对扩展的 API 调用频率进行监测。
- **警告阈值**：
  - UI 操作（如 `showSnackBar`）：约 30次/分
  - 网络请求：约 60次/分
- **后果**：
  - 触发阈值后，系统会弹出**警告通知**。
  - 用户可在通知中点击**“阻止”**，该扩展将被永久屏蔽。
- **建议**：
  - 避免在循环中直接调用 `showSnackBar` 或 `render`。
  - 使用 `updateProgress` 替代频繁的 UI 反馈。
  - 批量处理数据，减少细碎的 API 调用。

## 5. 常见问题与最佳实践 (Pitfalls & Best Practices)

### 5.1 布局崩溃：避免在滚动容器中使用弹性组件
- **现象**：报错 `RenderFlex children have non-zero flex but incoming height constraints are unbounded`。
- **原因**：扩展内容页通常被包裹在 `SingleChildScrollView` 中。在滚动容器内使用 `expanded` 或 `spacer` 会导致它们试图占据“无限”的剩余空间，从而引发崩溃。
- **对策**：使用 `sized_box` (固定尺寸) 或 `padding` 来代替 `spacer` 进行占位。

### 5.2 JS 兼容性：遵循标准语法
- **现象**：脚本加载失败或报错 `SyntaxError`。
- **原因**：内置 JS 引擎可能不支持过于超前的 ES 语法。
- **对策**：
  - 避免使用 **可选链** (`?.`)，改为传统的 `&&` 检查。
  - 避免在全局作用域使用 **顶层 await**，改为在 `onLoad` 中使用 `.then().catch()`。
  - 尽量使用 `var` 或 `let` 声明变量以保证兼容性。

### 5.3 全局扩展：处理上下文切换
- **现象**：在事件 A 中加载了内容，切换到事件 B 后内容依然显示 A 的信息。
- **原因**：全局扩展（`eventId: "*"`）的脚本只会加载一次，不会随页面切换重载。
- **对策**：实现 `globalThis.onContextChanged` 钩子。系统在切换事件详情页时会主动调用此函数，传入新的 `eventId`。

### 5.4 列表绑定：正确的 children 语法
- **现象**：动态生成的列表无法显示。
- **原因**：错误地将变量绑定到了 `type` 而非 `children`。
- **对策**：
  - **正确**：`children: "$myList"`。
  - **错误**：`type: "$myList"`。
  - 确保 JS 端的 `state.myList` 是一个有效的组件数组。

---

## 6. JS 逻辑引擎 (ExtensionJsEngine)

### 6.1 异步与 Promise
Essenmelia 提供了完整的 `Promise` 支持。所有 API 调用均为异步。

```javascript
async function fetchData() {
  try {
    const res = await essenmelia.httpGet('https://api.example.com/data');
    console.log(res);
  } catch (e) {
    console.error(e);
  }
}
```

- **优势**：
  - 显示在系统通知栏，不干扰用户当前操作。
  - 避免因频繁 `render` 导致的 UI 卡顿。
  - 进度完成后自动消失。

---

## 7. 实战案例：Bangumi 收藏扩展 (Case Study)

本节以 `bangumi_collection` 扩展为例，解析如何构建一个包含**表单输入、网络请求、动态列表渲染**的完整应用。

### 5.1 视图布局 (`view.yaml`)

这是一个典型的**表单+列表**结构：
1. **表单区域**：使用 `text_field` 获取输入，通过 `stateKey` 双向绑定 JS 变量。
2. **列表区域**：使用 `$state.collectionList` 动态插入 JS 生成的组件树。

```yaml
type: column
children:
  # --- 1. 表单区域 ---
  - type: card
    props:
      variant: outlined
      margin: [16, 16, 16, 8]
    children:
      - type: column
        props:
          padding: 16
        children:
          # 用户名输入框 (双向绑定 state.username)
          - type: text_field
            props:
              label: "Bangumi 用户名"
              stateKey: "username"
              hintText: "请输入您的 Bangumi ID"
          
          # 间距
          - type: sized_box
            props: { height: 16 }

          # 标签输入框 (双向绑定 state.defaultTags)
          - type: text_field
            props:
              label: "默认标签 (以逗号分隔)"
              stateKey: "defaultTags"
              hintText: "例如: 追番, 动漫"

          # 提交按钮 (绑定 fetchCollections 函数)
          - type: row
            props:
              mainAxisAlignment: end
              padding: [0, 16, 0, 0]
            children:
              - type: button
                props:
                  label: "获取收藏"
                  icon: 0xe8b6 # search icon
                  variant: filled
                  onTap: "fetchCollections"

  # --- 2. 动态列表区域 ---
  # 直接引用 JS 中的 collectionList 数组作为 children
  - type: column
    props:
      padding: 16
    children: $collectionList
```

### 5.2 逻辑实现 (`main.js`)

核心逻辑分为三个步骤：
1. **初始化状态**：设置默认值。
2. **获取数据**：调用 `httpGet`，解析 JSON。
3. **构建 UI**：在 JS 中生成组件对象，赋值给 `state.collectionList`。

```javascript
// 1. 初始化状态
const state = _state;
state.username = state.username || 'user123';
state.defaultTags = state.defaultTags || 'Bangumi';
state.collectionList = state.collectionList || [];
state.loading = false;

// 2. 获取数据函数
async function fetchCollections() {
  if (state.loading) return;

  const username = state.username ? state.username.trim() : '';
  if (!username) {
    await essenmelia.showSnackBar('请输入用户名');
    return;
  }

  state.loading = true;
  
  // 显示加载中提示 (直接更新 UI 列表)
  state.collectionList = [{
    type: 'container',
    props: { height: 100, padding: 20 },
    children: [{
      type: 'text', 
      props: { text: '加载中...', textAlign: 'center' }
    }]
  }];

  try {
    // 启动进度条
    await essenmelia.updateProgress(0, '开始获取收藏...');
    
    const url = `https://api.bgm.tv/v0/users/${username}/collections?limit=50`;
    console.log('Fetching: ' + url);

    // 发送 HTTP 请求 (带 UA 头)
    const resStr = await essenmelia.httpGet(url, {
        'User-Agent': 'EssenmeliaExtension/1.0'
    });
    
    // 解析 JSON (兼容不同返回类型)
    let res;
    try {
        res = typeof resStr === 'object' ? resStr : JSON.parse(resStr);
    } catch (e) {
        console.log('JSON parse error: ' + e);
        return;
    }

    if (res && res.data && Array.isArray(res.data)) {
        // 3. 构建 UI 组件列表
        const newUiList = [];
        const items = res.data;

        // 遍历数据，生成 Card 组件
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            const subject = item.subject || {};
            
            // 构建单个卡片对象
            const card = {
              type: 'card',
              props: {
                variant: 'filled',
                margin: [0, 0, 0, 12],
                onTap: 'openDetail', // 绑定详情点击事件
                params: { id: subject.id } // 传递参数
              },
              children: [{
                type: 'row',
                children: [
                  // 封面图
                  {
                    type: 'image',
                    props: {
                      url: subject.images?.medium || '',
                      width: 80,
                      height: 120,
                      borderRadius: 12
                    }
                  },
                  // 标题信息
                  {
                    type: 'expanded',
                    children: [{
                      type: 'column',
                      props: { padding: 12 },
                      children: [
                        {
                          type: 'text',
                          props: {
                            text: subject.name_cn || subject.name,
                            style: 'titleMedium',
                            bold: true
                          }
                        },
                        {
                          type: 'text',
                          props: {
                            text: subject.summary || '暂无简介',
                            style: 'bodySmall',
                            maxLines: 2
                          }
                        }
                      ]
                    }]
                  }
                ]
              }]
            };
            
            newUiList.push(card);
        }
        
        // 更新状态，触发界面重绘
        state.collectionList = newUiList;
        await essenmelia.updateProgress(1.0, `获取完成，共 ${items.length} 条`);
    }
  } catch (e) {
    console.log('Error: ' + e);
    await essenmelia.showSnackBar('获取失败: ' + e);
  } finally {
    state.loading = false;
  }
}
```

### 5.3 关键技巧总结

1.  **混合开发模式**：
    - 在 YAML 中定义静态的大框架（如输入框、按钮）。
    - 在 JS 中处理动态的列表数据（如 `collectionList`），利用 JS 的灵活性循环生成 UI 对象结构。
    - 使用 `$variable` 在 YAML 中引用 JS 生成的对象树。

2.  **状态驱动 UI**：
    - 不需要手动操作 DOM 或 Widget。
    - 只需修改 `state` 中的变量（如 `state.collectionList = [...]`），Essenmelia 引擎会自动 diff 并更新界面。

3.  **双向绑定简化输入**：
    - `text_field` 的 `stateKey: "username"` 使得输入内容自动同步到 `state.username`，无需手动监听 `onChange` 事件。

4.  **优雅的异步反馈**：
    - 在耗时操作前，先更新 `state.collectionList` 显示“加载中”占位符。
    - 使用 `essenmelia.updateProgress` 在系统通知栏展示精确进度，提升用户体验。

---

## 8. JS API 参考 (API Reference)

在 `main.js` 中，你可以通过全局对象 `essenmelia` 访问以下方法：

### 核心方法
- `essenmelia.call(method, params)`: 调用任意注册的 Dart 扩展 API。
- `essenmelia.getState(key)`: 获取当前状态值。

### 数据操作
- `async essenmelia.getEvents()`: 获取当前用户的任务/事件列表。返回 `Event` 对象数组。
- `async essenmelia.addEvent(event)`: 添加新任务。`event` 对象结构参考 `Event` 模型。
- `async essenmelia.updateEvent(event)`: 更新任务。必须包含 `id` 字段。
- `async essenmelia.deleteEvent(id)`: 删除任务。

### 网络与工具
- `async essenmelia.httpGet(url, headers)`: 发送 GET 请求。返回 JSON 对象或字符串。
- `async essenmelia.showSnackBar(message)`: 显示底部提示条。
- `async essenmelia.showConfirmDialog(options)`: 显示确认对话框。
  - `options`: `{ title, message, confirmLabel, cancelLabel }`
- `async essenmelia.updateProgress(progress, message)`: 更新通知栏进度条 (0.0 - 1.0)。

---

## 9. 实战案例：多媒体与阅读 (Multimedia & Reading)

本节展示如何构建包含**视频播放**、**Markdown 渲染**和**小说阅读器**的富媒体扩展。

### 7.1 视频播放器 (Video Player)
在 YAML 中直接定义视频组件，支持网络流媒体播放。

```yaml
type: column
children:
  - type: text
    props:
      text: "扩展视频演示"
      style: "titleLarge"
      padding: 16
  
  - type: video
    props:
      url: "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4"
      autoPlay: false
      looping: true
      aspectRatio: 1.77
```

### 7.2 Markdown 阅读器
适合展示文档、更新日志或富文本内容。

```yaml
type: markdown
props:
  data: |
    # Hello Markdown
    
    This is a **bold** text and *italic* text.
    
    - List item 1
    - List item 2
    
    [Link to Google](https://google.com)
  selectable: true
```

### 7.3 小说阅读器 (Novel Reader)
专为长文本优化，提供舒适的阅读体验。

```yaml
type: novel
props:
  text: "这里是小说正文内容..."
  fontSize: 18
  lineHeight: 1.8
  backgroundColor: 0xFFF5F5F5 # 浅灰背景
  padding: [16, 16, 16, 16]
```

### 7.4 动态组合示例 (JS + YAML)
结合 JS 逻辑，可以动态切换显示内容。

**view.yaml**:
```yaml
type: column
children:
  # 顶部切换按钮栏
  - type: row
    props: { mainAxisAlignment: spaceEvenly, padding: 8 }
    children:
      - type: button
        props: { label: "视频模式", onTap: "showVideo" }
      - type: button
        props: { label: "阅读模式", onTap: "showReader" }

  # 动态内容区域
  - type: container
    children: $contentArea
```

**main.js**:
```javascript
const state = _state;

// 初始化默认显示视频
if (!state.contentArea) {
  showVideo();
}

function showVideo() {
  state.contentArea = [{
    type: 'video',
    props: {
      url: 'https://example.com/video.mp4',
      autoPlay: true
    }
  }];
}

function showReader() {
  state.contentArea = [{
    type: 'novel',
    props: {
      text: '长篇小说内容...',
      fontSize: 20
    }
  }];
}
```

### 7.5 国际化支持 (Internationalization)
扩展可以通过 `state.locale` 获取当前应用的语言代码（如 'en', 'zh'），并在 JS 中动态返回不同的文本内容。

**main.js**:
```javascript
const state = _state;
const locale = state.locale || 'en'; // 默认为英文

const strings = {
    en: {
        hello: 'Hello World',
        btn: 'Click Me'
    },
    zh: {
        hello: '你好，世界',
        btn: '点我'
    }
};

// 获取当前语言的字符串资源
const t = locale.startsWith('zh') ? strings.zh : strings.en;

// 在构建 UI 时使用
function buildUI() {
    return {
        type: 'column',
        children: [
            {
                type: 'text',
                props: { text: t.hello }
            },
            {
                type: 'button',
                props: { label: t.btn, onTap: 'handleClick' }
            }
        ]
    };
}
```
