import React, { useState, useRef, useEffect } from 'react';
import { SearchIcon, XIcon, ChevronDownIcon, CheckIcon, SettingsIcon, TrashIcon, TagIcon } from './icons';

export type SortOrder = 'createdAt-desc' | 'createdAt-asc' | 'title-asc' | 'title-desc' | 'progress-desc' | 'progress-asc';

const sortOptions: { id: SortOrder; label: string }[] = [
  { id: 'createdAt-desc', label: '最新创建' },
  { id: 'createdAt-asc', label: '最早创建' },
  { id: 'title-asc', label: '标题 (A-Z)' },
  { id: 'title-desc', label: '标题 (Z-A)' },
  { id: 'progress-desc', label: '进度 (高到低)' },
  { id: 'progress-asc', label: '进度 (低到高)' },
];

interface HeaderProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  sortOrder: SortOrder;
  onSortChange: (order: SortOrder) => void;
  onOpenSettings: () => void;
  isSelectionMode: boolean;
  selectedCount: number;
  onClearSelection: () => void;
  onDeleteSelection: () => void;
  onManageSelectionTags: () => void;
}


const Header: React.FC<HeaderProps> = ({ 
  searchQuery, onSearchChange, sortOrder, onSortChange, onOpenSettings,
  isSelectionMode, selectedCount, onClearSelection, onDeleteSelection,
  onManageSelectionTags
}) => {
  const [isSortOpen, setIsSortOpen] = useState(false);
  const sortMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (sortMenuRef.current && !sortMenuRef.current.contains(event.target as Node)) {
        setIsSortOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const activeSortLabel = sortOptions.find(opt => opt.id === sortOrder)?.label || '排序方式';

  return (
    <header className="w-full">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 transition-all duration-300 py-4 sm:h-20">
          {isSelectionMode ? (
            <div className="flex items-center justify-between w-full animate-content-enter bg-brand-50/50 dark:bg-brand-900/20 p-2 rounded-xl border border-brand-200 dark:border-brand-800">
              <h2 className="text-xl font-bold text-brand-900 dark:text-brand-100 pl-2">
                已选中: {selectedCount} 个项目
              </h2>
              <div className="flex items-center gap-2">
                <div className="inline-flex rounded-lg shadow-sm" role="group">
                  <button
                    onClick={onManageSelectionTags}
                    className="text-sm font-semibold px-4 py-2 bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 transition-colors active:scale-95 flex items-center gap-2 rounded-l-lg border border-slate-300 dark:border-slate-600"
                    aria-label="管理选中项目的标签"
                  >
                    <TagIcon className="w-5 h-5" />
                    <span className="hidden sm:inline">管理标签</span>
                  </button>
                  <button
                    onClick={onDeleteSelection}
                    className="text-sm font-semibold px-4 py-2 bg-white dark:bg-slate-700 hover:bg-red-50 dark:hover:bg-red-900/30 text-red-600 dark:text-red-400 transition-colors active:scale-95 flex items-center gap-2 rounded-r-lg border border-l-0 border-slate-300 dark:border-slate-600"
                    aria-label="删除选中项目"
                  >
                    <TrashIcon className="w-5 h-5" />
                    <span className="hidden sm:inline">删除</span>
                  </button>
                </div>
                <button 
                  onClick={onClearSelection} 
                  className="text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg p-2 transition-colors"
                  aria-label="取消选择"
                >
                  <XIcon className="w-6 h-6" />
                </button>
              </div>
            </div>
          ) : (
            <>
              <h1 className="font-bold text-transparent bg-clip-text bg-gradient-to-r from-brand-600 to-purple-600 dark:from-brand-300 dark:to-purple-300 flex-shrink-0 truncate text-3xl tracking-tight">
                埃森梅莉亚 <span className="text-slate-300 dark:text-slate-700 text-lg font-light tracking-normal">Essenmelia</span>
              </h1>
              
              <div className="flex items-center gap-3 w-full sm:w-auto">
                {/* Search Input */}
                <div className="relative flex-1 sm:flex-initial sm:w-full sm:max-w-xs group">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <SearchIcon className="h-5 w-5 text-slate-400 group-focus-within:text-brand-500 transition-colors" />
                  </div>
                  <input
                    type="text"
                    placeholder="搜索事件..."
                    value={searchQuery}
                    onChange={(e) => onSearchChange(e.target.value)}
                    className="block w-full pl-10 pr-10 py-2.5 border border-transparent bg-slate-100/50 dark:bg-slate-800/50 backdrop-blur-md rounded-xl focus:bg-white dark:focus:bg-slate-800 focus:ring-2 focus:ring-brand-500/50 focus:border-brand-500 transition-all text-sm shadow-inner"
                  />
                  {searchQuery && (
                    <button
                      onClick={() => onSearchChange('')}
                      className="absolute inset-y-0 right-0 pr-3 flex items-center"
                      aria-label="清除搜索"
                    >
                      <XIcon className="h-5 w-5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200" />
                    </button>
                  )}
                </div>

                {/* Sort Dropdown */}
                <div className="relative" ref={sortMenuRef}>
                  <button
                    onClick={() => setIsSortOpen(!isSortOpen)}
                    className="flex-shrink-0 flex items-center justify-between gap-2 px-4 py-2.5 bg-slate-100/50 dark:bg-slate-800/50 backdrop-blur-md border border-transparent rounded-xl text-slate-700 dark:text-slate-200 hover:bg-white dark:hover:bg-slate-700 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500/50 text-sm whitespace-nowrap transition-all active:scale-95"
                  >
                    <span className="font-semibold hidden sm:inline">{activeSortLabel}</span>
                    <span className="font-semibold sm:hidden">排序</span>
                    <ChevronDownIcon className={`w-5 h-5 transition-transform ${isSortOpen ? 'rotate-180' : ''}`} />
                  </button>
                  {isSortOpen && (
                    <div className="absolute z-50 top-full mt-2 w-56 right-0 bg-white/90 dark:bg-slate-800/90 backdrop-blur-xl rounded-xl shadow-xl border border-white/20 dark:border-slate-700 p-2 animate-dialog-enter">
                      <ul>
                        {sortOptions.map(option => (
                          <li key={option.id}>
                            <button
                              onClick={() => {
                                onSortChange(option.id);
                                setIsSortOpen(false);
                              }}
                              className={`w-full flex items-center justify-between text-left px-3 py-2.5 rounded-lg text-sm transition-colors ${
                                sortOrder === option.id
                                  ? 'bg-brand-50 dark:bg-brand-900/30 text-brand-700 dark:text-brand-300 font-semibold'
                                  : 'text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700/50'
                              }`}
                            >
                              {option.label}
                              {sortOrder === option.id && <CheckIcon className="w-4 h-4" />}
                            </button>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
                 {/* Settings Button */}
                <button
                  onClick={onOpenSettings}
                  className="flex-shrink-0 p-2.5 bg-slate-100/50 dark:bg-slate-800/50 backdrop-blur-md border border-transparent rounded-xl text-slate-600 dark:text-slate-300 hover:bg-white dark:hover:bg-slate-700 hover:text-brand-600 dark:hover:text-brand-400 hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-brand-500/50 transition-all active:scale-95"
                  aria-label="打开设置"
                >
                  <SettingsIcon className="w-5 h-5" />
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </header>
  );
};

export default Header;