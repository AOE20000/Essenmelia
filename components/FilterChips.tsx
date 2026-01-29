import React from 'react';
import { CheckIcon, PencilIcon, ChevronDownIcon, ChevronUpIcon, XIcon } from './icons';

type StatusFilter = 'all' | 'in-progress' | 'completed';

interface ActiveFilters {
  status: StatusFilter;
  tags: string[];
}

interface FilterChipProps {
  label: string;
  isActive: boolean;
  onClick: () => void;
}

const Chip: React.FC<FilterChipProps> = ({ label, isActive, onClick }) => {
  return (
    <button
      onClick={onClick}
      className={`flex-shrink-0 flex items-center justify-center gap-2 px-4 py-2 rounded-full text-sm font-semibold transition-all duration-300 ease-out focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-brand-500 dark:focus-visible:ring-offset-slate-900 active:scale-95 border ${
        isActive
          ? 'bg-brand-500 text-white border-brand-500 shadow-glow-sm hover:bg-brand-600'
          : 'bg-white/50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-brand-300 dark:hover:border-brand-700 hover:bg-white dark:hover:bg-slate-800'
      }`}
    >
      {isActive && <CheckIcon className="w-4 h-4" />}
      {label}
    </button>
  );
};

interface FilterChipsProps {
  activeFilters: ActiveFilters;
  onStatusChange: (filter: StatusFilter) => void;
  onTagToggle: (tag: string) => void;
  customTags: string[];
  onManageTags: () => void;
  isExpanded: boolean;
  onToggleExpand: () => void;
  onResetTags: () => void;
}

const defaultFilters: { id: StatusFilter; label: string }[] = [
  { id: 'all', label: '全部' },
  { id: 'in-progress', label: '进行中' },
  { id: 'completed', label: '已完成' },
];

const FilterChips: React.FC<FilterChipsProps> = ({ activeFilters, onStatusChange, onTagToggle, customTags, onManageTags, isExpanded, onToggleExpand, onResetTags }) => {
  const hasTags = customTags.length > 0;

  return (
    <div className="px-4 sm:px-6 lg:px-8">
      <div className="flex flex-col">
        {/* Row 1: Status filters and controls */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 overflow-x-auto no-scrollbar py-1">
            {defaultFilters.map((filter) => (
              <Chip
                key={filter.id}
                label={filter.label}
                isActive={activeFilters.status === filter.id}
                onClick={() => onStatusChange(filter.id)}
              />
            ))}
          </div>

          {hasTags && (
            <div className="flex-shrink-0 flex items-center gap-2">
              <div className="h-6 w-px bg-slate-300 dark:bg-slate-700 flex-shrink-0 mx-1"></div>
              
              <button
                onClick={onManageTags}
                className="flex-shrink-0 flex items-center justify-center p-2 rounded-full transition-all duration-200 ease-in-out bg-white/50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400 hover:bg-white dark:hover:bg-slate-800 hover:text-brand-600 dark:hover:text-brand-400 border border-transparent hover:border-brand-200 dark:hover:border-slate-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-brand-500 dark:focus-visible:ring-offset-slate-900 active:scale-95"
                aria-label="管理标签"
              >
                <PencilIcon className="w-5 h-5" />
              </button>
              <button
                onClick={onToggleExpand}
                className="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 py-2 rounded-full text-sm font-semibold transition-colors duration-200 bg-white/50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400 hover:bg-white dark:hover:bg-slate-800 hover:text-brand-600 dark:hover:text-brand-400"
                aria-expanded={isExpanded}
              >
                <span>{isExpanded ? '收起' : '标签'}</span>
                {isExpanded ? <ChevronUpIcon className="w-4 h-4" /> : <ChevronDownIcon className="w-4 h-4" />}
              </button>
            </div>
          )}
        </div>

        {/* Row 2: Collapsible tags */}
        <div
          className={`grid transition-[grid-template-rows] duration-300 ease-in-out ${isExpanded ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]'}`}
        >
          <div className="overflow-hidden">
            {hasTags && (
              <div className="max-h-[50vh] overflow-y-auto no-scrollbar pr-2">
                <div className="flex items-center gap-2 pt-3 flex-wrap pb-2">
                  {customTags.map((tag) => (
                    <Chip
                      key={tag}
                      label={tag}
                      isActive={activeFilters.tags.includes(tag)}
                      onClick={() => onTagToggle(tag)}
                    />
                  ))}
                  {activeFilters.tags.length > 0 && (
                    <button
                      onClick={onResetTags}
                      className="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 py-2 rounded-full text-sm font-semibold transition-all duration-200 ease-in-out focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-slate-500 dark:focus-visible:ring-offset-slate-900 active:scale-95 text-slate-500 dark:text-slate-400 hover:text-red-500 dark:hover:text-red-400"
                      aria-label="重置标签筛选"
                    >
                      <XIcon className="w-4 h-4" />
                      <span>清除</span>
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default FilterChips;