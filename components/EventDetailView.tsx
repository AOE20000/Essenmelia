import React, { useState, useEffect, useRef } from 'react';
import { Event, ProgressStep, DEFAULT_ANIMATED_PLACEHOLDER } from '../types';
import { CheckIcon, PencilIcon, ArrowUpTrayIcon } from './icons';
import { useEvents } from '../context/EventsContext';
import AnimatedPlaceholder from './AnimatedPlaceholder';

type OverviewBlockSize = 'sm' | 'md' | 'lg';

interface EventDetailViewProps {
  event: Event;
  onBack: () => void;
  onUpdateEvent: (updatedEvent: Event) => void;
  onEdit: (event: Event) => void;
  onEditSteps: (event: Event) => void;
  overviewBlockSize: OverviewBlockSize;
  onOverviewBlockSizeChange: (size: OverviewBlockSize) => void;
}

const sizeConfig: Record<OverviewBlockSize, { container: string; text: string; icon: string }> = {
  sm: { container: '', text: 'text-xl', icon: 'w-7 h-7' },
  md: { container: '', text: 'text-2xl', icon: 'w-8 h-8' },
  lg: { container: '', text: 'text-3xl', icon: 'w-10 h-10' },
};

const sizeOptions: { id: OverviewBlockSize; label: string }[] = [
  { id: 'sm', label: '小' },
  { id: 'md', label: '中' },
  { id: 'lg', label: '大' },
];

const TimelineItem: React.FC<{ step: ProgressStep; onToggle: () => void; isLast: boolean }> = ({ step, onToggle, isLast }) => {
  return (
    <div className="relative flex group">
      {/* Connector Line */}
      {!isLast && (
        <div className={`absolute left-[19px] top-[40px] bottom-[-20px] w-[2px] transition-colors duration-500 ${step.completed ? 'bg-gradient-to-b from-brand-500 to-brand-300 dark:from-brand-600 dark:to-brand-800' : 'bg-slate-200 dark:bg-slate-700'}`}></div>
      )}
      
      <div className="flex-shrink-0 mr-6 relative z-10">
        <button
          onClick={onToggle}
          className={`w-10 h-10 rounded-full flex items-center justify-center cursor-pointer transition-all duration-300 shadow-md active:scale-90 border-2
            ${step.completed 
                ? 'bg-brand-500 border-brand-500 text-white shadow-glow-sm scale-105' 
                : 'bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 hover:border-brand-400 dark:hover:border-brand-500'
            }`}
        >
          {step.completed && <CheckIcon className="w-5 h-5 animate-dialog-enter" />}
        </button>
      </div>
      
      <div className={`pt-1 pb-8 flex-grow transition-opacity duration-300 ${step.completed ? 'opacity-60' : 'opacity-100'}`}>
        <div 
            onClick={onToggle}
            className={`p-4 rounded-2xl border transition-all duration-200 cursor-pointer ${step.completed ? 'bg-slate-50/50 dark:bg-slate-800/30 border-transparent' : 'bg-white/80 dark:bg-slate-800/80 border-white/50 dark:border-slate-700 hover:shadow-md'}`}
        >
            <p className={`font-medium text-lg text-slate-800 dark:text-slate-100 transition-all duration-300 ${step.completed ? 'line-through decoration-slate-400' : ''}`}>{step.description}</p>
            <p className="text-xs font-mono text-slate-400 dark:text-slate-500 mt-2">{step.timestamp.toLocaleString([], { dateStyle: 'short', timeStyle: 'short' })}</p>
        </div>
      </div>
    </div>
  );
};

