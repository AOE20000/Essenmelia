// 状态变量
var state = {
    result: "等待测试..."
};

// 初始化
function onLoad() {
    console.log("API Tester loaded");
    // 不需要手动 updateState，因为 state 是 Proxy
    // 但这里为了初始化界面，保持原样或直接赋值
    // state.result = "等待测试...";
}

// 测试获取事件
async function testGetEvents() {
    state.result = "正在获取事件...";
    
    try {
        const events = await essenmelia.getEvents();
        state.result = "成功获取 " + events.length + " 个事件";
    } catch (e) {
        state.result = "错误: " + e;
    }
}

// 测试显示通知
async function testShowSnackBar() {
    await essenmelia.showSnackBar("这是一条来自 JS 的通知！");
}

// 测试网络请求
async function testHttpGet() {
    state.result = "正在请求...";
    
    try {
        // 使用通用 call 接口调用 httpGet
        // 注意：httpGet 并不是 essenmelia 的直接方法
        const res = await essenmelia.call('httpGet', { url: "https://api.github.com/zen" });
        
        // 假设返回的是响应体字符串或对象
        let content = res;
        if (typeof res === 'object') {
            content = JSON.stringify(res);
        }
        
        state.result = "GitHub Zen: " + content;
    } catch (e) {
        state.result = "网络错误: " + e;
    }
}

// 事件处理
function onEvent(event) {
    console.log("Received event: " + event.name);
}
