import React from 'react';
import { Event } from '../types';
import useLongPress from '../hooks/useLongPress';
import { CheckIcon } from './icons';
import AnimatedPlaceholder from './AnimatedPlaceholder';
import { DEFAULT_ANIMATED_PLACEHOLDER } from '../App';

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
  return (
    <div className="w-full bg-slate-200 dark:bg-slate-700 rounded-full h-2.5">
      <div
        className="bg-slate-800 dark:bg-slate-300 h-2.5 rounded-full transition-all duration-500 ease-out"
        style={{ width: `${progress}%` }}
      ></div>
    </div>
  );
};


const EventCard: React.FC<EventCardProps> = ({ event, onClick, onLongPress, onOpenContextMenu, collapseCardImages, isSelected, isSelectionMode }) => {
  const completedSteps = event.steps.filter(step => step.completed).length;
  const totalSteps = event.steps.length;
  const progress = totalSteps > 0 ? (completedSteps / totalSteps) * 100 : 0;
  
  const handleContextMenu = (e: React.MouseEvent) => {
    if (isSelectionMode) return;
    e.preventDefault();
    onOpenContextMenu({ x: e.clientX, y: e.clientY }, event);
  };

  const handleLongPressCallback = React.useCallback((e: React.MouseEvent | React.TouchEvent) => {
    if (isSelectionMode) return;
    onLongPress(event);
  }, [onLongPress, event, isSelectionMode]);

  const handleClickCallback = React.useCallback((e: React.MouseEvent | React.TouchEvent) => {
    // useLongPress 钩子在 mouseup/touchend 事件上为“单击”手势调用此回调。
    // App 的状态逻辑在此处触发。
    onClick(event);
  }, [onClick, event]);

  const longPressEvents = useLongPress(
    handleLongPressCallback,
    handleClickCallback,
    { delay: 400 }
  );
  
  const handleNativeClick = (e: React.MouseEvent) => {
    // 此处理器捕获在 mouseup/touchend 之后触发的原生 'click' 事件。
    // 我们阻止其冒泡，以防止它到达 <aside> 背景，
    // 该背景有自己的 onClick 来清除选择。所有在卡片上的点击
    // 都应该是自包含的，不应被解释为背景点击。
    e.stopPropagation();
  };

  return (
    <div
      {...longPressEvents}
      onClick={handleNativeClick}
      onContextMenu={handleContextMenu}
      className={`relative bg-white dark:bg-slate-800 rounded-2xl shadow-md cursor-pointer transition-all duration-300 overflow-hidden flex flex-col select-none 
      ${isSelectionMode ? 'active:scale-100 hover:-translate-y-0 hover:shadow-md' : 'hover:shadow-xl hover:-translate-y-1 active:scale-[0.98] active:shadow-lg'}`}
    >
      {isSelected && (
        <div className="absolute inset-0 bg-slate-900/40 dark:bg-slate-900/60 flex items-center justify-center z-10 animate-backdrop-enter pointer-events-none">
            <div className="w-10 h-10 rounded-full bg-white/90 dark:bg-slate-800/90 flex items-center justify-center animate-dialog-enter">
                <CheckIcon className="w-6 h-6 text-slate-800 dark:text-slate-200" />
            </div>
        </div>
      )}
      {!collapseCardImages && (
        event.imageUrl === DEFAULT_ANIMATED_PLACEHOLDER ? (
          <AnimatedPlaceholder className="w-full h-40 pointer-events-none" />
        ) : event.imageUrl ? (
          <div className="w-full h-40 bg-slate-200 dark:bg-slate-700 pointer-events-none">
            <img src={event.imageUrl} alt={event.title} className="w-full h-full object-cover" />
          </div>
        ) : null
      )}
      <div className="p-6 flex flex-col flex-grow">
        <h3 className="text-xl font-bold text-slate-800 dark:text-slate-100 mb-2 truncate pointer-events-none">{event.title}</h3>
        <p className="text-slate-600 dark:text-slate-400 text-sm mb-4 line-clamp-2 flex-grow pointer-events-none">{event.description}</p>
        
        <div className="mt-auto pointer-events-none">
          <div className="flex justify-between items-center mb-2 text-sm text-slate-500 dark:text-slate-400">
            <span>进度</span>
            <span>{completedSteps} / {totalSteps}</span>
          </div>
          <ProgressBar progress={progress} />
        </div>
      </div>
    </div>
  );
};

export default EventCard;