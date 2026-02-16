// 初始状态
var state = {
    counter: 0,
    user_name: "访客",
    is_lab_enabled: false,
    zoom_level: 50,
    app_mode: "auto"
};

function onLoad() {
    console.log("Kitchen Sink loaded");
    // 不需要手动 syncAll，因为 state 是 Proxy
    // syncAll(); 
}

function incrementCounter() {
    state.counter++;
}

function decrementCounter() {
    state.counter--;
}

function resetAll() {
    state.counter = 0;
    state.user_name = "访客";
    state.is_lab_enabled = false;
    state.zoom_level = 50;
    state.app_mode = "auto";
    
    essenmelia.showSnackBar("所有数据已清除");
}

async function showDialog() {
    const confirmed = await essenmelia.showConfirmDialog({
        title: "测试对话框",
        message: "这是一个来自扩展的确认请求，你确定要继续吗？"
    });
    if (confirmed) {
        await essenmelia.showSnackBar("已确认操作");
    } else {
        await essenmelia.showSnackBar("已取消操作");
    }
}
