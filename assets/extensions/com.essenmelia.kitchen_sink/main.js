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
    // 初始化时同步状态
    syncAll();
}

function syncAll() {
    essenmelia.updateState("counter", state.counter);
    essenmelia.updateState("user_name", state.user_name);
    essenmelia.updateState("is_lab_enabled", state.is_lab_enabled);
    essenmelia.updateState("zoom_level", state.zoom_level);
    essenmelia.updateState("app_mode", state.app_mode);
}

function incrementCounter() {
    state.counter++;
    essenmelia.updateState("counter", state.counter);
}

function decrementCounter() {
    state.counter--;
    essenmelia.updateState("counter", state.counter);
}

function resetAll() {
    state.counter = 0;
    state.user_name = "访客";
    state.is_lab_enabled = false;
    state.zoom_level = 50;
    state.app_mode = "auto";
    syncAll();
    essenmelia.showSnackBar("所有数据已清除");
}

async function showDialog() {
    const confirmed = await essenmelia.showConfirmDialog({
        title: "测试对话框",
        message: "这是一个来自扩展的确认请求，你确定要继续吗？"
    });
    if (confirmed) {
        essenmelia.showSnackBar("已确认操作");
    } else {
        essenmelia.showSnackBar("已取消操作");
    }
}
