import React, { useState, useMemo, useRef, useEffect, useCallback, useLayoutEffect } from 'react';
import { Event } from './types';
import Header, { SortOrder } from './components/Header';
import EventCard from './components/EventCard';
import EventDetailView from './components/EventDetailView';
import FAB from './components/FAB';
import FilterChips from './components/FilterChips';
import ContextMenu, { ContextMenuAction } from './components/ContextMenu';
import ControlsBar from './components/ControlsBar';
import { PencilIcon, TrashIcon, LoadingSpinnerIcon, ArchiveBoxIcon } from './components/ui/icons';

// Contexts
import { useEvents } from './context/EventsContext';
import { useDatabase } from './context/DatabaseContext';
import { useWindow } from './context/WindowContext';
import { useWindowWidth } from './hooks/useWindowWidth';

interface ActiveFilters {
  status: 'all' | 'in-progress' | 'completed';
  tags: string[];
}

const BackgroundOrbs = () => (
  <div className="fixed inset-0 overflow-hidden pointer-events-none z-0">
    <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-brand-300/30 dark:bg-brand-900/20 blur-[120px] animate-blob mix-blend-multiply dark:mix-blend-screen" />
    <div className="absolute top-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-purple-300/30 dark:bg-purple-900/20 blur-[120px] animate-blob animation-delay-2000 mix-blend-multiply dark:mix-blend-screen" style={{ animationDelay: '2s' }} />
    <div className="absolute bottom-[-20%] left-[20%] w-[60%] h-[60%] rounded-full bg-indigo-300/30 dark:bg-indigo-950/30 blur-[120px] animate-blob animation-delay-4000 mix-blend-multiply dark:mix-blend-screen" style={{ animationDelay: '4s' }} />
  </div>
);

