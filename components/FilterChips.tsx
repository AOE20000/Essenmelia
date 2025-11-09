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
      className={`flex-shrink-0 flex items-center justify-center gap-2 px-4 py-2.5 rounded-full text-sm font-semibold transition-all duration-200 ease-in-out focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-slate-500 dark:focus-visible:ring-offset-slate-900 active:scale-95 ${
        isActive
          ? 'bg-slate-900 text-white dark:bg-slate-200 dark:text-slate-900'
          : 'bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600'
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
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-2 overflow-x-auto no-scrollbar">
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
              <div className="h-5 w-px bg-slate-300 dark:bg-slate-600 flex-shrink-0"></div>
              
              <button
                onClick={onManageTags}
                className="flex-shrink-0 flex items-center justify-center p-2.5 rounded-full transition-all duration-200 ease-in-out bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-slate-500 dark:focus-visible:ring-offset-slate-900 active:scale-95"
                aria-label="管理标签"
              >
                <PencilIcon className="w-5 h-5" />
              </button>
              <button
                onClick={onToggleExpand}
                className="flex-shrink-0 flex items-center justify-center gap-1.5 pl-3 pr-2 py-2.5 rounded-full text-sm font-semibold transition-colors duration-200 bg-slate-200 text-slate-700 hover:bg-slate-300 dark:bg-slate-700 dark:text-slate-200 dark:hover:bg-slate-600"
                aria-expanded={isExpanded}
              >
                <span>{isExpanded ? '收起' : '筛选'}</span>
                {isExpanded ? <ChevronUpIcon className="w-5 h-5" /> : <ChevronDownIcon className="w-5 h-5" />}
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
                <div className="flex items-center gap-2 pt-2 flex-wrap">
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
                      className="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 py-2.5 rounded-full text-sm font-semibold transition-all duration-200 ease-in-out focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-slate-500 dark:focus-visible:ring-offset-slate-900 active:scale-95 bg-transparent border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"
                      aria-label="重置标签筛选"
                    >
                      <XIcon className="w-4 h-4" />
                      <span>重置</span>
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
