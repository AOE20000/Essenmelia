var state = {
    logs: "暂无外部调用记录",
    logCount: 0,
    totalRequests: 0,
    successCount: 0,
    failCount: 0,
    logLevel: "basic"
};

var logList = [];

function onLoad() {
    console.log("External Call Bridge initialized");
    // 初始化状态同步
    syncState();
}

/**
 * 处理外部请求的核心入口
 * @param {Object} args - { method: string, params: object }
 */
async function handleExternalRequest(args) {
    const method = args.method;
    const params = args.params;
    const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false });
    let result;
    let success = true;
    let error = null;

    state.totalRequests++;

    try {
        // 调用原生 API
        result = await essenmelia.call(method, params);
        state.successCount++;
    } catch (e) {
        success = false;
        error = e.toString();
        state.failCount++;
    }

    // 格式化日志条目
    const logEntry = `${timestamp}  ${method.padEnd(15)} ${success ? '成功' : '失败'}`;
    
    logList.unshift(logEntry);
    if (logList.length > 20) logList.pop();
    
    state.logs = logList.join("\n");
    state.logCount = logList.length;
    syncState();
    
    if (!success) throw error;
    return result;
}

function syncState() {
    essenmelia.updateState('totalRequests', state.totalRequests);
    essenmelia.updateState('successCount', state.successCount);
    essenmelia.updateState('failCount', state.failCount);
    essenmelia.updateState('logs', state.logs);
    essenmelia.updateState('logCount', state.logCount);
    essenmelia.updateState('logLevel', state.logLevel);
}

function showStatsDetail() {
    essenmelia.showSnackBar(`成功率: ${((state.successCount / (state.totalRequests || 1)) * 100).toFixed(1)}%`);
}

function viewLogs() {
    essenmelia.showSnackBar(`当前记录了 ${state.logCount} 条活动日志`);
}

function clearLogs() {
    logList = [];
    state.logs = "日志已清除";
    state.logCount = 0;
    state.totalRequests = 0;
    state.successCount = 0;
    state.failCount = 0;
    syncState();
    essenmelia.showSnackBar("历史数据已清空");
}
