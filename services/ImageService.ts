/**
 * 在客户端调整图片大小以进行优化。
 * @param file 要调整大小的图片文件。
 * @param options 包含 maxWidth、maxHeight 和 quality 的配置对象。
 * @returns 返回一个解析为优化后图片的 Base64 数据 URL 的 Promise。
 */
export const resizeImage = (file: File, options: { maxWidth: number; maxHeight: number; quality: number }): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target?.result as string;
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const { maxWidth, maxHeight, quality } = options;
        let { width, height } = img;

        if (width > height) {
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          }
        } else {
          if (height > maxHeight) {
            width = Math.round((width * maxHeight) / height);
            height = maxHeight;
          }
        }

        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          return reject(new Error('无法获取 canvas 上下文'));
        }
        ctx.drawImage(img, 0, 0, width, height);
        
        // 对于 PNG 等可能没有背景的格式，我们添加一个白色背景。
        // 这可以防止在转换为 JPEG 时出现黑色背景。
        if (file.type !== 'image/jpeg') {
            const compositeCanvas = document.createElement('canvas');
            compositeCanvas.width = width;
            compositeCanvas.height = height;
            const compositeCtx = compositeCanvas.getContext('2d')!;
            compositeCtx.fillStyle = '#FFFFFF'; // 白色背景
            compositeCtx.fillRect(0, 0, width, height);
            compositeCtx.drawImage(canvas, 0, 0);
            resolve(compositeCanvas.toDataURL('image/jpeg', quality));
        } else {
            resolve(canvas.toDataURL('image/jpeg', quality));
        }
      };
      img.onerror = (error) => reject(error);
    };
    reader.onerror = (error) => reject(error);
  });
};