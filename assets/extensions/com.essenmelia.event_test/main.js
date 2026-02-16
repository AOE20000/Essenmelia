var state = {
    eventList: "加载中...",
    count: 0
};

async function onLoad() {
    await refreshEvents();
}

async function refreshEvents() {
    state.eventList = "正在获取...";
    
    try {
        const events = await essenmelia.getEvents();
        state.count = events.length;
        if (events.length === 0) {
            state.eventList = "暂无事件";
        } else {
            // 显示最近 10 个事件
            state.eventList = events.slice(0, 10).map(e => {
                const time = e.startTime ? new Date(e.startTime).toLocaleTimeString() : "无时间";
                return `• ${e.title}`;
            }).join("\n");
        }
    } catch (e) {
        state.eventList = "加载失败: " + e;
    }
}

async function createTestEvent() {
    try {
        const now = new Date();
        const endTime = new Date(now.getTime() + 3600000);
        
        // 注意：API 目前仅支持 title, description, tags
        // 时间信息暂时放入描述中
        const eventData = {
            title: "模拟事件 " + (state.count + 1),
            description: `由事件沙盒扩展生成\n开始时间: ${now.toLocaleString()}\n结束时间: ${endTime.toLocaleString()}`,
            tags: ["test", "simulation"]
        };
        
        await essenmelia.addEvent(eventData);
        await essenmelia.showSnackBar("事件已创建");
        await refreshEvents();
    } catch (e) {
        await essenmelia.showSnackBar("创建失败: " + e);
    }
}

async function clearAllEvents() {
    const confirmed = await essenmelia.showConfirmDialog({
        title: "危险操作",
        message: "你确定要清空所有事件吗？此操作无法撤销。"
    });
    
    if (confirmed) {
        try {
            const events = await essenmelia.getEvents();
            for (const e of events) {
                // 使用通用 call 接口调用 deleteEvent
                await essenmelia.call('deleteEvent', { id: e.id });
            }
            await essenmelia.showSnackBar("所有事件已清空");
            await refreshEvents();
        } catch (e) {
            await essenmelia.showSnackBar("清理失败: " + e);
        }
    }
}
