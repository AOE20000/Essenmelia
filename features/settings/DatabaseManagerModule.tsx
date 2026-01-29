import React, { useRef, useState } from 'react';
import { useDatabase } from '../../context/DatabaseContext';
import { useWindow } from '../../context/WindowContext';
import { useToast } from '../../context/ToastContext';
import { DEFAULT_DB_NAME_EXPORT, DEMO_DB_NAME_EXPORT, TEMP_STORAGE_DB_NAME_EXPORT } from '../../services/DatabaseService';
import { exportDatabase, importDatabase } from '../../services/DataService';
import { CheckIcon, ExclamationTriangleIcon, PlusIcon, ArrowUpTrayIcon, SaveIcon, TrashIcon } from '../../components/ui/icons';
import ContextMenu from '../../components/ContextMenu';

// Helper Component for List Item
const DbItem: React.FC<{
  db: { id: string; name: string; description: string; isDemo: boolean; isTemp: boolean; };
  isActive: boolean;
  onSwitch: (id: string) => void;
  onOpenContextMenu: (position: {x: number, y: number}, db: {id: string, name: string}) => void;
}> = ({ db, isActive, onSwitch, onOpenContextMenu }) => {
  const isDeletable = !db.isTemp && !db.isDemo;

  const handleClick = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isActive) onSwitch(db.id);
  };
  
  const handleContextMenu = (e: React.MouseEvent) => {
    if (!isDeletable) return;
    e.preventDefault();
    onOpenContextMenu({ x: e.clientX, y: e.clientY }, db);
  };

  const baseClasses = "w-full p-5 rounded-2xl text-left transition-all duration-300 flex items-center justify-between border relative overflow-hidden group";
  let stateClasses = '';

  if (isActive) {
    stateClasses = 'border-brand-500 bg-brand-50/50 dark:bg-brand-900/20 shadow-glow-sm';
    if (db.isTemp || db.isDemo) {
      stateClasses = 'border-yellow-500 bg-yellow-50/50 dark:bg-yellow-900/20 shadow-sm';
    }
  } else {
    stateClasses = 'border-white/60 dark:border-white/10 bg-white/60 dark:bg-slate-800/60 hover:bg-white dark:hover:bg-slate-800 hover:shadow-md hover:-translate-y-0.5 cursor-pointer backdrop-blur-sm';
  }

  return (
    <div 
      onClick={handleClick}
      onContextMenu={handleContextMenu}
      className={`${baseClasses} ${stateClasses}`}
    >
        <div className="flex-grow min-w-0 relative z-10">
            <p className="font-bold truncate text-slate-800 dark:text-slate-100 text-lg">{db.name}</p>
            <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{db.description}</p>
        </div>
        {isActive && (
            <div className={`flex items-center justify-center w-8 h-8 rounded-full shadow-sm relative z-10 ${
              (db.isTemp || db.isDemo) ? 'bg-yellow-500 text-white' : 'bg-brand-500 text-white'
            }`}>
                <CheckIcon className="w-5 h-5" />
            </div>
        )}
        {/* Shine effect on hover */}
        {!isActive && <div className="absolute inset-0 -translate-x-full group-hover:animate-[shimmer_1.5s_infinite] bg-gradient-to-r from-transparent via-white/20 to-transparent skew-x-12" />}
    </div>
  );
}

