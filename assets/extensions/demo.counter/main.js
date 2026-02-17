// demo.counter/main.js

/**
 * 扩展初始化时调用
 * 可以在这里设置初始状态
 */
function onLoad() {
    console.log("Counter Demo: Extension Loaded!");
    
    // 初始化状态，界面会自动更新
    state.count = 0;
}

/**
 * 增加计数
 * 在 view.yaml 中通过 onTap: increment 绑定
 */
function increment() {
    state.count = (state.count || 0) + 1;
    console.log("Incremented count to: " + state.count);
    
    // 如果是 10 的倍数，发送个小庆祝
    if (state.count > 0 && state.count % 10 === 0) {
        // 使用 async/await 风格调用 API
        celebrate();
    }
}

async function celebrate() {
    await essenmelia.showSnackBar("里程碑达成！你已经点击了 " + state.count + " 次！继续加油！");
}

/**
 * 减少计数
 * 在 view.yaml 中通过 onTap: decrement 绑定
 */
function decrement() {
    state.count = (state.count || 0) - 1;
    console.log("Decremented count to: " + state.count);
}

/**
 * 触发系统通知
 * 需要在 README.md 中声明 'notifications' 权限
 */
async function showNotification() {
    console.log("Sending notification request...");
    
    // 使用 showSnackBar 替代复杂的 notifications API
    await essenmelia.showSnackBar("Hello from JS! 当前计数是: " + state.count);
}

/**
 * 监听系统事件（可选）
 */
function onEvent(event) {
    console.log("Received system event: " + JSON.stringify(event));
}