const EventDetailView: React.FC<EventDetailViewProps> = ({ event, onBack, onUpdateEvent, onEdit, onEditSteps, overviewBlockSize, onOverviewBlockSizeChange }) => {
  const { getOriginalImage } = useEvents();
  const [localSteps, setLocalSteps] = useState(() => [...event.steps].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime()));
  const isSwipingRef = useRef(false);
  const swipeTargetStateRef = useRef(false);
  const swipedThisActionRef = useRef(false);

  useEffect(() => {
      setLocalSteps([...event.steps].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime()));
  }, [event.steps]);

  const handlePointerMove = (e: PointerEvent) => {
      if (!isSwipingRef.current) return;
      swipedThisActionRef.current = true;

      const element = document.elementFromPoint(e.clientX, e.clientY);
      const stepBlock = element?.closest<HTMLElement>('[data-step-id]');
      
      if (stepBlock?.dataset.stepId) {
          const stepId = stepBlock.dataset.stepId;
          setLocalSteps(prev => prev.map(step => {
              if (step.id === stepId && step.completed !== swipeTargetStateRef.current) {
                  return { ...step, completed: swipeTargetStateRef.current };
              }
              return step;
          }));
      }
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLButtonElement> | PointerEvent) => {
      if (!isSwipingRef.current) return;
      isSwipingRef.current = false;

      if ('pointerId' in e) {
        (e.target as HTMLElement).releasePointerCapture(e.pointerId);
      }
      
      const finalUpdatedSteps = event.steps.map(originalStep => {
          const localVersion = localSteps.find(ls => ls.id === originalStep.id);
          return localVersion ? { ...originalStep, completed: localVersion.completed } : originalStep;
      });

      onUpdateEvent({ ...event, steps: finalUpdatedSteps });

      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp as EventListener);
      document.body.style.userSelect = '';
  };

  const handlePointerDown = (e: React.PointerEvent<HTMLButtonElement>, step: ProgressStep) => {
      // Allow swiping only if starting from the first item (visual choice) or any item? 
      // Current implementation in App allows dragging from anywhere if we pass the logic.
      // But here we might want to start swipe from the specific item clicked.
      
      e.preventDefault();
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
      
      isSwipingRef.current = true;
      swipedThisActionRef.current = false;
      const targetState = !step.completed;
      swipeTargetStateRef.current = targetState;
      
      window.addEventListener('pointermove', handlePointerMove);
      window.addEventListener('pointerup', handlePointerUp as EventListener);
      document.body.style.userSelect = 'none';
  };

  const handleOverviewBlockClick = (stepId: string) => {
      if (swipedThisActionRef.current) {
          swipedThisActionRef.current = false;
          return;
      }

      const updatedSteps = event.steps.map(step =>
          step.id === stepId ? { ...step, completed: !step.completed } : step
      );
      onUpdateEvent({ ...event, steps: updatedSteps });
  };
  
  const handleTimelineToggleStep = (stepId: string) => {
    const updatedSteps = event.steps.map(step =>
      step.id === stepId ? { ...step, completed: !step.completed } : step
    );
    onUpdateEvent({ ...event, steps: updatedSteps });
  };

  const handleDownloadOriginal = async () => {
    try {
      const originalImageFile = await getOriginalImage(event.id);
      if (originalImageFile instanceof File) {
        const url = URL.createObjectURL(originalImageFile);
        const a = document.createElement('a');
        a.href = url;
        a.download = originalImageFile.name;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      } else {
        console.warn("未找到原始图片或存储的数据格式不正确。");
      }
    } catch (error) {
        console.error("下载原始图片失败:", error);
    }
  };
  
  const sortedSteps = localSteps;
  
  const gridLayoutClasses = {
      sm: 'grid-cols-7',
      md: 'grid-cols-6',
      lg: 'grid-cols-5',
  }[overviewBlockSize];

  return (
    <div className="max-w-3xl mx-auto lg:max-w-none lg:mx-0 pt-8">
      <header className="mb-8 animate-content-enter opacity-0" style={{ animationDelay: '100ms' }}>
        <div className="flex flex-wrap gap-2 mb-4">
            {event.tags?.map(tag => (
                <span key={tag} className="px-3 py-1 rounded-full text-xs font-bold uppercase tracking-wider bg-brand-100 dark:bg-brand-900/30 text-brand-700 dark:text-brand-300 border border-brand-200 dark:border-brand-800/50">
                    {tag}
                </span>
            ))}
        </div>
        <h2 className="text-3xl lg:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-br from-slate-900 via-slate-700 to-slate-900 dark:from-white dark:via-slate-200 dark:to-slate-400 tracking-tight leading-tight">{event.title}</h2>
        <div className="mt-6 p-6 bg-white/50 dark:bg-slate-800/50 rounded-2xl border border-white/60 dark:border-white/5 backdrop-blur-sm">
            <p className="text-lg text-slate-700 dark:text-slate-300 leading-relaxed">{event.description}</p>
            <div className="mt-4 pt-4 border-t border-slate-200/60 dark:border-slate-700/60 flex items-center text-sm text-slate-500 font-mono">
                <span>创建于 {event.createdAt.toLocaleDateString()}</span>
            </div>
        </div>

        {/* Action Buttons Moved Here */}
        <div className="flex flex-wrap items-center gap-3 mt-6">
             {event.hasOriginalImage && (
              <button
                onClick={handleDownloadOriginal}
                className="flex items-center gap-2 text-slate-700 dark:text-slate-200 font-semibold px-4 py-2 rounded-xl shadow-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 transition-all active:scale-95 text-sm"
              >
                <ArrowUpTrayIcon className="w-4 h-4" />
                原图
              </button>
            )}
             <button
              onClick={() => onEdit(event)}
              className="flex items-center gap-2 text-slate-700 dark:text-slate-200 font-semibold px-4 py-2 rounded-xl shadow-sm bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700 transition-all active:scale-95 text-sm"
            >
              <PencilIcon className="w-4 h-4"/>
              编辑
            </button>
            <button
              onClick={() => onEditSteps(event)}
              className="flex items-center gap-2 bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 font-semibold px-5 py-2 rounded-xl shadow-lg hover:bg-slate-800 dark:hover:bg-white/90 transition-all active:scale-95 text-sm"
            >
              <PencilIcon className="w-4 h-4"/>
              规划步骤
            </button>
        </div>
      </header>
      
      {event.imageUrl === DEFAULT_ANIMATED_PLACEHOLDER ? (
        <div className="mb-12 rounded-3xl overflow-hidden shadow-2xl shadow-indigo-500/10 dark:shadow-black/30 border-4 border-white dark:border-slate-800 animate-content-enter opacity-0" style={{ animationDelay: '200ms' }}>
          <AnimatedPlaceholder className="w-full object-cover aspect-video" />
        </div>
      ) : event.imageUrl ? (
        <div className="mb-12 rounded-3xl overflow-hidden shadow-2xl shadow-indigo-500/10 dark:shadow-black/30 border-4 border-white dark:border-slate-800 animate-content-enter opacity-0" style={{ animationDelay: '200ms' }}>
          <img src={event.imageUrl} alt={event.title} className="w-full object-cover aspect-video" />
        </div>
      ) : null}
      
      {event.steps.length > 0 && (
        <div className="mb-12 animate-content-enter opacity-0" style={{ animationDelay: '300ms' }}>
          <div className="flex justify-between items-center mb-6">
            <h3 className="text-2xl font-bold text-slate-800 dark:text-slate-200 flex items-center gap-2">
                <span className="w-2 h-8 bg-brand-500 rounded-full inline-block"></span>
                概览
            </h3>
            <div className="flex items-center gap-1 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm p-1 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700">
              {sizeOptions.map(opt => (
                <button
                  key={opt.id}
                  onClick={() => onOverviewBlockSizeChange(opt.id)}
                  className={`px-3 py-1.5 text-sm font-semibold rounded-lg transition-all ${
                    overviewBlockSize === opt.id
                      ? 'bg-brand-500 text-white shadow-md'
                      : 'text-slate-500 dark:text-slate-400 hover:bg-white dark:hover:bg-slate-700'
                  }`}
                  aria-pressed={overviewBlockSize === opt.id}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>
          <div className={`grid ${gridLayoutClasses} gap-3 touch-none p-1`}>
            {sortedSteps.map(step => {
              const description = step.description.trim();
              const emojiRegex = /^\p{Emoji_Presentation}/u;
              const emojiMatch = description.match(emojiRegex);
              
              const displayText = emojiMatch ? emojiMatch[0] : (Array.from(description)[0] || '');
              
              const layoutClasses = 'items-center aspect-square';

              return (
                <button
                  key={step.id}
                  data-step-id={step.id}
                  onPointerDown={(e) => handlePointerDown(e, step)}
                  onPointerUp={(e) => handlePointerUp(e)}
                  onClick={() => handleOverviewBlockClick(step.id)}
                  title={step.description}
                  aria-label={`切换步骤状态: ${step.description}`}
                  className={`
                    relative rounded-2xl flex ${layoutClasses} justify-center p-2 text-center
                    transition-all duration-300 ease-out transform hover:-translate-y-1 active:scale-95 shadow-sm border
                    ${sizeConfig[overviewBlockSize].container}
                    ${step.completed 
                      ? 'bg-gradient-to-br from-brand-500 to-indigo-600 border-transparent shadow-glow-sm' 
                      : 'bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 hover:shadow-md hover:border-brand-300 dark:hover:border-brand-700'
                    }
                  `}
                >
                  {step.completed && (
                    <div className="absolute inset-0 flex items-center justify-center bg-brand-500/10">
                      <CheckIcon className={`${sizeConfig[overviewBlockSize].icon} text-white animate-dialog-enter drop-shadow-md`} />
                    </div>
                  )}
                  <span className={`${sizeConfig[overviewBlockSize].text} font-bold transition-opacity ${step.completed ? 'opacity-10 text-white' : 'text-slate-700 dark:text-slate-200'}`}>
                    {displayText}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div className="animate-content-enter opacity-0" style={{ animationDelay: '400ms' }}>
        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center mb-8 gap-4">
          <h3 className="text-2xl font-bold text-slate-800 dark:text-slate-200 flex items-center gap-2">
             <span className="w-2 h-8 bg-purple-500 rounded-full inline-block"></span>
             时间线
          </h3>
          {/* Action buttons were here, now moved to top */}
        </div>

        {event.steps.length > 0 ? (
          <div className="relative pl-2">
             {localSteps.map((step, index) => (
              <TimelineItem 
                key={step.id} 
                step={step} 
                onToggle={() => handleTimelineToggleStep(step.id)}
                isLast={index === event.steps.length - 1}
              />
            ))}
          </div>
        ) : (
          <div className="text-center py-16 px-4 bg-white/50 dark:bg-slate-800/50 rounded-3xl border border-dashed border-slate-300 dark:border-slate-700">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-slate-100 dark:bg-slate-800 mb-4">
                <PencilIcon className="w-8 h-8 text-slate-400" />
            </div>
            <p className="text-slate-500 dark:text-slate-400 font-medium">旅程尚未开始。</p>
            <p className="text-sm text-slate-400 mt-1">点击右上角的“规划步骤”来分解你的宏大目标。</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default EventDetailView;