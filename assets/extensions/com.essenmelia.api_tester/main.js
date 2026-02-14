// 状态变量
var state = {
    result: "等待测试..."
};

// 初始化
function onLoad() {
    console.log("API Tester loaded");
}

// 测试获取事件
async function testGetEvents() {
    state.result = "正在获取事件...";
    essenmelia.updateState('result', state.result);
    try {
        const events = await essenmelia.getEvents();
        state.result = "成功获取 " + events.length + " 个事件";
        essenmelia.updateState('result', state.result);
    } catch (e) {
        state.result = "错误: " + e;
        essenmelia.updateState('result', state.result);
    }
}

// 测试显示通知
function testShowSnackBar() {
    essenmelia.showSnackBar("这是一条来自 JS 的通知！");
}

// 测试网络请求
async function testHttpGet() {
    state.result = "正在请求...";
    essenmelia.updateState('result', state.result);
    try {
        const res = await essenmelia.httpGet("https://api.github.com/zen");
        state.result = "GitHub Zen: " + res;
        essenmelia.updateState('result', state.result);
    } catch (e) {
        state.result = "网络错误: " + e;
        essenmelia.updateState('result', state.result);
    }
}

// 事件处理
function onEvent(event) {
    console.log("Received event: " + event.name);
}