const App: React.FC = () => {
  // Context Hooks
  const { events, tags: customTags, isLoading: isEventsLoading, deleteEvent, updateEvent } = useEvents();
  const { isLoading: isDbLoading, globalSettings, updateGlobalSettings } = useDatabase();
  const { open } = useWindow();
  
  // Local UI State
  const [activeFilters, setActiveFilters] = useState<ActiveFilters>({ status: 'all', tags: [] });
  const [searchQuery, setSearchQuery] = useState('');
  const [sortOrder, setSortOrder] = useState<SortOrder>('createdAt-desc');
  
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [detailViewPlaceholder, setDetailViewPlaceholder] = useState<string | null>(null);
  const [isClosingDetail, setIsClosingDetail] = useState(false);
  
  const [selectedEventIds, setSelectedEventIds] = useState<Set<string>>(new Set());
  
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; event: Event } | null>(null);
  
  const [isFilterBarExpanded, setIsFilterBarExpanded] = useState(() => window.innerWidth >= 768);
  const [fabMode, setFabMode] = useState<'add' | 'toTop'>('add');
  
  const headerRef = useRef<HTMLDivElement>(null);
  const [headerHeight, setHeaderHeight] = useState(0);
  
  const lastScrollY = useRef(0);
  const listScrollRef = useRef<HTMLDivElement>(null);
  const detailScrollRef = useRef<HTMLElement>(null);
  
  const windowWidth = useWindowWidth();
  
  const { cardDensity, collapseCardImages, overviewBlockSize } = globalSettings;
  const isLoading = isEventsLoading || isDbLoading;
  const isSelectionMode = selectedEventIds.size > 0;

  // Header Height Observer
  useLayoutEffect(() => {
    const element = headerRef.current;
    if (!element) return;
    setHeaderHeight(element.offsetHeight);
    const observer = new ResizeObserver(() => setHeaderHeight(element.offsetHeight));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  // Derived State: Selected Event
  const selectedEvent = useMemo(() => 
    events.find(e => e.id === selectedEventId) || null
  , [events, selectedEventId]);

  // Derived State: Filtered Events
  const filteredEvents = useMemo(() => {
    let processedEvents = [...events];
    
    // Search
    if (searchQuery.trim() !== '') {
      const lowercasedQuery = searchQuery.toLowerCase();
      processedEvents = processedEvents.filter(event =>
        event.title.toLowerCase().includes(lowercasedQuery) ||
        event.description.toLowerCase().includes(lowercasedQuery)
      );
    }
    
    // Status Filter
    if (activeFilters.status !== 'all') {
      processedEvents = processedEvents.filter(event => {
        const totalSteps = event.steps.length;
        if (totalSteps === 0) return activeFilters.status === 'in-progress';
        const completedSteps = event.steps.filter(step => step.completed).length;
        if (activeFilters.status === 'in-progress') return completedSteps < totalSteps;
        if (activeFilters.status === 'completed') return completedSteps === totalSteps;
        return false;
      });
    }
    
    // Tag Filter
    if (activeFilters.tags.length > 0) {
      processedEvents = processedEvents.filter(event =>
        activeFilters.tags.every(tag => event.tags?.includes(tag))
      );
    }
    
    // Sorting
    const getProgress = (event: Event) => {
      if (event.steps.length === 0) return 0;
      return (event.steps.filter(s => s.completed).length / event.steps.length) * 100;
    };
    
    return processedEvents.sort((a, b) => {
      switch (sortOrder) {
        case 'createdAt-asc': return a.createdAt.getTime() - b.createdAt.getTime();
        case 'title-asc': return a.title.localeCompare(b.title);
        case 'title-desc': return b.title.localeCompare(a.title);
        case 'progress-asc': return getProgress(a) - b.createdAt.getTime();
        case 'progress-desc': return getProgress(b) - getProgress(a);
        default: return b.createdAt.getTime() - a.createdAt.getTime();
      }
    });
  }, [events, activeFilters, searchQuery, sortOrder]);

  // Grid Config (Mapping directly to globalSettings logic)
  const gridConfig = useMemo(() => {
    let numColumns;
    if (windowWidth >= 1280) { // Desktop
      if (cardDensity >= 95) numColumns = 5;
      else if (cardDensity >= 68) numColumns = 4;
      else if (cardDensity >= 40) numColumns = 3;
      else if (cardDensity >= 20) numColumns = 2;
      else numColumns = 1;
    } else if (windowWidth >= 768) { // Tablet
      if (cardDensity >= 85) numColumns = 4;
      else if (cardDensity >= 55) numColumns = 3;
      else if (cardDensity >= 25) numColumns = 2;
      else numColumns = 1;
    } else { // Mobile
      if (cardDensity >= 50) numColumns = 2;
      else numColumns = 1;
    }
    return { numColumns };
  }, [cardDensity, windowWidth]);

  // Scroll Handling for FAB
  const handleScroll = useCallback((e: globalThis.Event) => {
    const target = e.currentTarget as HTMLElement;
    const currentScrollY = target.scrollTop;
    const newDirection = currentScrollY > lastScrollY.current && currentScrollY > 50 ? 'down' : 'up';
    const newFabMode = newDirection === 'down' && currentScrollY > 300 ? 'toTop' : 'add';
    setFabMode(newFabMode);
    lastScrollY.current = currentScrollY;
  }, []);

  useEffect(() => {
    lastScrollY.current = 0;
    setFabMode('add');
    const listEl = listScrollRef.current;
    const detailEl = detailScrollRef.current;
    if (listEl) listEl.addEventListener('scroll', handleScroll, { passive: true });
    if (detailEl) detailEl.addEventListener('scroll', handleScroll, { passive: true });
    return () => {
      if (listEl) listEl.removeEventListener('scroll', handleScroll);
      if (detailEl) detailEl.removeEventListener('scroll', handleScroll);
    };
  }, [handleScroll, selectedEventId]);

  // Handlers
  const handleSelectEvent = (event: Event) => {
    setSelectedEventId(event.id);
    setDetailViewPlaceholder(null);
  };

  const handleBackToList = () => {
    setIsClosingDetail(true);
    setTimeout(() => { 
        setSelectedEventId(null); 
        setIsClosingDetail(false);
        setDetailViewPlaceholder(null);
    }, 300);
  };

  const handleCardClick = (event: Event) => {
    if (isSelectionMode) {
        setSelectedEventIds(prev => {
            const newSet = new Set(prev);
            if (newSet.has(event.id)) newSet.delete(event.id);
            else newSet.add(event.id);
            return newSet;
        });
    } else {
        handleSelectEvent(event);
    }
  };

  const handleCardLongPress = (event: Event) => {
    setSelectedEventIds(new Set([event.id]));
  };

  const handleClearSelection = () => setSelectedEventIds(new Set());

  // Context Menu Logic
  const handleOpenContextMenu = (position: { x: number; y: number }, event: Event) => setContextMenu({ ...position, event });
  const handleCloseContextMenu = () => setContextMenu(null);
  
  const contextMenuActions: ContextMenuAction[] = contextMenu ? [
    { label: '编辑', icon: <PencilIcon className="w-5 h-5" />, onClick: () => open('edit-event', { eventId: contextMenu.event.id }) },
    { 
        label: '删除', 
        icon: <TrashIcon className="w-5 h-5" />, 
        isDestructive: true, 
        onClick: () => open('confirm', { 
            message: '您确定要删除此事件吗？', 
            isDestructive: true, 
            confirmText: '删除',
            onConfirm: () => {
                deleteEvent(contextMenu.event.id);
                if (selectedEventId === contextMenu.event.id) {
                    setSelectedEventId(null);
                    setDetailViewPlaceholder('您正在查看的事件已被删除。');
                }
            } 
        }) 
    }
  ] : [];

  // Filter Handlers
  const handleStatusFilterChange = (status: 'all' | 'in-progress' | 'completed') => setActiveFilters(prev => ({ ...prev, status }));
  const handleTagFilterChange = (tag: string) => setActiveFilters(prev => {
      const newTags = new Set(prev.tags);
      if (newTags.has(tag)) newTags.delete(tag); else newTags.add(tag);
      return { ...prev, tags: Array.from(newTags) };
  });
  const handleResetTagFilters = () => setActiveFilters(prev => ({ ...prev, tags: [] }));

  // Render Helpers
  const renderEventList = () => {
    if (isLoading && events.length === 0) {
        return (
            <div className="flex items-center justify-center h-full pt-20">
                <div className="glass p-6 rounded-2xl flex flex-col items-center gap-4 text-slate-500 dark:text-slate-400 shadow-glass">
                    <LoadingSpinnerIcon className="w-8 h-8 text-brand-500" />
                    <p className="font-semibold">正在同步数据水晶...</p>
                </div>
            </div>
        );
    }
    if (filteredEvents.length === 0) {
        return <div className="text-center py-20 px-4">
            <h2 className="text-2xl font-bold text-slate-700 dark:text-slate-300">档案馆空空如也</h2>
            <p className="mt-2 text-slate-500">点击右下角的法阵开始编写一段新的编年史。</p>
        </div>;
    }

    return (
      <div style={{ columnCount: gridConfig.numColumns, columnGap: '1.5rem' }}>
        {filteredEvents.map((event, index) => (
          <div
            key={event.id}
            className="animate-content-enter opacity-0 mb-6 break-inside-avoid"
            style={{ animationDelay: `${index * 50}ms` }}
          >
            <EventCard
              event={event}
              onClick={handleCardClick}
              onLongPress={handleCardLongPress}
              isSelected={selectedEventIds.has(event.id)}
              isSelectionMode={isSelectionMode}
              onOpenContextMenu={handleOpenContextMenu}
              collapseCardImages={collapseCardImages}
            />
          </div>
        ))}
      </div>
    );
  };

  const isMobileDetailView = (selectedEventId || detailViewPlaceholder) && windowWidth < 1024;
  
  const fabOnClick = fabMode === 'toTop' 
    ? () => {
        const ref = (selectedEventId || detailViewPlaceholder) ? detailScrollRef.current : listScrollRef.current;
        ref?.scrollTo({ top: 0, behavior: 'smooth' });
    } 
    : () => open('edit-event', {});

  return (
    <div className="h-screen relative overflow-hidden bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-200">
      <BackgroundOrbs />
      
      <div className="relative z-10 h-full flex flex-col">
        <div
            ref={headerRef}
            className={`${isMobileDetailView ? 'hidden' : ''} z-40 transition-all duration-300 glass border-b border-white/20 dark:border-white/5 sticky top-0 backdrop-blur-md`}
        >
            <Header
                searchQuery={searchQuery} onSearchChange={setSearchQuery}
                sortOrder={sortOrder} onSortChange={setSortOrder}
                onOpenSettings={() => open('settings', {})}
                isSelectionMode={isSelectionMode}
                selectedCount={selectedEventIds.size}
                onClearSelection={handleClearSelection}
                onDeleteSelection={() => open('confirm', {
                    message: `您确定要删除选中的 ${selectedEventIds.size} 个事件吗？`,
                    isDestructive: true,
                    confirmText: '删除',
                    onConfirm: () => {
                        const ids = Array.from(selectedEventIds);
                        ids.forEach(id => deleteEvent(id));
                        if (selectedEventId && ids.includes(selectedEventId)) {
                            setSelectedEventId(null);
                            setDetailViewPlaceholder('您正在查看的事件已在所选项目中被删除。');
                        }
                        handleClearSelection();
                    }
                })}
                onManageSelectionTags={() => open('manage-selection-tags', { selectedEventIds: Array.from(selectedEventIds) })}
            />
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
            <div className="pt-2 flex-shrink-0 transition-all duration-300 pb-4 -mx-4 sm:-mx-6 lg:-mx-8">
                <FilterChips
                activeFilters={activeFilters} onStatusChange={handleStatusFilterChange}
                onTagToggle={handleTagFilterChange} customTags={customTags}
                onManageTags={() => open('manage-tags', {})}
                isExpanded={isFilterBarExpanded}
                onToggleExpand={() => setIsFilterBarExpanded(prev => !prev)}
                onResetTags={handleResetTagFilters}
                />
            </div>
            </div>
        </div>

        <div className="flex-1 overflow-hidden">
            <div className="max-w-7xl mx-auto h-full">
            <main className="h-full lg:flex lg:gap-x-6 items-start p-4 lg:p-6 lg:pt-6">
                <aside
                ref={listScrollRef}
                className={`no-scrollbar h-full overflow-y-auto rounded-3xl transition-all duration-300 ${selectedEventId || detailViewPlaceholder ? 'hidden lg:block lg:w-[450px] lg:flex-shrink-0' : 'w-full'} ${(!selectedEventId && !detailViewPlaceholder) ? '' : 'lg:bg-white/40 lg:dark:bg-slate-900/40 lg:backdrop-blur-md lg:border lg:border-white/20 lg:dark:border-white/5'}`}
                onClick={() => { if (isSelectionMode) handleClearSelection(); }}
                >
                <div className={`pb-24 lg:p-4`}>
                    {renderEventList()}
                </div>
                </aside>

                <section
                ref={detailScrollRef}
                className={`no-scrollbar h-full overflow-y-auto rounded-3xl transition-all duration-500 glass-card shadow-glass dark:shadow-glass-dark ${selectedEventId || detailViewPlaceholder ? 'w-full flex-grow opacity-100 translate-x-0' : 'hidden lg:block lg:w-0 lg:opacity-0 lg:translate-x-10 lg:overflow-hidden'} ${isClosingDetail ? 'animate-view-exit' : 'animate-view-enter'}`}
                >
                {selectedEvent ? (
                    <div className="relative min-h-full pb-24">
                        {/* Mobile close button overlay/control bar */}
                        <div className="sticky top-0 right-0 p-4 flex justify-end z-20 pointer-events-none">
                             <div className="pointer-events-auto">
                                <ControlsBar onClose={handleBackToList} />
                             </div>
                        </div>
                        <div className="-mt-16 px-4 sm:px-8">
                            <EventDetailView 
                                key={selectedEvent.id} 
                                event={selectedEvent} 
                                onBack={handleBackToList} 
                                onUpdateEvent={(updatedEvent) => updateEvent(updatedEvent)} 
                                onEdit={() => open('edit-event', { eventId: selectedEvent.id })} 
                                onEditSteps={() => open('steps-editor', { eventId: selectedEvent.id })} 
                                overviewBlockSize={overviewBlockSize} 
                                onOverviewBlockSizeChange={(size) => updateGlobalSettings({ overviewBlockSize: size })} 
                            />
                        </div>
                    </div>
                ) : detailViewPlaceholder ? (
                    <div className="flex items-center justify-center h-full">
                        <div className="text-center text-slate-500 dark:text-slate-400 px-8 flex flex-col items-center gap-4">
                            <div className="w-20 h-20 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
                                <ArchiveBoxIcon className="w-10 h-10 text-slate-400 dark:text-slate-500" />
                            </div>
                            <p className="font-semibold text-lg">{detailViewPlaceholder}</p>
                        </div>
                    </div>
                ) : (
                    <div className="hidden lg:flex items-center justify-center h-full text-slate-400 dark:text-slate-600">
                        <div className="text-center">
                            <div className="w-24 h-24 mx-auto mb-4 opacity-20">
                                <svg fill="currentColor" viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5zm0 9l2.5-1.25L12 8.5l-2.5 1.25L12 11zm0 2.5l-5-2.5-5 2.5L12 22l10-8.5-5-2.5-5 2.5z"/></svg>
                            </div>
                            <p>选择一份卷轴（事件）以查看详情</p>
                        </div>
                    </div>
                )}
                </section>
            </main>
            </div>
        </div>
      </div>
      
      {!isSelectionMode && <FAB onClick={fabOnClick} mode={fabMode} />}
      {contextMenu && <ContextMenu x={contextMenu.x} y={contextMenu.y} actions={contextMenuActions} onClose={handleCloseContextMenu}/>}
    </div>
  );
};

export default App;