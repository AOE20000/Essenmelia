


import React, { useRef, useState } from 'react';
import Modal from './Modal';
import { CheckIcon, ExclamationTriangleIcon, PlusIcon, ArrowUpTrayIcon, SaveIcon, TrashIcon } from './icons';
import ContextMenu, { ContextMenuAction } from './ContextMenu';
import useLongPress from '../hooks/useLongPress';

export const DEFAULT_DB_NAME_EXPORT = 'essenmelia-db-default';
export const DEMO_DB_NAME_EXPORT = 'essenmelia-db-demo';
export const TEMP_STORAGE_DB_NAME_EXPORT = 'essenmelia-db-temp-storage';
const DB_PREFIX = 'essenmelia-db';

interface DbItemProps {
  db: { id: string; name: string; description: string; isDemo: boolean; isTemp: boolean; };
  isActive: boolean;
  onSwitch: (id: string) => void;
  onOpenContextMenu: (position: {x: number, y: number}, db: {id: string, name: string}) => void;
  userDbNames: string[];
}

const DbItem: React.FC<DbItemProps> = ({ db, isActive, onSwitch, onOpenContextMenu, userDbNames }) => {
  const isTempOrDemo = db.isTemp || db.isDemo;
  const isDeletable = !isTempOrDemo;

  const handleLongPress = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isDeletable) return;
    let position;
    if ('touches' in e) {
        position = { x: e.touches[0].clientX, y: e.touches[0].clientY };
    } else {
        position = { x: e.clientX, y: e.clientY };
    }
    onOpenContextMenu(position, db);
  };

  // Fix: The onClick callback for useLongPress expects an event argument.
  const handleClick = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isActive) onSwitch(db.id);
  };
  
  const longPressEvents = useLongPress(handleLongPress, handleClick, { delay: 500 });
  
  const handleContextMenu = (e: React.MouseEvent) => {
    if (!isDeletable) return;
    e.preventDefault();
    onOpenContextMenu({ x: e.clientX, y: e.clientY }, db);
  };

  const baseClasses = "w-full p-4 rounded-lg text-left transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-slate-500 dark:focus-visible:ring-offset-slate-800 flex items-center justify-between";
  let stateClasses = '';

  if (isActive) {
    stateClasses = 'ring-2 shadow-md ';
    if (isTempOrDemo) {
      stateClasses += 'ring-yellow-500 bg-yellow-50 dark:bg-yellow-900/30';
    } else {
      stateClasses += 'ring-green-500 bg-green-50 dark:bg-green-900/30';
    }
  } else {
    stateClasses = 'bg-slate-100 dark:bg-slate-900/50 hover:bg-slate-200 dark:hover:bg-slate-700/50 active:scale-[0.98]';
  }

  return (
    <div 
      {...longPressEvents}
      onContextMenu={handleContextMenu}
      className={`${baseClasses} ${stateClasses} ${isActive ? '' : 'cursor-pointer'}`}
    >
        <div className="flex-grow min-w-0">
            <p className="font-semibold truncate text-slate-800 dark:text-slate-100">{db.name}</p>
            <p className="text-sm text-slate-600 dark:text-slate-400">{db.description}</p>
        </div>
        {isActive && (
            <div className={`flex items-center gap-2 font-semibold text-sm flex-shrink-0 ml-4 ${
              isTempOrDemo ? 'text-yellow-700 dark:text-yellow-200' : 'text-green-600 dark:text-green-400'
            }`}>
                <CheckIcon className="w-5 h-5" />
                <span>当前</span>
            </div>
        )}
    </div>
  );
}


interface DatabaseManagerModalProps {
  isOpen: boolean;
  onClose: () => void;
  activeDbName: string;
  userDbNames: string[];
  onSwitchDb: (dbName: string) => void;
  onOpenCreateDb: () => void;
  onDeleteDbRequest: (dbName: string) => void;
  onFormatAppRequest: () => void;
  onExport: () => void;
  onImport: (file: File) => void;
  dbError: Error | null;
}

