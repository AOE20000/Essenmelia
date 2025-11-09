import React, { useMemo } from 'react';
import Modal from './Modal';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
  density: number;
  onDensityChange: (density: number) => void;
  collapseCardImages: boolean;
  onCollapseCardImagesChange: (collapse: boolean) => void;
  isDeveloperMode: boolean;
  onDeveloperModeChange: (enabled: boolean) => void;
  windowWidth: number;
  onOpenDbManager: () => void;
  numColumns: number;
}

const SettingsModal: React.FC<SettingsModalProps> = ({ 
  isOpen, onClose, density, onDensityChange, collapseCardImages, onCollapseCardImagesChange, 
  isDeveloperMode, onDeveloperModeChange,
  windowWidth, onOpenDbManager, numColumns
}) => {
  const columnOptions = useMemo(() => {
    // Mappings from number of columns to a representative density value.
    // These values must correspond to the thresholds in App.tsx's gridConfig.
    const desktopDensityMap: Record<number, number> = { 1: 10, 2: 30, 3: 50, 4: 75, 5: 100 };
    const tabletDensityMap: Record<number, number> = { 1: 10, 2: 35, 3: 65, 4: 90 };
    const mobileDensityMap: Record<number, number> = { 1: 25, 2: 75 };

    if (windowWidth >= 1280) { // Desktop
        return { columns: [1, 2, 3, 4, 5], densityMap: desktopDensityMap };
    } else if (windowWidth >= 768) { // Tablet
        return { columns: [1, 2, 3, 4], densityMap: tabletDensityMap };
    } else { // Mobile
        return { columns: [1, 2], densityMap: mobileDensityMap };
    }
  }, [windowWidth]);

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="设置" variant="sheet">
      <div className="space-y-6 divide-y divide-slate-200 dark:divide-slate-700">
        <div className="pt-2">
            <h3 className="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-4">显示</h3>
            <div className="flex items-start justify-between gap-4">
                <div className="flex-1">
                <label htmlFor="collapseImages" className="block text-sm font-medium text-slate-700 dark:text-slate-300">
                    折叠首页图片
                </label>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                    隐藏事件卡片上的封面图片以获得更紧凑的视图。
                </p>
                </div>
                <button
                id="collapseImages"
                role="switch"
                aria-checked={collapseCardImages}
                onClick={() => onCollapseCardImagesChange(!collapseCardImages)}
                className={`${
                    collapseCardImages ? 'bg-slate-800 dark:bg-slate-300' : 'bg-slate-200 dark:bg-slate-600'
                } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800`}
                >
                <span
                    aria-hidden="true"
                    className={`${
                    collapseCardImages ? 'translate-x-5' : 'translate-x-0'
                    } pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                />
                </button>
            </div>
        </div>
        
        <div className="pt-6">
          <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            列数
          </label>
          <div className="flex items-center bg-slate-200 dark:bg-slate-700 p-1 rounded-lg">
            {columnOptions.columns.map(col => (
              <button
                key={col}
                onClick={() => onDensityChange(columnOptions.densityMap[col])}
                className={`w-full px-3 py-1.5 text-sm font-semibold rounded-md transition-all ${
                  numColumns === col
                    ? 'bg-white dark:bg-slate-800 shadow-sm text-slate-800 dark:text-slate-100'
                    : 'text-slate-600 dark:text-slate-300 hover:bg-white/50 dark:hover:bg-slate-800/50'
                }`}
              >
                {col}
              </button>
            ))}
          </div>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-2">
            调整主视图中事件卡片的列数。
          </p>
        </div>

        <div className="pt-6">
            <h3 className="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-4">高级</h3>
            <div className="space-y-4">
                 <div className="flex flex-col items-start gap-3">
                    <div>
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">数据库</p>
                        <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">切换、管理或重置您的应用数据库。</p>
                    </div>
                    <button onClick={onOpenDbManager} className="w-full px-4 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-sm font-medium flex items-center justify-center gap-2">
                        管理数据库
                    </button>
                </div>
                <div className="flex items-start justify-between gap-4">
                    <div className="flex-1">
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">开发者模式</p>
                        <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">启用后，在通知弹窗上显示额外调试选项。</p>
                    </div>
                    <button
                        role="switch"
                        aria-checked={isDeveloperMode}
                        onClick={() => onDeveloperModeChange(!isDeveloperMode)}
                        className={`${
                            isDeveloperMode ? 'bg-slate-800 dark:bg-slate-300' : 'bg-slate-200 dark:bg-slate-600'
                        } relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:focus:ring-offset-slate-800`}
                    >
                        <span
                            aria-hidden="true"
                            className={`${
                            isDeveloperMode ? 'translate-x-5' : 'translate-x-0'
                            } pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                        />
                    </button>
                </div>
            </div>
        </div>

        {isDeveloperMode && (
            <div className="pt-6">
                <h3 className="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-4">开发者</h3>
                <div className="space-y-4">
                    <div className="flex items-center justify-between gap-4">
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">埃森梅莉亚 (Essenmelia)</p>
                    </div>
                    <div className="flex items-center justify-between gap-4">
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">Gemini</p>
                    </div>
                </div>
            </div>
        )}
      </div>
    </Modal>
  );
};

export default SettingsModal;
