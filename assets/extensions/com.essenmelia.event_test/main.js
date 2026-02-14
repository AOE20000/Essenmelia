var state = {
    eventList: "加载中..."
};

async function onLoad() {
    await refreshEvents();
}

async function refreshEvents() {
    state.eventList = "正在获取...";
    essenmelia.updateState('eventList', state.eventList);
    try {
        const events = await essenmelia.getEvents();
        if (events.length === 0) {
            state.eventList = "暂无事件";
        } else {
            state.eventList = events.slice(0, 5).map(e => "• " + e.title).join("\n");
        }
        essenmelia.updateState('eventList', state.eventList);
    } catch (e) {
        state.eventList = "加载失败: " + e;
        essenmelia.updateState('eventList', state.eventList);
    }
}

async function createTestEvent() {
    try {
        // 更新为符合新 API 的调用方式
        await essenmelia.showSnackBar("正在创建测试事件...");
        
        // 假设 addEvent 是 ExtensionApi 中的一个方法，或者通过 call 调用原生
        // 注意：目前 ExtensionApi 并没有 addEvent，可能需要通过其它方式
        // 这里暂时保持 call 逻辑，但确保 UI 刷新
        await refreshEvents();
    } catch (e) {
        essenmelia.showSnackBar("操作失败: " + e);
    }
}