const DatabaseManagerModal: React.FC<DatabaseManagerModalProps> = ({ 
    isOpen, onClose, activeDbName, userDbNames, onSwitchDb, 
    onOpenCreateDb, onDeleteDbRequest, onFormatAppRequest, onExport, onImport,
    dbError
}) => {
  const importInputRef = useRef<HTMLInputElement>(null);
  const isTempStorageMode = activeDbName === TEMP_STORAGE_DB_NAME_EXPORT;
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; db: { id: string; name: string } } | null>(null);

  const getDisplayName = (fullName: string) => {
    if (fullName === DEFAULT_DB_NAME_EXPORT) return '我的数据库';
    return fullName.replace(`${DB_PREFIX}-`, '');
  };

  // A "passive" temporary mode is entered when there's a DB error or the last DB was deleted.
  // This is different from the user actively selecting "Temporary Storage".
  // The presence of a `dbError` is the key indicator for this state.
  const isPassiveTempMode = dbError !== null;

  const allDatabases = [
     {
      id: TEMP_STORAGE_DB_NAME_EXPORT,
      name: '临时存储',
      description: isPassiveTempMode
        ? '您的更改是临时的。切换到常规数据库以保存它们。'
        : '这是一个临时会话。切换到常规数据库将丢弃当前更改。',
      isDemo: false,
      isTemp: true,
    },
    ...userDbNames
      .filter(name => name !== DEMO_DB_NAME_EXPORT)
      .map(name => ({
        id: name,
        name: getDisplayName(name),
        description: name === DEFAULT_DB_NAME_EXPORT ? '您的主要个人数据。' : '用户创建的数据库。',
        isDemo: false,
        isTemp: false,
    })),
    { 
      id: DEMO_DB_NAME_EXPORT, 
      name: '演示数据库', 
      description: '一组用于探索的示例数据（更改不会被保存）。',
      isDemo: true,
      isTemp: false,
    },
  ];

  const handleOpenContextMenu = (position: { x: number; y: number }, db: { id: string; name: string }) => {
    setContextMenu({ ...position, db });
  };

  const handleCloseContextMenu = () => {
    setContextMenu(null);
  };

  const contextMenuActions: ContextMenuAction[] = contextMenu ? [
    {
      label: `删除 "${contextMenu.db.name}"`,
      icon: <TrashIcon className="w-5 h-5" />,
      isDestructive: true,
      onClick: () => onDeleteDbRequest(contextMenu.db.id),
    }
  ] : [];

  const handleImportClick = () => {
    importInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      onImport(file);
    }
    if(event.target) {
        event.target.value = "";
    }
  };

  return (
    <>
    <Modal isOpen={isOpen} onClose={onClose} title="管理数据库" variant="sheet">
      <div className="space-y-6">
        {dbError && (
            <div className="p-4 rounded-lg bg-red-100 dark:bg-red-900/40 border border-red-300 dark:border-red-600 flex items-start gap-3">
                <ExclamationTriangleIcon className="w-6 h-6 text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5" />
                <div>
                    <h4 className="font-semibold text-red-800 dark:text-red-200">数据库连接错误</h4>
                    <p className="text-sm text-red-700 dark:text-red-300 mt-1">
                        无法连接到数据库。您的更改是临时的。请选择另一个数据库以保存您的进度。
                    </p>
                </div>
            </div>
        )}
        <div>
          <h3 className="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-2">切换或创建</h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">切换数据库将刷新应用内容。您在其他数据库中的数据将保持不变。</p>
          <div className="space-y-3">
            {allDatabases.map(db => (
                <DbItem
                    key={db.id}
                    db={db}
                    isActive={activeDbName === db.id}
                    onSwitch={onSwitchDb}
                    onOpenContextMenu={handleOpenContextMenu}
                    userDbNames={userDbNames}
                />
            ))}
            <button onClick={onOpenCreateDb} className="w-full mt-3 px-4 py-3 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-base font-medium flex items-center justify-center gap-2">
                <PlusIcon className="w-5 h-5" />
                新建数据库
            </button>
          </div>
        </div>

        <div className="pt-6 border-t border-slate-200 dark:border-slate-700">
             <h3 className="text-lg font-semibold text-slate-800 dark:text-slate-100 mb-4">当前存储操作</h3>
             <div className="space-y-4">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                    <div>
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">导出数据</p>
                        <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">将<span className="font-bold">当前</span>存储中的所有数据保存到 JSON 文件中。</p>
                    </div>
                    <button onClick={onExport} className="w-full sm:w-auto flex-shrink-0 px-4 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-sm font-medium flex items-center justify-center gap-2">
                        <ArrowUpTrayIcon className="w-5 h-5" />
                        导出
                    </button>
                </div>
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
                     <div>
                        <p className="text-sm font-medium text-slate-700 dark:text-slate-300">导入数据</p>
                        <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">从 JSON 文件加载数据。 <span className="font-bold">数据将被添加到当前存储中，而不会覆盖现有内容。</span></p>
                    </div>
                    <input type="file" ref={importInputRef} onChange={handleFileChange} accept=".json" className="hidden" />
                    <button onClick={handleImportClick} className="w-full sm:w-auto flex-shrink-0 px-4 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-sm font-medium flex items-center justify-center gap-2">
                        <SaveIcon className="w-5 h-5" />
                        导入
                    </button>
                </div>
             </div>
        </div>

        <div className="pt-6 border-t border-slate-200 dark:border-slate-700">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2">
            <div>
              <p className="text-sm font-medium text-red-600 dark:text-red-400">{isTempStorageMode ? '重置会话' : '格式化 埃森梅莉亚 (Essenmelia)'}</p>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">{isTempStorageMode ? '将当前会话恢复到初始状态。' : '永久删除所有数据库并将应用程序恢复到初始状态。'}</p>
            </div>
            <button onClick={onFormatAppRequest} className="w-full sm:w-auto flex-shrink-0 px-4 py-2.5 rounded-lg text-red-600 dark:text-red-400 bg-red-100 dark:bg-red-900/40 hover:bg-red-200 dark:hover:bg-red-900/60 transition-all active:scale-95 text-sm font-medium flex items-center justify-center gap-2">
              <ExclamationTriangleIcon className="w-5 h-5" />
              {isTempStorageMode ? '重置' : '格式化'}
            </button>
          </div>
        </div>
      </div>
    </Modal>
    {contextMenu && (
        <ContextMenu
          x={contextMenu.x}
          y={contextMenu.y}
          actions={contextMenuActions}
          onClose={handleCloseContextMenu}
        />
      )}
    </>
  );
};

export default DatabaseManagerModal;