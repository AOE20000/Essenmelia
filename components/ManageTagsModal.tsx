import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { XIcon, PlusIcon, TrashIcon, CheckIcon } from './icons';
import ContextMenu, { ContextMenuAction } from './ContextMenu';
import useLongPress from '../hooks/useLongPress';

// Helper component for inline editing text (from StepsEditorPanel)
const InlineEdit: React.FC<{
    text: string;
    onSave: (newText: string) => boolean; // Return boolean for success
    className?: string;
    placeholder?: string;
    onEditingChange?: (isEditing: boolean) => void;
}> = ({ text, onSave, className, placeholder, onEditingChange }) => {
    const [isEditing, setIsEditing] = useState(false);
    const [editText, setEditText] = useState(text);
    const inputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        if (isEditing) {
            inputRef.current?.focus();
            inputRef.current?.select();
        }
    }, [isEditing]);
    
    useEffect(() => {
        setEditText(text);
    }, [text]);

    const handleSave = () => {
        if (editText.trim() && editText.trim() !== text) {
            if (!onSave(editText.trim())) {
                // Revert on failure
                setEditText(text);
            }
        } else {
            setEditText(text);
        }
        setIsEditing(false);
        onEditingChange?.(false);
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') handleSave();
        if (e.key === 'Escape') {
            setEditText(text);
            setIsEditing(false);
            onEditingChange?.(false);
        }
    };

    if (isEditing) {
        return (
            <input
                ref={inputRef}
                type="text"
                value={editText}
                onChange={(e) => setEditText(e.target.value)}
                onBlur={handleSave}
                onKeyDown={handleKeyDown}
                placeholder={placeholder}
                className={`w-full bg-white/50 dark:bg-slate-800/50 p-1 -m-1 rounded min-w-0 border border-brand-300 dark:border-brand-700 outline-none ring-2 ring-brand-500/20 ${className}`}
            />
        );
    }

    return (
        <p onDoubleClick={() => { setIsEditing(true); onEditingChange?.(true); }} className={`flex-grow cursor-pointer select-none min-w-0 break-words hover:text-brand-600 dark:hover:text-brand-400 transition-colors ${className}`}>
            {text}
        </p>
    );
};

const DropIndicator: React.FC<{className?: string}> = ({className}) => {
    return <div className={`w-full h-1 bg-brand-500 rounded-full my-1 shadow-[0_0_8px_rgba(99,102,241,0.6)] ${className}`} />;
};

