// preload.cjs
const { contextBridge, ipcRenderer } = require('electron');

/**
 * 暴露给渲染进程的 API
 * window.electronAPI
 */
contextBridge.exposeInMainWorld('electronAPI', {
  // 测试方法
  ping: () => 'pong!',

  // 向主进程发送消息
  send: (channel, data) => {
    const validChannels = ['toMain']; // 白名单
    if (validChannels.includes(channel)) {
      ipcRenderer.send(channel, data);
    }
  },

  // 从主进程接收消息
  on: (channel, callback) => {
    const validChannels = ['fromMain']; // 白名单
    if (validChannels.includes(channel)) {
      ipcRenderer.on(channel, (event, ...args) => callback(...args));
    }
  },

  // 移除监听
  removeListener: (channel, callback) => {
    const validChannels = ['fromMain'];
    if (validChannels.includes(channel)) {
      ipcRenderer.removeListener(channel, callback);
    }
  }
});
