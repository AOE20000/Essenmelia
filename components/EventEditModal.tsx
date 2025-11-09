import React, { useState, useEffect } from 'react';
import { Event } from '../types';
import Modal from './Modal';
import TagInput from './TagInput';
import { LoadingSpinnerIcon } from './icons';

interface EventEditModalProps {
  event: Event | null;
  isOpen: boolean;
  onClose: () => void;
  onUpdate: (updatedEvent: Event, originalImage?: File | 'remove') => void;
  availableTags: string[];
}

/**
 * 在客户端调整图片大小以进行优化。
 * @param file 要调整大小的图片文件。
 * @param options 包含 maxWidth、maxHeight 和 quality 的配置对象。
 * @returns 返回一个解析为优化后图片的 Base64 数据 URL 的 Promise。
 */
const resizeImage = (file: File, options: { maxWidth: number; maxHeight: number; quality: number }): Promise<string> => {
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

const EventEditModal: React.FC<EventEditModalProps> = ({ event, isOpen, onClose, onUpdate, availableTags }) => {
  const [activeEvent, setActiveEvent] = useState<Event | null>(null);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [originalImageFile, setOriginalImageFile] = useState<File | null>(null);
  const [tags, setTags] = useState<string[]>([]);
  const [isProcessingImage, setIsProcessingImage] = useState(false);
  const [wasImageRemoved, setWasImageRemoved] = useState(false);

  useEffect(() => {
    if (event) {
      setActiveEvent(event);
    }
  }, [event]);

  useEffect(() => {
    if (activeEvent) {
      setTitle(activeEvent.title);
      setDescription(activeEvent.description);
      setImagePreview(activeEvent.imageUrl || null);
      setTags(activeEvent.tags || []);
      setOriginalImageFile(null);
      setWasImageRemoved(false);
    }
  }, [activeEvent]);

  const handleImageSelected = async (file: File | null) => {
    setOriginalImageFile(file);
    setWasImageRemoved(false);
    if (file && file.type.startsWith('image/')) {
      setIsProcessingImage(true);
      try {
        const resizedImage = await resizeImage(file, { maxWidth: 1920, maxHeight: 1080, quality: 0.8 });
        setImagePreview(resizedImage);
      } catch (error) {
        console.error("图片处理失败", error);
        setOriginalImageFile(null);
        // 在这里可以设置一个错误通知
      } finally {
        setIsProcessingImage(false);
      }
    } else {
        setImagePreview(null);
    }
  };

  const handleRemoveImage = () => {
    setImagePreview(null);
    setOriginalImageFile(null);
    setWasImageRemoved(true);
  };
  
  const handleSaveChanges = () => {
    if (title.trim() && activeEvent && !isProcessingImage) {
        const imageUpdateSignal = wasImageRemoved ? 'remove' : originalImageFile || undefined;
        onUpdate({
            ...activeEvent,
            title,
            description,
            imageUrl: imagePreview || undefined,
            tags,
        }, imageUpdateSignal);
        onClose();
    }
  };

  const handleExited = () => {
    setActiveEvent(null);
  };

  if (!activeEvent) {
    return null;
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} onExited={handleExited} title="编辑事件" variant="sheet">
      <div className="space-y-4">
        <div>
          <label htmlFor="editEventTitle" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            事件标题*
          </label>
          <input
            type="text"
            id="editEventTitle"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-slate-500 focus:border-slate-500"
          />
        </div>
        <div>
          <label htmlFor="editEventDescription" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            描述
          </label>
          <textarea
            id="editEventDescription"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={4}
            className="w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-slate-500 focus:border-slate-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            标签
          </label>
          <TagInput
            availableTags={availableTags}
            selectedTags={tags}
            onChange={setTags}
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            封面图片
          </label>
          <input
            id="edit-image-upload"
            type="file"
            className="sr-only"
            accept="image/*"
            onChange={(e) => handleImageSelected(e.target.files ? e.target.files[0] : null)}
            disabled={isProcessingImage}
          />
          <label
            htmlFor="edit-image-upload"
            className={`relative ${isProcessingImage ? 'cursor-not-allowed' : 'cursor-pointer'} bg-white dark:bg-slate-700 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 flex justify-center items-center w-full h-48 text-center hover:border-slate-400 dark:hover:border-slate-500 transition-colors`}
          >
            {isProcessingImage ? (
                <div className="flex flex-col items-center gap-2 text-slate-500 dark:text-slate-400">
                    <LoadingSpinnerIcon className="w-8 h-8" />
                    <span>正在处理...</span>
                </div>
            ) : imagePreview ? (
              <img src={imagePreview} alt="预览" className="w-full h-full object-contain rounded-lg p-1" />
            ) : (
               <div className="text-slate-500 dark:text-slate-400 px-6">
                <svg className="mx-auto h-12 w-12" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                  <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <p className="mt-2">点击选择文件</p>
              </div>
            )}
          </label>
          {imagePreview && (
              <div className="grid grid-cols-2 gap-2 mt-2">
                  <label htmlFor="edit-image-upload" className="w-full text-center px-4 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-sm font-medium cursor-pointer">
                      更换图片
                  </label>
                  <button type="button" onClick={handleRemoveImage} className="w-full text-center px-4 py-2.5 rounded-lg text-red-600 dark:text-red-400 bg-red-100 dark:bg-red-900/40 hover:bg-red-200 dark:hover:bg-red-900/60 transition-all active:scale-95 text-sm font-medium">
                      移除图片
                  </button>
              </div>
          )}
        </div>
        <div className="flex justify-end gap-3 pt-2">
          <button onClick={onClose} className="px-5 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-base font-medium">取消</button>
          <button onClick={handleSaveChanges} disabled={isProcessingImage} className="px-5 py-2.5 rounded-lg bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900 font-semibold hover:bg-slate-700 dark:hover:bg-slate-300 transition-all active:scale-95 text-base disabled:bg-slate-400 dark:disabled:bg-slate-700 disabled:cursor-not-allowed">保存更改</button>
        </div>
      </div>
    </Modal>
  );
};

export default EventEditModal;