var state = {
    eventList: "加载中...",
    count: 0
};

async function onLoad() {
    await refreshEvents();
}

async function refreshEvents() {
    state.eventList = "正在获取...";
    essenmelia.updateState('eventList', state.eventList);
    try {
        const events = await essenmelia.getEvents();
        state.count = events.length;
        if (events.length === 0) {
            state.eventList = "暂无事件";
        } else {
            // 显示最近 10 个事件
            state.eventList = events.slice(0, 10).map(e => {
                const time = e.startTime ? new Date(e.startTime).toLocaleTimeString() : "无时间";
                return `• [${time}] ${e.title}`;
            }).join("\n");
        }
        essenmelia.updateState('eventList', state.eventList);
        essenmelia.updateState('count', state.count);
    } catch (e) {
        state.eventList = "加载失败: " + e;
        essenmelia.updateState('eventList', state.eventList);
    }
}

async function createTestEvent() {
    try {
        const now = new Date();
        const eventData = {
            title: "模拟事件 " + (state.count + 1),
            description: "由事件沙盒扩展生成",
            startTime: now.toISOString(),
            endTime: new Date(now.getTime() + 3600000).toISOString()
        };
        
        await essenmelia.addEvent(eventData);
        essenmelia.showSnackBar("事件已创建");
        await refreshEvents();
    } catch (e) {
        essenmelia.showSnackBar("创建失败: " + e);
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
                await essenmelia.deleteEvent(e.id);
            }
            essenmelia.showSnackBar("所有事件已清空");
            await refreshEvents();
        } catch (e) {
            essenmelia.showSnackBar("清理失败: " + e);
        }
    }
}
