// 外部调用网关逻辑
console.log('Gateway: Initializing...');

// 状态：最近的请求列表
const state = {
  requests: [],
  isListening: true,
};

// 初始化状态
essenmelia.render(state);

// 监听 Deep Link 事件
essenmelia.on('system.gateway.request', async (event) => {
  console.log('Gateway: Received request', event);
  
  // 添加到请求列表
  state.requests.unshift({
    timestamp: new Date().toISOString(),
    ...event
  });
  
  // 保持列表长度不超过 50
  if (state.requests.length > 50) {
    state.requests.pop();
  }
  
  essenmelia.render(state);
  
  // 简单的路由逻辑示例
  const { path, params } = event;
  
  if (path === '/test') {
    await essenmelia.call('showSnackBar', { message: 'Test command received via Deep Link!' });
  } else if (path === '/add_task') {
      // essenmelia://add_task?title=BuyMilk
      if (params && params.title) {
          try {
              await essenmelia.call('addEvent', {
                  title: params.title,
                  description: params.description || 'Added via External Call',
                  tags: []
              });
              await essenmelia.call('showSnackBar', { message: `Task added: ${params.title}` });
          } catch (e) {
              await essenmelia.call('showSnackBar', { message: `Failed to add task: ${e}` });
          }
      }
  }
});

// 导出函数供 UI 调用
globalThis.clearLog = () => {
  state.requests = [];
  essenmelia.render(state);
};
