import React, { useState, useEffect } from 'react';
import { useEvents } from '../../context/EventsContext';
import { useWindow } from '../../context/WindowContext';
import { useToast } from '../../context/ToastContext';
import { Event } from '../../types';
import TagInput from '../../components/TagInput'; 
import { LoadingSpinnerIcon } from '../../components/ui/icons';
import { resizeImage } from '../../services/ImageService';
import Button from '../../components/ui/Button';

interface EditEventModuleProps {
  eventId?: string; // If present, edit mode. If absent, add mode.
  closeWindow: () => void;
}

export const EditEventModule: React.FC<EditEventModuleProps> = ({ eventId, closeWindow }) => {
  const { events, addEvent, updateEvent, tags: allTags, getOriginalImage } = useEvents();
  const { showToast } = useToast();
  
  const isEditMode = !!eventId;
  const existingEvent = isEditMode ? events.find(e => e.id === eventId) : null;

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [tags, setTags] = useState<string[]>([]);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [originalImageFile, setOriginalImageFile] = useState<File | null>(null);
  const [isProcessingImage, setIsProcessingImage] = useState(false);
  const [wasImageRemoved, setWasImageRemoved] = useState(false);

  // Load event data if in edit mode
  useEffect(() => {
    if (existingEvent) {
      setTitle(existingEvent.title);
      setDescription(existingEvent.description);
      setTags(existingEvent.tags || []);
      setImagePreview(existingEvent.imageUrl || null);
    }
  }, [existingEvent]);

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
        showToast('图片处理失败', 'error');
        setOriginalImageFile(null);
      } finally {
        setIsProcessingImage(false);
      }
    }
  };

  const handleRemoveImage = () => {
    setImagePreview(null);
    setOriginalImageFile(null);
    setWasImageRemoved(true);
  };

  const handleSubmit = () => {
    if (!title.trim()) {
        showToast('标题不能为空', 'error');
        return;
    }

    if (isEditMode && existingEvent) {
        const imageUpdateSignal = wasImageRemoved ? 'remove' : originalImageFile || undefined;
        updateEvent({
            ...existingEvent,
            title,
            description,
            imageUrl: imagePreview || undefined,
            tags,
        }, imageUpdateSignal);
        showToast('档案已更新', 'success');
    } else {
        const newEvent: Event = {
            id: `event-${Date.now()}`,
            title,
            description,
            createdAt: new Date(),
            steps: [],
            imageUrl: imagePreview || undefined,
            tags,
            hasOriginalImage: !!originalImageFile
        };
        addEvent(newEvent, originalImageFile || undefined);
        showToast('新编年史已开启', 'success');
    }
    closeWindow();
  };

  const inputClass = "w-full px-4 py-3 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm border border-slate-300 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-brand-500/20 outline-none transition-all shadow-sm focus:bg-white dark:focus:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-400";

  if (isEditMode && !existingEvent) {
      return <div className="p-4 text-center">档案未找到</div>;
  }

  return (
    <div className="space-y-6">
      <div>
        <label htmlFor="eventTitle" className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2 pl-1">
          事件标题 <span className="text-red-500">*</span>
        </label>
        <input
          type="text"
          id="eventTitle"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="例如：重铸星辰神殿 / 追番：进击的巨人"
          className={inputClass}
          autoFocus
        />
      </div>
      <div>
        <label htmlFor="eventDescription" className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2 pl-1">
          概要
        </label>
        <textarea
          id="eventDescription"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={4}
          placeholder="记载这次冒险的背景、目标或你的誓言..."
          className={`${inputClass} resize-none`}
        />
      </div>
      <div>
        <label className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2 pl-1">
          印记 (标签)
        </label>
        <TagInput
          availableTags={allTags}
          selectedTags={tags}
          onChange={setTags}
        />
      </div>
      <div>
        <label className="block text-sm font-bold text-slate-700 dark:text-slate-300 mb-2 pl-1">
          封面映象
        </label>
        <input
          id="image-upload"
          type="file"
          className="sr-only"
          accept="image/*"
          onChange={(e) => handleImageSelected(e.target.files ? e.target.files[0] : null)}
          disabled={isProcessingImage}
        />
        <label
          htmlFor="image-upload"
          className={`relative ${isProcessingImage ? 'cursor-not-allowed' : 'cursor-pointer'} bg-slate-50/50 dark:bg-slate-800/50 rounded-2xl border-2 border-dashed border-slate-300 dark:border-slate-600 flex justify-center items-center w-full h-48 text-center hover:border-brand-400 dark:hover:border-brand-500 hover:bg-brand-50/30 dark:hover:bg-brand-900/10 transition-all duration-300 group overflow-hidden`}
        >
          {isProcessingImage ? (
              <div className="flex flex-col items-center gap-2 text-slate-500 dark:text-slate-400">
                  <LoadingSpinnerIcon className="w-8 h-8 text-brand-500" />
                  <span className="font-medium animate-pulse">正在精炼影像...</span>
              </div>
          ) : imagePreview ? (
            <div className="relative w-full h-full group-hover:opacity-90 transition-opacity">
                <img src={imagePreview} alt="预览" className="w-full h-full object-cover" />
                <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity backdrop-blur-sm">
                    <span className="text-white font-semibold">点击更换</span>
                </div>
            </div>
          ) : (
             <div className="text-slate-500 dark:text-slate-400 px-6 group-hover:text-brand-600 dark:group-hover:text-brand-400 transition-colors">
              <div className="bg-white dark:bg-slate-700 p-3 rounded-full shadow-sm inline-block mb-3 group-hover:scale-110 transition-transform">
                <svg className="h-8 w-8" stroke="currentColor" fill="none" viewBox="0 0 48 48" aria-hidden="true">
                    <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>
              <p className="font-medium">点击选择图片</p>
              <p className="text-xs mt-1 opacity-70">支持 JPG, PNG, WEBP</p>
            </div>
          )}
        </label>
        {imagePreview && (
            <div className="flex justify-end mt-2">
                <button type="button" onClick={handleRemoveImage} className="text-red-500 hover:text-red-600 text-sm font-medium px-3 py-1 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors">
                    移除当前图片
                </button>
            </div>
        )}
      </div>
      <div className="flex justify-end gap-3 pt-4 border-t border-slate-200 dark:border-slate-700">
        <Button variant="secondary" onClick={closeWindow}>取消</Button>
        <Button onClick={handleSubmit} disabled={isProcessingImage}>
            {isEditMode ? '保存更改' : '开启新篇章'}
        </Button>
      </div>
    </div>
  );
};