// Item component styled exactly like items in StepsEditorPanel
const TagItem: React.FC<{
    tag: string;
    onUpdate: (oldTag: string, newTag: string) => boolean;
    onItemClick: (e: React.MouseEvent | React.TouchEvent, tag: string) => void;
    onContextMenu: (e: React.MouseEvent) => void;
    isSelected: boolean;
    isGhost: boolean;
    isSelectionMode: boolean;
    dragProps: {
        onDragStart: (e: React.DragEvent) => void;
        onTouchStart: (e: React.TouchEvent) => void;
    };
}> = ({ tag, onUpdate, onItemClick, onContextMenu, isSelected, isGhost, isSelectionMode, dragProps }) => {
    const [isRenaming, setIsRenaming] = useState(false);
    
    // We use long press ONLY to start dragging in this view.
    // Selection is done via normal clicks or "Select All".
    const longPressEvents = useLongPress(
        () => {}, // Drag handled by onDrag below, no separate long press action
        (e) => onItemClick(e, tag),
        { 
            delay: 400,
            onDrag: isSelectionMode ? dragProps.onTouchStart : undefined
        }
    );
    
    return (
        <div
            data-reorder-id={tag}
            data-item-type="tag"
            className={`flex items-center gap-3 p-3 rounded-xl transition-all duration-200 
            ${isGhost ? 'opacity-30' : 'opacity-100'} 
            ${isSelected 
                ? 'bg-brand-50 dark:bg-brand-900/30 ring-1 ring-brand-500 shadow-md translate-x-1' 
                : 'bg-white/80 dark:bg-slate-700/80 hover:bg-white dark:hover:bg-slate-700 shadow-sm hover:shadow-md hover:-translate-y-0.5 border border-transparent hover:border-slate-200 dark:hover:border-slate-600'
            }`}
        >
            <div
                onClick={(e) => onItemClick(e, tag)}
                onMouseUp={e => e.stopPropagation()}
                onTouchEnd={e => e.stopPropagation()}
                onMouseDown={e => e.stopPropagation()}
                onTouchStart={e => e.stopPropagation()}
                onDragStart={e => { e.preventDefault(); e.stopPropagation(); }}
                draggable={false}
                className="flex-shrink-0 self-stretch flex items-center p-2 -m-2 cursor-pointer"
                aria-label={`选择标签 ${tag}`}
            >
                <div
                    className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-all pointer-events-none ${isSelected ? 'bg-brand-500 border-brand-500 scale-110' : 'bg-transparent border-slate-300 dark:border-slate-500 group-hover:border-brand-300'}`}
                >
                    {isSelected && <CheckIcon className="w-3 h-3 text-white" />}
                </div>
            </div>

            <div
                draggable={isSelectionMode && !isRenaming}
                onDragStart={isSelectionMode ? dragProps.onDragStart : undefined}
                {...longPressEvents}
                onContextMenu={onContextMenu}
                className={`flex items-center self-stretch flex-grow min-w-0 ${isSelectionMode && !isRenaming ? 'cursor-grab' : ''}`}
            >
                <InlineEdit 
                    text={tag} 
                    onSave={(newTag) => onUpdate(tag, newTag)} 
                    className="text-slate-800 dark:text-slate-100 font-medium" 
                    onEditingChange={setIsRenaming}
                />
            </div>
        </div>
    );
};

const AddInput: React.FC<{
    placeholder: string;
    onAdd: (value: string) => void | boolean;
}> = ({ placeholder, onAdd }) => {
    const [value, setValue] = useState('');
    
    const handleAdd = () => {
        if (value.trim()) {
            const success = onAdd(value.trim());
            if (success !== false) {
                setValue('');
            }
        }
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            handleAdd();
        }
    };

    return (
        <div className="flex flex-col sm:flex-row gap-2">
            <input 
                type="text" 
                value={value} 
                onChange={(e) => setValue(e.target.value)} 
                onKeyDown={handleKeyDown} 
                placeholder={placeholder}
                className="flex-grow px-4 py-2.5 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm border border-slate-300 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-brand-500/20 outline-none transition-all shadow-sm" />
            <button 
                onClick={handleAdd} 
                className="px-4 py-2.5 rounded-xl font-bold flex items-center justify-center transition-transform active:scale-95 bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 hover:bg-slate-300 dark:hover:bg-slate-600"
            >
                <PlusIcon className="w-5 h-5" />
            </button>
        </div>
    );
};

interface ManageTagsModalProps {
  onClose: () => void;
  tags: string[];
  onAddTag: (tag: string) => void;
  onDeleteTags: (tags: string[]) => void;
  onRenameTag: (oldTag: string, newTag: string) => boolean;
  onReorderTags: (reorderedTags: string[]) => void;
  setHeader: (node: React.ReactNode) => void;
  setOverrideCloseAction: (action: (() => void) | null) => void;
}

const ManageTagsModal: React.FC<ManageTagsModalProps> = ({ onClose, tags, onAddTag, onDeleteTags, onRenameTag, onReorderTags, setHeader, setOverrideCloseAction }) => {
  const [localTags, setLocalTags] = useState<string[]>([]);
  const [selectedTags, setSelectedTags] = useState<Set<string>>(new Set());
  const [lastSelectedTag, setLastSelectedTag] = useState<string | null>(null);
  
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; tags: Set<string> } | null>(null);

  const [draggedTags, setDraggedTags] = useState<Set<string>>(new Set());
  const [dropIndex, setDropIndex] = useState<number | null>(null);
  const tagsContainerRef = useRef<HTMLDivElement>(null);
  
  const [touchDragState, setTouchDragState] = useState<{
    payload: any | null;
    ghostElement: React.ReactNode | null;
    position: { x: number; y: number };
    offset: { x: number; y: number };
  } | null>(null);


  useEffect(() => {
    setLocalTags([...tags]);
    setSelectedTags(new Set());
    setLastSelectedTag(null);
    setContextMenu(null);
    setDraggedTags(new Set());
    setDropIndex(null);
  }, [tags]);

  const isSelectionMode = useMemo(() => selectedTags.size > 0, [selectedTags]);

  const handleTagInteraction = (e: React.MouseEvent | React.TouchEvent, clickedTag: string) => {
    e.stopPropagation();
    
    if ('shiftKey' in e && e.shiftKey && lastSelectedTag) {
        const lastIndex = localTags.indexOf(lastSelectedTag);
        const currentIndex = localTags.indexOf(clickedTag);
        if (lastIndex !== -1 && currentIndex !== -1) {
            const start = Math.min(lastIndex, currentIndex);
            const end = Math.max(lastIndex, currentIndex);
            const rangeSelection = new Set(localTags.slice(start, end + 1));
            setSelectedTags(rangeSelection);
        }
        setLastSelectedTag(clickedTag);
        return;
    }

    const newSelection = new Set(selectedTags);
    newSelection.has(clickedTag) ? newSelection.delete(clickedTag) : newSelection.add(clickedTag);
    setSelectedTags(newSelection);
    setLastSelectedTag(clickedTag);
  };
  
  const handleAddTags = (tagsString: string) => {
    const tagsToAdd = tagsString.split(/\s+/).filter(Boolean);
    if (tagsToAdd.length === 0) {
      return false;
    }

    tagsToAdd.forEach((tag) => {
      if (!tags.includes(tag)) {
        onAddTag(tag);
      }
    });

    return true;
  };

  const handleDeleteSelected = useCallback(() => {
    const tagsToDelete = contextMenu ? Array.from(contextMenu.tags) : Array.from(selectedTags);
    if (tagsToDelete.length > 0) {
      onDeleteTags(tagsToDelete);
    }
    setSelectedTags(new Set());
    setLastSelectedTag(null);
    setContextMenu(null);
  }, [onDeleteTags, selectedTags, contextMenu]);

  const handleRenameTag = (oldTag: string, newTag: string): boolean => {
    if (onRenameTag(oldTag, newTag)) {
        if (selectedTags.has(oldTag)) {
            const newSelection = new Set(selectedTags);
            newSelection.delete(oldTag);
            newSelection.add(newTag);
            setSelectedTags(newSelection);
        }
        if (lastSelectedTag === oldTag) setLastSelectedTag(newTag);
        return true;
    }
    return false;
  };
  
  const handleContextMenu = (e: React.MouseEvent, rightClickedTag: string) => {
    e.preventDefault();
    e.stopPropagation();
    let selection = new Set(selectedTags);
    if (!selection.has(rightClickedTag)) {
        selection = new Set([rightClickedTag]);
        setSelectedTags(selection);
        setLastSelectedTag(rightClickedTag);
    }
    if (selection.size > 0) setContextMenu({ x: e.clientX, y: e.clientY, tags: selection });
  };

  const contextMenuActions = useMemo<ContextMenuAction[]>(() => {
    if (!contextMenu) return [];
    const count = contextMenu.tags.size;
    return [
        { label: `删除 ${count} 个标签`, icon: <TrashIcon className="w-5 h-5" />, isDestructive: true, onClick: handleDeleteSelected }
    ];
  }, [contextMenu, handleDeleteSelected]);
  
  const handleContainerClickToDeselect = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
        setSelectedTags(new Set());
        setLastSelectedTag(null);
    }
  };

  const startTouchDrag = useCallback((e: React.TouchEvent, tag: string) => {
      e.preventDefault();
      
      const isDraggingSelected = selectedTags.has(tag);
      const tagsToDrag = isDraggingSelected && selectedTags.size > 0 ? new Set(selectedTags) : new Set([tag]);
      
      setDraggedTags(tagsToDrag);
      const orderedTagsToDrag = Array.from(tagsToDrag).sort((a, b) => localTags.indexOf(a) - localTags.indexOf(b));

      const payload = { tags: orderedTagsToDrag };
      
      const ghostContent = `${orderedTagsToDrag.length}个标签`;
      const ghost = <div className="p-2 rounded-lg bg-white dark:bg-slate-600 shadow-xl">{ghostContent}</div>;

      const touch = e.touches[0];
      const targetRect = (e.currentTarget as HTMLElement).getBoundingClientRect();
      
      setTouchDragState({
          payload, ghostElement: ghost,
          position: { x: touch.clientX, y: touch.clientY },
          offset: { x: touch.clientX - targetRect.left, y: touch.clientY - targetRect.top }
      });

  }, [selectedTags, localTags]);
  
  const commitDrop = useCallback((tagsToDrop: string[], dropIndex: number) => {
      if (tagsToDrop.length === 0) return;
      
      const dropTargetId = localTags[dropIndex];
      if (tagsToDrop.includes(dropTargetId)) return;
      
      const remainingTags = localTags.filter(t => !tagsToDrop.includes(t));
      const newDropIndex = dropTargetId ? remainingTags.indexOf(dropTargetId) : remainingTags.length;

      const newTags = [ ...remainingTags.slice(0, newDropIndex), ...tagsToDrop, ...remainingTags.slice(newDropIndex) ];
      
      setLocalTags(newTags);
      onReorderTags(newTags);

      setSelectedTags(new Set());
  }, [localTags, onReorderTags]);
  
  const updateDropIndicator = useCallback((clientY: number) => {
      const container = tagsContainerRef.current;
      if (!container || draggedTags.size === 0) return;
      
      const allOriginalElements = Array.from(container.querySelectorAll('[data-reorder-id]')) as HTMLElement[];
      const draggableElements = allOriginalElements.filter(el => !draggedTags.has(el.dataset.reorderId || ''));

      if (draggableElements.length === 0) {
          setDropIndex(0);
          return;
      }

      const closest = draggableElements.reduce(
          (acc, child) => {
              const box = child.getBoundingClientRect();
              const offset = clientY - (box.top + box.height / 2);
              if (offset < 0 && offset > acc.offset) {
                  return { offset: offset, element: child };
              } else {
                  return acc;
              }
          },
          { offset: Number.NEGATIVE_INFINITY, element: null as HTMLElement | null }
      );
      
      const newIndex = closest.element
          ? allOriginalElements.indexOf(closest.element)
          : allOriginalElements.length;

      if (dropIndex !== newIndex) {
          setDropIndex(newIndex);
      }
  }, [draggedTags, dropIndex]);
  
    useEffect(() => {
        const handleTouchMove = (e: TouchEvent) => {
            if (touchDragState) {
                e.preventDefault();
                const touch = e.touches[0];
                setTouchDragState(prev => prev ? { ...prev, position: { x: touch.clientX, y: touch.clientY } } : null);
                updateDropIndicator(touch.clientY);
            }
        };

        const handleTouchEnd = (e: TouchEvent) => {
            if (touchDragState && dropIndex !== null) {
                commitDrop(touchDragState.payload.tags, dropIndex);
            }
            setTouchDragState(null);
            setDropIndex(null);
            setDraggedTags(new Set());
        };

        if (touchDragState) {
            window.addEventListener('touchmove', handleTouchMove, { passive: false });
            window.addEventListener('touchend', handleTouchEnd);
        }

        return () => {
            window.removeEventListener('touchmove', handleTouchMove);
            window.removeEventListener('touchend', handleTouchEnd);
        };
    }, [touchDragState, dropIndex, commitDrop, updateDropIndicator]);


  const handleDragStart = (e: React.DragEvent, tag: string) => {
    const isDraggingSelected = selectedTags.has(tag);
    const tagsToDrag = isDraggingSelected && selectedTags.size > 0 ? new Set(selectedTags) : new Set([tag]);
    
    setDraggedTags(tagsToDrag);
    const orderedTagsToDrag = Array.from(tagsToDrag).sort((a, b) => localTags.indexOf(a) - localTags.indexOf(b));

    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('application/json', JSON.stringify({ tags: orderedTagsToDrag }));
  };
  
  const handleDragOver = (e: React.DragEvent) => {
      e.preventDefault();
      updateDropIndicator(e.clientY);
  };
  
  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    const finalDropIndex = dropIndex;
    setDropIndex(null); 
    setDraggedTags(new Set());
    
    if (finalDropIndex === null) return;
    
    let tagsToDrop: string[] = [];
    try {
        const data = JSON.parse(e.dataTransfer.getData('application/json'));
        if (data && Array.isArray(data.tags)) { tagsToDrop = data.tags; }
    } catch { return; }
    
    commitDrop(tagsToDrop, finalDropIndex);
  };
  
  const handleDragEnd = () => {
    setDraggedTags(new Set());
    setDropIndex(null);
  };

  useEffect(() => {
      const headerContent = (
        <div className="flex items-center justify-between w-full">
            <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100 flex-shrink-0 truncate animate-fade-in-up">
                {isSelectionMode ? `已选中: ${selectedTags.size} 个标签` : '管理标签'}
            </h2>
            {isSelectionMode && (
                <button 
                    onClick={handleDeleteSelected} 
                    className="text-sm font-semibold px-4 py-2 bg-red-50 dark:bg-red-900/50 hover:bg-red-100 dark:hover:bg-red-900/80 text-red-600 dark:text-red-400 transition-colors active:scale-95 flex items-center gap-2 rounded-lg animate-fade-in-up">
                    <TrashIcon className="w-5 h-5" /> 删除
                </button>
            )}
        </div>
      );
      setHeader(headerContent);

      return () => {
        setOverrideCloseAction(null);
      }
  }, [isSelectionMode, selectedTags.size, handleDeleteSelected, setHeader, setOverrideCloseAction]);

  return (
    <>
      <div
        className="flex flex-col h-full bg-slate-50/50 dark:bg-slate-900/50 rounded-lg"
        onClick={() => {
          setContextMenu(null);
        }}
      >
        <div
            ref={tagsContainerRef}
            className="flex-grow overflow-y-auto flex flex-col gap-2 content-start cursor-default p-2"
            onDrop={handleDrop}
            onDragOver={handleDragOver}
            onDragLeave={() => setDropIndex(null)}
            onDragEnd={handleDragEnd}
            onClick={handleContainerClickToDeselect}
        >
            {localTags.length > 0 ? (
                localTags.map((tag, index) => (
                    <React.Fragment key={tag}>
                        {dropIndex === index && <DropIndicator />}
                        <TagItem 
                            tag={tag} 
                            onUpdate={handleRenameTag}
                            onItemClick={handleTagInteraction}
                            onContextMenu={(e) => handleContextMenu(e, tag)}
                            isSelected={selectedTags.has(tag)}
                            isGhost={draggedTags.has(tag)}
                            isSelectionMode={isSelectionMode}
                            dragProps={{ 
                            onDragStart: (e) => handleDragStart(e, tag),
                            onTouchStart: (e) => startTouchDrag(e, tag)
                            }}
                        />
                    </React.Fragment>
                ))
            ) : (
                <p className="text-slate-500 dark:text-slate-400 text-center py-8 select-none italic">还没有自定义标签。</p>
            )}
            {dropIndex === localTags.length && <DropIndicator />}
        </div>
        <div className="flex-shrink-0 p-4 pt-3 border-t border-slate-200/50 dark:border-slate-700/50">
          <AddInput placeholder="添加新标签 (用空格分隔)..." onAdd={handleAddTags} />
        </div>
      </div>
      {touchDragState && (
          <div 
              id="touch-drag-ghost"
              className="fixed top-0 left-0 pointer-events-none z-50" 
              style={{ transform: `translate(${touchDragState.position.x - touchDragState.offset.x}px, ${touchDragState.position.y - touchDragState.offset.y}px)` }}
          >
              {touchDragState.ghostElement}
          </div>
      )}
      {contextMenu && <ContextMenu x={contextMenu.x} y={contextMenu.y} actions={contextMenuActions} onClose={() => setContextMenu(null)} />}
    </>
  );
};

export default ManageTagsModal;