export const DatabaseManagerModule: React.FC<{ closeWindow: () => void }> = ({ closeWindow }) => {
  const { 
      activeDbName, userDbNames, dbError, 
      switchDb, deleteDb, refreshDbList, resetApp
  } = useDatabase();
  const { open } = useWindow();
  const { showToast } = useToast();
  
  const importInputRef = useRef<HTMLInputElement>(null);
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; db: { id: string; name: string } } | null>(null);

  const getDisplayName = (fullName: string) => {
    if (fullName === DEFAULT_DB_NAME_EXPORT) return '主档案馆';
    return fullName.replace('essenmelia-db-', '');
  };

  const allDatabases = [
     {
      id: TEMP_STORAGE_DB_NAME_EXPORT,
      name: '以太位面 (临时存储)',
      description: dbError
        ? '无法连接到主水晶。你的记录在此位面是易逝的。'
        : '一个临时的、不稳定的存储空间。',
      isDemo: false,
      isTemp: true,
    },
    ...userDbNames
      .filter(name => name !== DEMO_DB_NAME_EXPORT)
      .map(name => ({
        id: name,
        name: getDisplayName(name),
        description: name === DEFAULT_DB_NAME_EXPORT ? '你主要的记忆与进度档案。' : '一个独立的世界线。',
        isDemo: false,
        isTemp: false,
    })),
    { 
      id: DEMO_DB_NAME_EXPORT, 
      name: '全息演示馆', 
      description: '一组用于展示埃森梅莉亚功能的示例数据。',
      isDemo: true,
      isTemp: false,
    },
  ];

  const handleSwitch = (id: string) => {
      switchDb(id);
      closeWindow();
  };

  const handleOpenContextMenu = (position: { x: number; y: number }, db: { id: string; name: string }) => {
    setContextMenu({ ...position, db });
  };

  const handleExport = async () => {
      if (activeDbName === TEMP_STORAGE_DB_NAME_EXPORT || activeDbName === DEMO_DB_NAME_EXPORT) {
          showToast('无法从临时位面或演示馆提取物质', 'error');
          return;
      }
      try {
          await exportDatabase(activeDbName);
          showToast('档案提取成功', 'success');
      } catch (e) {
          showToast('提取失败', 'error');
      }
  };

  const handleImportClick = () => importInputRef.current?.click();
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) {
          open('import-confirm', { 
              file, 
              onConfirm: async () => {
                  try {
                      if (activeDbName === TEMP_STORAGE_DB_NAME_EXPORT || activeDbName === DEMO_DB_NAME_EXPORT) {
                          showToast('无法向临时位面或演示馆注入数据', 'error');
                          return;
                      }
                      await importDatabase(activeDbName, file);
                      await refreshDbList(); 
                      window.location.reload(); 
                  } catch (e) {
                      showToast('注入失败', 'error');
                  }
              }
          });
      }
      e.target.value = "";
  };

  return (
    <div className="space-y-8">
      {dbError && (
          <div className="p-4 rounded-xl bg-red-100 dark:bg-red-900/40 border border-red-300 dark:border-red-600 flex items-start gap-3 shadow-sm">
              <ExclamationTriangleIcon className="w-6 h-6 text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5" />
              <div>
                  <h4 className="font-bold text-red-800 dark:text-red-200">水晶共鸣断裂</h4>
                  <p className="text-sm text-red-700 dark:text-red-300 mt-1">
                      无法连接到数据库。您的更改目前仅存于以太中（临时），请尽快切换数据库以固化您的进度。
                  </p>
              </div>
          </div>
      )}
      <div>
        <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
            <span className="w-1.5 h-6 bg-brand-500 rounded-full inline-block"></span>
            位面切换
        </h3>
        <div className="space-y-4">
          {allDatabases.map(db => (
              <DbItem
                  key={db.id}
                  db={db}
                  isActive={activeDbName === db.id}
                  onSwitch={handleSwitch}
                  onOpenContextMenu={handleOpenContextMenu}
              />
          ))}
          <button onClick={() => open('create-db', {})} className="w-full mt-2 px-4 py-3.5 rounded-2xl text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 transition-all active:scale-95 text-base font-bold flex items-center justify-center gap-2 border border-slate-200 dark:border-slate-700 hover:shadow-md border-dashed">
              <PlusIcon className="w-5 h-5" />
              开辟新世界
          </button>
        </div>
      </div>

      <div className="pt-6 border-t border-slate-200 dark:border-slate-700">
           <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
                <span className="w-1.5 h-6 bg-purple-500 rounded-full inline-block"></span>
                数据铭刻
           </h3>
           <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button onClick={handleExport} className="flex-1 px-4 py-4 rounded-2xl text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 hover:border-brand-300 dark:hover:border-brand-700 transition-all active:scale-95 text-sm font-bold flex flex-col items-center justify-center gap-2 shadow-sm hover:shadow-md">
                    <div className="p-2 rounded-full bg-brand-50 dark:bg-brand-900/30 text-brand-600 dark:text-brand-400">
                        <ArrowUpTrayIcon className="w-6 h-6" />
                    </div>
                    提取备份 (Export)
                </button>
                
                <div className="relative">
                    <input type="file" ref={importInputRef} onChange={handleFileChange} accept=".json" className="hidden" />
                    <button onClick={handleImportClick} className="w-full h-full px-4 py-4 rounded-2xl text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 hover:border-brand-300 dark:hover:border-brand-700 transition-all active:scale-95 text-sm font-bold flex flex-col items-center justify-center gap-2 shadow-sm hover:shadow-md">
                        <div className="p-2 rounded-full bg-purple-50 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400">
                            <SaveIcon className="w-6 h-6" />
                        </div>
                        注入记忆 (Import)
                    </button>
                </div>
           </div>
      </div>

      <div className="pt-6 border-t border-slate-200 dark:border-slate-700">
          <div className="p-4 rounded-2xl bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="text-center sm:text-left">
                <p className="text-base font-bold text-red-700 dark:text-red-400">禁忌区域</p>
                <p className="text-xs text-red-600/70 dark:text-red-400/70 mt-1">毁灭所有世界线并回归虚无。</p>
            </div>
            <button onClick={() => open('confirm', {
                title: '重置所有数据',
                message: '此禁咒将粉碎所有本地水晶（数据库）并将埃森梅莉亚重置到初始状态。所有的记忆、史诗和旅程都将消失在虚空中，无法挽回。您确定要咏唱此咒语吗？',
                isDestructive: true,
                confirmText: '彻底湮灭',
                onConfirm: () => resetApp()
            })} className="w-full sm:w-auto px-5 py-2.5 rounded-xl text-red-600 dark:text-red-100 bg-white dark:bg-red-900/50 hover:bg-red-50 dark:hover:bg-red-800 border border-red-200 dark:border-red-800 transition-all active:scale-95 text-sm font-bold flex items-center justify-center gap-2 shadow-sm">
                <ExclamationTriangleIcon className="w-5 h-5" />
                格式化应用
            </button>
          </div>
      </div>
      
      {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          actions={[{
              label: `删除 "${contextMenu.db.name}"`,
              icon: <TrashIcon className="w-5 h-5" />,
              isDestructive: true,
              onClick: () => deleteDb(contextMenu.db.id)
          }]}
          onClose={() => setContextMenu(null)}
        />
      )}
    </div>
  );
};