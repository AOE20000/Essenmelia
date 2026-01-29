import React from 'react';
import { Event, DEFAULT_ANIMATED_PLACEHOLDER } from '../types';
import { CheckIcon } from './icons';
import AnimatedPlaceholder from './AnimatedPlaceholder';

interface EventCardProps {
  event: Event;
  onClick: (event: Event) => void;
  onLongPress: (event: Event) => void;
  onOpenContextMenu: (position: { x: number; y: number }, event: Event) => void;
  collapseCardImages?: boolean;
  isSelected: boolean;
  isSelectionMode: boolean;
}

const ProgressBar: React.FC<{ progress: number }> = ({ progress }) => {
  const isCompleted = progress === 100;
  return (
    <div className="w-full bg-slate-100 dark:bg-slate-700/50 rounded-full h-1.5 overflow-hidden group-hover:h-2 transition-all duration-300">
      <div
        className={`h-full rounded-full transition-all duration-700 ease-out relative ${isCompleted ? 'bg-gradient-to-r from-emerald-400 to-emerald-500 shadow-glow-sm' : 'bg-gradient-to-r from-brand-400 to-brand-600'}`}
        style={{ width: `${progress}%` }}
      />
    </div>
  );
};


const EventCard: React.FC<EventCardProps> = ({ event, onClick, onLongPress, onOpenContextMenu, collapseCardImages, isSelected, isSelectionMode }) => {
  const completedSteps = event.steps.filter(step => step.completed).length;
  const totalSteps = event.steps.length;
  const progress = totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0;
  
  // 使用原生 onContextMenu (移动端长按/桌面端右键) 来触发选择模式
  // 这避免了使用 JS 模拟长按导致的滚动性能问题
  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault(); // 阻止浏览器默认菜单
    e.stopPropagation();
    
    // 如果已经在选择模式，右键/长按可以触发应用内的上下文菜单（如果需要的话）
    // 或者统一逻辑：长按总是尝试选中/进入选择模式
    if (isSelectionMode) {
        // 可选：在选择模式下长按也可以打开更多菜单，或者什么都不做
        // 这里我们选择让它触发 onLongPress，通常意味着“选中”
        onLongPress(event);
    } else {
        // 进入选择模式
        onLongPress(event);
    }
  };

  const handleNativeClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    onClick(event);
  };

  return (
    <div
      onClick={handleNativeClick}
      onContextMenu={handleContextMenu}
      className={`group relative glass-card rounded-3xl cursor-pointer transition-all duration-300 overflow-hidden flex flex-col select-none border border-white/40 dark:border-white/5
      ${isSelectionMode 
        ? 'active:scale-95' 
        : 'hover:shadow-glow-sm hover:-translate-y-1 hover:border-brand-300/50 dark:hover:border-brand-700/50 active:scale-[0.98]'
      }
      ${isSelected ? 'ring-2 ring-brand-500 shadow-glow scale-95' : 'shadow-sm'}
      `}
    >
      {isSelected && (
        <div className="absolute inset-0 bg-brand-900/20 dark:bg-brand-500/20 backdrop-blur-[2px] flex items-center justify-center z-20 animate-backdrop-enter pointer-events-none">
            <div className="w-12 h-12 rounded-full bg-brand-500 text-white flex items-center justify-center animate-dialog-enter shadow-lg">
                <CheckIcon className="w-7 h-7" />
            </div>
        </div>
      )}
      {!collapseCardImages && (
        <div className="relative w-full h-40 overflow-hidden bg-slate-100 dark:bg-slate-800 pointer-events-none">
            {event.imageUrl === DEFAULT_ANIMATED_PLACEHOLDER ? (
            <AnimatedPlaceholder className="w-full h-full" />
            ) : event.imageUrl ? (
            <img src={event.imageUrl} alt={event.title} className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105" />
            ) : null}
            
            {/* Gradient overlay for text readability if image exists, or just style */}
            <div className="absolute inset-0 bg-gradient-to-t from-white/90 via-transparent to-transparent dark:from-slate-900/90" />
        </div>
      )}
      
      <div className={`p-5 flex flex-col flex-grow relative ${!collapseCardImages ? '-mt-12' : ''}`}>
        <div className="mb-3">
            <h3 className="text-xl font-bold text-slate-900 dark:text-slate-100 leading-tight mb-1 line-clamp-2 group-hover:text-brand-600 dark:group-hover:text-brand-400 transition-colors duration-300">
                {event.title}
            </h3>
            {event.tags && event.tags.length > 0 && (
                <div className="flex flex-wrap gap-1.5 mt-2 mb-2">
                    {event.tags.slice(0, 3).map(tag => (
                        <span key={tag} className="text-[10px] uppercase tracking-wider font-bold px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400 border border-slate-200 dark:border-slate-600">
                            {tag}
                        </span>
                    ))}
                    {event.tags.length > 3 && <span className="text-[10px] text-slate-400 px-1">+{event.tags.length - 3}</span>}
                </div>
            )}
            <p className="text-slate-600 dark:text-slate-400 text-sm line-clamp-2 leading-relaxed">
                {event.description || "没有描述..."}
            </p>
        </div>
        
        <div className="mt-auto pt-2">
          <div className="flex justify-between items-end mb-2">
            <span className="text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider">进度</span>
            <div className="text-right">
                <span className={`text-lg font-bold ${progress === 100 ? 'text-emerald-500' : 'text-brand-600 dark:text-brand-400'}`}>
                    {Math.round(progress)}%
                </span>
                <span className="text-xs text-slate-400 ml-1">
                    ({completedSteps}/{totalSteps})
                </span>
            </div>
          </div>
          <ProgressBar progress={progress} />
        </div>
      </div>
    </div>
  );
};

export default EventCard;