import React, { useMemo } from 'react';
import { useDatabase } from '../../context/DatabaseContext';
import { useWindow } from '../../context/WindowContext';
import { useWindowWidth } from '../../hooks/useWindowWidth';

export const SettingsModule: React.FC<{ closeWindow: () => void }> = () => {
  const { 
      globalSettings, 
      updateGlobalSettings,
      refreshDbList 
  } = useDatabase();
  
  const { open } = useWindow();
  const windowWidth = useWindowWidth();

  const { cardDensity, collapseCardImages, overviewBlockSize } = globalSettings;

  const columnOptions = useMemo(() => {
    const desktopDensityMap: Record<number, number> = { 1: 10, 2: 30, 3: 50, 4: 75, 5: 100 };
    const tabletDensityMap: Record<number, number> = { 1: 10, 2: 35, 3: 65, 4: 90 };
    const mobileDensityMap: Record<number, number> = { 1: 25, 2: 75 };

    let currentMap: Record<number, number>;
    let columns: number[];

    if (windowWidth >= 1280) { // Desktop
        currentMap = desktopDensityMap;
        columns = [1, 2, 3, 4, 5];
    } else if (windowWidth >= 768) { // Tablet
        currentMap = tabletDensityMap;
        columns = [1, 2, 3, 4];
    } else { // Mobile
        currentMap = mobileDensityMap;
        columns = [1, 2];
    }
    
    // Find closest column count for current density
    const currentColumns = Object.entries(currentMap).reduce((closest, [cols, dens]) => {
        return Math.abs(dens - cardDensity) < Math.abs(currentMap[closest] - cardDensity) ? parseInt(cols) : closest;
    }, columns[0]);

    return { columns, densityMap: currentMap, currentColumns };
  }, [windowWidth, cardDensity]);

  const handleOpenDbManager = async () => {
      await refreshDbList();
      open('db-manager', {});
  };

  return (
    <div className="space-y-8">
      <div>
          <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
            <span className="w-1.5 h-6 bg-brand-500 rounded-full inline-block"></span>
            显示设置
          </h3>
          <div className="glass-card p-4 rounded-2xl border border-white/40 dark:border-white/5 space-y-6">
            
            {/* Toggle Item */}
            <div className="flex items-center justify-between gap-4">
                <div className="flex-1">
                    <label className="text-base font-semibold text-slate-800 dark:text-slate-200">
                        折叠首页图片
                    </label>
                    <p className="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
                        隐藏事件卡片上的封面图片以获得更紧凑的视图。
                    </p>
                </div>
                <button
                    role="switch"
                    aria-checked={collapseCardImages}
                    onClick={() => updateGlobalSettings({ collapseCardImages: !collapseCardImages })}
                    className={`${
                        collapseCardImages ? 'bg-brand-500' : 'bg-slate-200 dark:bg-slate-700'
                    } relative inline-flex h-7 w-12 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none`}
                >
                    <span
                        aria-hidden="true"
                        className={`${
                        collapseCardImages ? 'translate-x-5' : 'translate-x-0'
                        } pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out`}
                    />
                </button>
            </div>

            {/* Segment Control */}
            <div>
                <label className="block text-base font-semibold text-slate-800 dark:text-slate-200 mb-3">
                卡片密度 (每行)
                </label>
                <div className="flex items-center bg-slate-100 dark:bg-slate-900/50 p-1.5 rounded-xl border border-slate-200 dark:border-slate-700/50">
                {columnOptions.columns.map(col => (
                    <button
                    key={col}
                    onClick={() => updateGlobalSettings({ cardDensity: columnOptions.densityMap[col] })}
                    className={`flex-1 py-2 text-sm font-bold rounded-lg transition-all duration-300 ${
                        columnOptions.currentColumns === col
                        ? 'bg-white dark:bg-slate-700 shadow-sm text-brand-600 dark:text-brand-400 scale-[1.02]'
                        : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300'
                    }`}
                    >
                    {col}
                    </button>
                ))}
                </div>
            </div>
          </div>
      </div>

      <div>
          <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
            <span className="w-1.5 h-6 bg-purple-500 rounded-full inline-block"></span>
            高级
          </h3>
          <div className="glass-card p-4 rounded-2xl border border-white/40 dark:border-white/5 space-y-6">
               <div className="flex flex-col items-start gap-4">
                  <div>
                      <p className="text-base font-semibold text-slate-800 dark:text-slate-200">数据库管理</p>
                      <p className="text-sm text-slate-500 dark:text-slate-400 mt-0.5">切换、导出、导入或重置您的应用数据。</p>
                  </div>
                  <button onClick={handleOpenDbManager} className="w-full px-4 py-3 rounded-xl text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 hover:bg-white dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 transition-all active:scale-95 text-sm font-bold flex items-center justify-center gap-2 shadow-sm hover:shadow-md">
                      管理数据库
                  </button>
              </div>
          </div>
      </div>
      
      <div className="text-center pt-4 pb-2">
          <p className="text-xs font-mono text-slate-400 dark:text-slate-600">
              Version 1.0.1
          </p>
      </div>
    </div>
  );
};