// vite.config.ts
import path from 'path';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  // 加载环境变量
  const env = loadEnv(mode, '.', '');

  return {
    // 1. 核心配置：必须设为相对路径，否则 Electron 打包后找不到资源
    base: './', 

    server: {
      port: 3000,
      host: '0.0.0.0',
    },
    
    plugins: [react()],

    define: {
      // 这里的 process.env 替换是为了在前端代码中直接使用
      'process.env.API_KEY': JSON.stringify(env.GEMINI_API_KEY),
      'process.env.GEMINI_API_KEY': JSON.stringify(env.GEMINI_API_KEY)
    },

    resolve: {
      alias: {
        // 将 @ 映射到根目录
        '@': path.resolve(__dirname, '.'),
      }
    }
  };
});