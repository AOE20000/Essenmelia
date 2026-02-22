(async function() {
    try {
        console.log("Content Page Demo Extension Loaded");
        
        const state = _state;
        const locale = state.locale || 'en';
        const isZh = locale.startsWith('zh');

        // Localization helpers
        const strings = {
            en: {
                title: 'Multimedia Demo',
                btnVideo: 'Video Mode',
                btnReader: 'Reader Mode',
                videoTitle: 'Video Player Mode',
                videoDesc: 'This video component supports network URLs, auto-play, looping, and custom aspect ratios.',
                readerTitle: 'Reader Mode',
                novelText: 'It was a dark and stormy night; the rain fell in torrents—except at occasional intervals, when it was checked by a violent gust of wind which swept up the streets (for it is in London that our scene lies), rattling along the housetops, and fiercely agitating the scanty flame of the lamps that struggled against the darkness.',
                mdTitle: 'Markdown Supported'
            },
            zh: {
                title: '多媒体演示',
                btnVideo: '视频模式',
                btnReader: '阅读模式',
                videoTitle: '视频播放器模式',
                videoDesc: '该视频组件支持网络 URL、自动播放、循环播放和自定义宽高比。',
                readerTitle: '阅读模式',
                novelText: '那是一个月黑风高的夜晚，大雨倾盆而下——除了偶尔的间歇，那时雨势被一阵猛烈的风阻挡，风席卷过街道（因为我们的场景发生在伦敦），在屋顶上嘎嘎作响，猛烈地摇晃着那些在黑暗中挣扎的微弱灯光。',
                mdTitle: '支持 Markdown'
            }
        };

        const t = isZh ? strings.zh : strings.en;

        // 初始化状态
        state.contentArea = null;

        // 定义切换函数
        globalThis.showVideo = function() {
            console.log("Switching to Video Mode");
            state.contentArea = [{
                type: 'column',
                children: [
                    {
                        type: 'text',
                        props: { text: t.videoTitle, style: 'headlineSmall', padding: [0, 0, 0, 16] }
                    },
                    {
                        type: 'video',
                        props: {
                            url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
                            autoPlay: false,
                            looping: true,
                            aspectRatio: 1.77
                        }
                    },
                    {
                        type: 'text',
                        props: { 
                            text: t.videoDesc,
                            style: 'bodyMedium',
                            padding: [0, 16, 0, 0]
                        }
                    }
                ]
            }];
            // 触发更新
            // 注意: 在新版引擎中直接修改 state.contentArea = ... 就会触发，但在某些旧逻辑中可能需要手动 render
            essenmelia.call('render', { contentArea: state.contentArea }); 
        };

        globalThis.showReader = function() {
            console.log("Switching to Reader Mode");
            state.contentArea = [
                {
                    type: 'text',
                    props: { text: t.readerTitle, style: 'headlineSmall', padding: [0, 0, 0, 16] }
                },
                {
                    type: 'novel',
                    props: {
                        text: t.novelText,
                        fontSize: 18,
                        lineHeight: 1.8,
                        backgroundColor: '#f0f0f0',
                        padding: 16
                    }
                },
                { type: 'sized_box', props: { height: 24 } },
                {
                    type: 'markdown',
                    props: {
                        data: '### ' + t.mdTitle + '\n\n- **Bold** and *Italic*\n- [Links](https://flutter.dev)\n- Code blocks\n\n```dart\nvoid main() {\n  print("Hello World");\n}\n```',
                        selectable: true
                    }
                }
            ];
            essenmelia.call('render', { contentArea: state.contentArea }); 
        };

        // 1. 获取所有事件
        let events = await essenmelia.getEvents();
        
        if (!events) {
            console.log("getEvents returned null or undefined");
            events = [];
        }
        
        console.log("Found " + events.length + " events");
        
        if (events.length > 0) {
            const firstEvent = events[0];
            const eventId = firstEvent.id;
            const eventTitle = firstEvent.title;
            
            console.log("Registering content for event: " + eventTitle + " (" + eventId + ")");
            
            // 构建自定义内容页 UI (包含动态部分)
            const customContent = {
                type: 'column',
                props: {
                    padding: 16
                },
                children: [
                    {
                        type: 'text',
                        props: {
                            text: t.title,
                            style: 'headlineMedium',
                            bold: true,
                            padding: [0, 0, 0, 16]
                        }
                    },
                    // 切换按钮行
                    {
                        type: 'row',
                        props: {
                            mainAxisAlignment: 'spaceEvenly',
                            padding: [0, 0, 0, 24]
                        },
                        children: [
                            {
                                type: 'button',
                                props: {
                                    label: t.btnVideo,
                                    icon: 0xe639, // videocam
                                    variant: 'filled',
                                    onTap: 'showVideo'
                                }
                            },
                            {
                                type: 'button',
                                props: {
                                    label: t.btnReader,
                                    icon: 0xe0ef, // book
                                    variant: 'outlined',
                                    onTap: 'showReader'
                                }
                            }
                        ]
                    },
                    // 动态内容区域 - 绑定到 state.contentArea
                    {
                        type: 'column',
                        children: '$contentArea'
                    }
                ]
            };
            
            // 默认显示视频模式
            showVideo();

            // 调用 API 注册内容
            // 使用新版 API helper
            if (essenmelia.registerEventDetailContent) {
                await essenmelia.registerEventDetailContent(
                    eventId,
                    'com.example.content_page_demo',
                    customContent,
                    t.title
                );
            } else {
                // 兼容旧版
                 await essenmelia.call('registerEventDetailContent', {
                    eventId: eventId,
                    extensionId: 'com.example.content_page_demo',
                    title: t.title,
                    content: customContent
                });
            }
            
            await essenmelia.showSnackBar('演示扩展已加载，请点击图片进入详情页查看');
            
        } else {
            console.log("No events found to register content for.");
            await essenmelia.showSnackBar('未找到事件，无法演示内容注入');
        }
        
    } catch (e) {
        console.error("Extension Error: " + e);
        if (typeof essenmelia !== 'undefined' && essenmelia.showSnackBar) {
            await essenmelia.showSnackBar("Extension Error: " + e);
        }
    }
})();
