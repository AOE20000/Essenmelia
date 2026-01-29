const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
    // 如果有图标，可以取消注释下面这行并确保路径正确
    // icon: path.join(__dirname, '../dist/vite.svg') 
  });

  // 开发环境下加载 Vite 服务，生产环境下加载打包好的文件
  // 注意：我们在 package.json 的 electron:dev 命令中使用了 wait-on 来确保端口就绪
  const isDev = !app.isPackaged;

  if (isDev) {
    win.loadURL('http://localhost:5173');
    // 开发模式下打开开发者工具
    win.webContents.openDevTools();
  } else {
    // 生产环境加载 dist/index.html
    // 使用 loadFile 加载本地文件
    win.loadFile(path.join(__dirname, '../dist/index.html'));
  }
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});