// 初始状态
var state = {
    counter: 0,
    user_name: "访客",
    is_lab_enabled: false
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
    syncAll();
    essenmelia.showSnackBar("所有数据已清除");
}

async function showDialog() {
    const confirmed = await essenmelia.showConfirmDialog({
        title: "提示",
        message: "你确定要执行此操作吗？"
    });
    if (confirmed) {
        essenmelia.showSnackBar("你点击了确定");
    } else {
        essenmelia.showSnackBar("你点击了取消");
    }
}
