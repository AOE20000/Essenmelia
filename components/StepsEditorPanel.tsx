import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { Event, ProgressStep, StepTemplate, StepSetTemplate, StepSetTemplateStep } from '../types';
import { XIcon, PlusIcon, TrashIcon, SaveIcon, ChevronDownIcon, ChevronUpIcon, CheckIcon, ChevronLeftIcon, ChevronRightIcon, ArrowUpTrayIcon, ArchiveBoxIcon } from './icons';
import ContextMenu, { ContextMenuAction } from './ContextMenu';
import Modal from './Modal';
import useLongPress from '../hooks/useLongPress';
import Snackbar from './Snackbar';

const useWindowWidth = () => {
    const [windowWidth, setWindowWidth] = useState(window.innerWidth);
    useEffect(() => {
        const handleResize = () => setWindowWidth(window.innerWidth);
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);
    return windowWidth;
};


// Sub-component for inline editing text
const InlineEdit: React.FC<{
    text: string;
    onSave: (newText: string) => void;
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
    }, [text])

    const handleSave = () => {
        if (editText.trim()) {
            onSave(editText.trim());
        } else {
            setEditText(text); // Revert if empty
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
                className="flex-grow bg-white dark:bg-slate-800 p-1 rounded min-w-0"
            />
        );
    }

    return (
        <p onDoubleClick={() => { setIsEditing(true); onEditingChange?.(true); }} className={`flex-grow cursor-pointer select-none min-w-0 break-words ${className}`}>
            {text}
        </p>
    );
};

interface DraggableItemProps {
    id: string;
    itemType: 'current' | 'archive';
    description: string;
    onUpdate: (id: string, newDescription: string) => void;
    onItemClick: (e: React.MouseEvent | React.TouchEvent, id: string) => void;
    onItemLongPress: (id: string) => void;
    onItemPointerDown: (e: React.PointerEvent, itemType: 'current' | 'archive' | 'templateSet', id: string) => void;
    onContextMenu: (e: React.MouseEvent) => void;
    isGhost: boolean;
    isSelected: boolean;
    isSelectionMode: boolean;
    dragProps: {
        onDragStart: (e: React.DragEvent) => void;
        onTouchStart: (e: React.TouchEvent) => void;
    };
}

// Sub-component for a single draggable/editable item (used in Panel 1 & 2)
const DraggableItem: React.FC<DraggableItemProps> = ({ id, itemType, description, onUpdate, onItemClick, onItemLongPress, onItemPointerDown, onContextMenu, isGhost, isSelected, isSelectionMode, dragProps }) => {
    const [isRenaming, setIsRenaming] = useState(false);
    
    const handleBodyClick = (e: React.MouseEvent | React.TouchEvent) => {
        onItemClick(e, id);
    };

    const longPressEvents = useLongPress(
        // FIX: The onLongPress callback for useLongPress expects an event argument.
        (e) => onItemLongPress(id),
        handleBodyClick,
        { 
            delay: 400,
            onDrag: isSelectionMode ? dragProps.onTouchStart : undefined,
        }
    );

    return (
        <div
            data-reorder-id={id}
            data-item-type={itemType}
            className={`flex items-center gap-2 p-2 rounded-lg bg-white dark:bg-slate-700 transition-all duration-150 ${isGhost ? 'opacity-30 pointer-events-none' : 'opacity-100'} ${isSelected ? 'ring-2 ring-slate-500 shadow-lg' : 'shadow-sm'}`}
        >
            <div
                onClick={handleBodyClick}
                onPointerDown={(e) => {
                    e.stopPropagation();
                    onItemPointerDown(e, itemType, id);
                }}
                onMouseUp={e => e.stopPropagation()}
                onTouchEnd={e => e.stopPropagation()}
                onMouseDown={e => e.stopPropagation()}
                onTouchStart={e => e.stopPropagation()}
                onDragStart={e => { e.preventDefault(); e.stopPropagation(); }}
                draggable={false}
                className="flex-shrink-0 self-stretch flex items-center p-3 -m-1 cursor-pointer"
                aria-label={`选择步骤 ${description}`}
            >
                <div
                    className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-all pointer-events-none ${isSelected ? 'bg-slate-800 dark:bg-slate-200 border-slate-800 dark:border-slate-200' : 'bg-transparent border-slate-300 dark:border-slate-500'}`}
                >
                    {isSelected && <CheckIcon className="w-3.5 h-3.5 text-white dark:text-slate-900" />}
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
                    text={description} 
                    onSave={(newDesc) => onUpdate(id, newDesc)} 
                    onEditingChange={setIsRenaming}
                />
            </div>
        </div>
    );
};


// Sub-component for a collapsible/editable Step Set Template
const TemplateSetItem: React.FC<{
    templateSet: StepSetTemplate;
    onUpdate: (updatedSet: StepSetTemplate) => void;
    onDragStartSet: (e: React.DragEvent) => void;
    onTouchStartSet: (e: React.TouchEvent) => void;
    isGhost: boolean;
    draggedStepIds: Set<string>;
    onSetDraggedIds: (ids: Set<string>) => void;
    isSelectionMode: boolean;
    isSelected: boolean;
    onItemClick: (e: React.MouseEvent | React.TouchEvent, id: string) => void;
    onItemLongPress: (id: string) => void;
    onItemPointerDown: (e: React.PointerEvent, itemType: 'current' | 'archive' | 'templateSet', id: string) => void;
    onContextMenu: (e: React.MouseEvent) => void;
}> = ({ templateSet, onUpdate, onDragStartSet, onTouchStartSet, isGhost, draggedStepIds, onSetDraggedIds, isSelectionMode, isSelected, onItemClick, onItemLongPress, onItemPointerDown, onContextMenu }) => {
    const [isExpanded, setIsExpanded] = useState(false);
    const [newStep, setNewStep] = useState('');
    const [dropIndex, setDropIndex] = useState<number | null>(null);
    const [isRenamingSet, setIsRenamingSet] = useState(false);
    const [editingInnerStepId, setEditingInnerStepId] = useState<string | null>(null);
    
    const handleBodyClick = (e: React.MouseEvent | React.TouchEvent) => {
        onItemClick(e, templateSet.id);
    };

    const longPressEvents = useLongPress(
        // FIX: The onLongPress callback for useLongPress expects an event argument.
        (e) => onItemLongPress(templateSet.id),
        handleBodyClick,
        {
            delay: 400,
            onDrag: isSelectionMode ? onTouchStartSet : undefined,
        }
    );

    const handleUpdateName = (newName: string) => {
        onUpdate({ ...templateSet, name: newName });
    };

    const handleUpdateStep = (stepId: string, newDesc: string) => {
        const newSteps = templateSet.steps.map(s => s.id === stepId ? { ...s, description: newDesc } : s);
        onUpdate({ ...templateSet, steps: newSteps });
    };

    const handleDeleteStep = (stepId: string) => {
        const newSteps = templateSet.steps.filter((s) => s.id !== stepId);
        onUpdate({ ...templateSet, steps: newSteps });
    };
    
    const handleAddStep = () => {
        if(newStep.trim()){
            const newStepObject: StepSetTemplateStep = { id: `set-step-${Date.now()}`, description: newStep.trim() };
            const newSteps = [...templateSet.steps, newStepObject];
            onUpdate({ ...templateSet, steps: newSteps });
            setNewStep('');
        }
    };
    
    const handleStepDragStart = (e: React.DragEvent, step: StepSetTemplateStep) => {
        const payload = {
            type: 'multi-source-drag',
            sources: {
                archive: [{ // Treat individual template steps as archived items
                    id: step.id,
                    description: step.description,
                }],
                steps: [],
                sets: [],
            },
            sourceSetId: templateSet.id, // for internal move checks
        };
        e.dataTransfer.setData('application/json', JSON.stringify(payload));
        e.dataTransfer.effectAllowed = 'copyMove';
        onSetDraggedIds(new Set([step.id]));
        e.stopPropagation();
    };

    const handleStepContainerDragOver = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();

        const container = e.currentTarget as HTMLDivElement;

        try {
            const payload = JSON.parse(e.dataTransfer.getData('application/json'));
            
            if (!payload.type || payload.type !== 'multi-source-drag') {
                 setDropIndex(null);
                 return;
            }

            const isInternalMove = payload.sourceSetId === templateSet.id;
            const draggedStepId = isInternalMove ? (payload.sources.archive?.[0]?.id ?? null) : null;

            const otherElements = Array.from(container.querySelectorAll('[data-reorder-step-id]'))
                .filter(el => !draggedStepId || (el as HTMLElement).dataset.reorderStepId !== draggedStepId) as HTMLElement[];

            if (otherElements.length === 0) {
                if (dropIndex !== 0) setDropIndex(0);
                return;
            }
            
            let afterElement: HTMLElement | null = null;
            
            for (const child of otherElements) {
                const box = child.getBoundingClientRect();
                const isSameRow = Math.abs(e.clientY - (box.top + box.height / 2)) < box.height / 2;
                
                if (e.clientY < box.top) {
                    afterElement = child;
                    break;
                }
                
                if (isSameRow && e.clientX < box.left + box.width / 2) {
                    afterElement = child;
                    break;
                }
            }

            const newIndex = afterElement
                ? templateSet.steps.findIndex(s => s.id === afterElement!.dataset.reorderStepId)
                : templateSet.steps.length;

            if (dropIndex !== newIndex) {
                setDropIndex(newIndex);
            }
        } catch {
            setDropIndex(null);
        }
    };
    
    const handleStepContainerDrop = (e: React.DragEvent) => {
        e.preventDefault();
        e.stopPropagation();
        
        if (dropIndex === null) return;
        
        try {
            const payload = JSON.parse(e.dataTransfer.getData('application/json'));
             if (payload.type !== 'multi-source-drag' || !payload.sources) return;

            const isInternalMove = payload.sourceSetId === templateSet.id;

            if (isInternalMove) {
                const stepId = payload.sources.archive[0].id;
                const dragIndex = templateSet.steps.findIndex(s => s.id === stepId);
                
                if (dragIndex === -1) return;
                
                let newSteps = [...templateSet.steps];
                const [movedItem] = newSteps.splice(dragIndex, 1);
                
                const adjustedDropIndex = dropIndex > dragIndex ? dropIndex - 1 : dropIndex;
                
                newSteps.splice(adjustedDropIndex, 0, movedItem);

                onUpdate({ ...templateSet, steps: newSteps });
            } else { // External drop
                const stepsToAdd = [
                    ...(payload.sources.steps || []),
                    ...(payload.sources.archive || [])
                ].map((item: any) => ({
                    id: `set-step-${Date.now()}-${Math.random()}`,
                    description: item.description,
                }));

                if (stepsToAdd.length > 0) {
                    const currentStepsList = [...templateSet.steps];
                    currentStepsList.splice(dropIndex, 0, ...stepsToAdd);
                    onUpdate({ ...templateSet, steps: currentStepsList });
                }
            }
        } catch (error) {
            console.error("Drop within set failed:", error);
        } finally {
            setDropIndex(null);
        }
    };

    return (
        <div 
            data-reorder-id={templateSet.id}
            data-item-type="templateSet"
            className={`bg-slate-100 dark:bg-slate-700 rounded-lg transition-all duration-150 ${isGhost ? 'opacity-30 pointer-events-none' : ''} ${isSelected ? 'ring-2 ring-slate-500 shadow-lg' : 'shadow-sm'}`}
        >
            <header 
                className={`flex items-center gap-2 p-2 rounded-t-lg`}
            >
                <div
                    onClick={handleBodyClick}
                    onPointerDown={(e) => {
                        e.stopPropagation();
                        onItemPointerDown(e, 'templateSet', templateSet.id);
                    }}
                    onMouseUp={e => e.stopPropagation()}
                    onTouchEnd={e => e.stopPropagation()}
                    onMouseDown={e => e.stopPropagation()}
                    onTouchStart={e => e.stopPropagation()}
                    onDragStart={e => { e.preventDefault(); e.stopPropagation(); }}
                    draggable={false}
                    className="flex-shrink-0 self-stretch flex items-center p-3 -m-1 cursor-pointer"
                    aria-label={`选择模板 ${templateSet.name}`}
                >
                    <div
                        className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-all pointer-events-none ${isSelected ? 'bg-slate-800 dark:bg-slate-200 border-slate-800 dark:border-slate-200' : 'bg-transparent border-slate-300 dark:border-slate-500'}`}
                    >
                        {isSelected && <CheckIcon className="w-3.5 h-3.5 text-white dark:text-slate-900" />}
                    </div>
                </div>

                <div
                    draggable={isSelectionMode && !isRenamingSet}
                    onDragStart={isSelectionMode ? onDragStartSet : undefined}
                    {...longPressEvents}
                    onContextMenu={onContextMenu}
                    className={`flex items-center flex-grow min-w-0 ${isSelectionMode && !isRenamingSet ? 'cursor-grab' : 'cursor-default'}`}
                >
                    <div className="flex-grow">
                        <InlineEdit 
                            text={templateSet.name} 
                            onSave={handleUpdateName} 
                            className="font-semibold" 
                            onEditingChange={setIsRenamingSet}
                        />
                    </div>
                    <button 
                        onClick={(e) => { e.stopPropagation(); setIsExpanded(!isExpanded); }}
                        onMouseDown={e => e.stopPropagation()}
                        onTouchStart={e => e.stopPropagation()}
                        className="p-2 rounded-full hover:bg-slate-200 dark:hover:bg-slate-600 active:scale-95 transition-all">
                        {isExpanded ? <ChevronUpIcon className="w-5 h-5" /> : <ChevronDownIcon className="w-5 h-5" />}
                    </button>
                </div>
            </header>
            {isExpanded && (
                <div 
                    className="p-3 border-t border-slate-200 dark:border-slate-600 space-y-2"
                    onDragOver={(e) => {e.preventDefault(); e.stopPropagation();}}
                >
                    <div 
                        className="flex flex-wrap gap-2"
                        onDragOver={handleStepContainerDragOver}
                        onDrop={handleStepContainerDrop}
                        onDragLeave={() => setDropIndex(null)}
                    >
                        {templateSet.steps.map((step, index) => (
                             <React.Fragment key={step.id}>
                                {dropIndex === index && <DropIndicator orientation="vertical" className="h-6" />}
                                <div 
                                    data-reorder-step-id={step.id}
                                    draggable={!isRenamingSet && editingInnerStepId !== step.id} 
                                    onDragStart={(e) => handleStepDragStart(e, step)}
                                    className={`inline-flex items-center gap-1.5 text-sm p-1.5 rounded-md bg-white dark:bg-slate-600 shadow-sm transition-opacity active:scale-95 ${draggedStepIds.has(step.id) ? 'opacity-30 pointer-events-none' : ''} ${!isRenamingSet && editingInnerStepId !== step.id ? 'cursor-grab' : 'cursor-default'}`}
                                >
                                    <InlineEdit 
                                        text={step.description} 
                                        onSave={(newDesc) => handleUpdateStep(step.id, newDesc)}
                                        onEditingChange={(isEditing) => setEditingInnerStepId(isEditing ? step.id : null)}
                                    />
                                    <button onClick={() => handleDeleteStep(step.id)} className="text-red-500/70 hover:text-red-500 p-1 rounded-full">
                                        <XIcon className="w-4 h-4" />
                                    </button>
                                </div>
                            </React.Fragment>
                        ))}
                        {dropIndex === templateSet.steps.length && <DropIndicator orientation="vertical" className="h-6" />}
                    </div>
                    {templateSet.steps.length === 0 && <p className="text-xs text-center text-slate-500">此模板为空。拖动步骤到此处。</p>}
                    <div className="flex gap-2 pt-2">
                         <input
                            type="text"
                            value={newStep}
                            onChange={(e) => setNewStep(e.target.value)}
                            onKeyDown={(e) => e.key === 'Enter' && handleAddStep()}
                            placeholder="添加步骤到模板..."
                            className="flex-grow px-2 py-1.5 text-sm bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-500 rounded-md"
                        />
                        <button onClick={handleAddStep} className="px-3 py-1.5 rounded-md bg-slate-800 dark:bg-slate-200 text-white dark:text-slate-900 text-sm font-semibold transition-transform active:scale-95">添加</button>
                    </div>
                </div>
            )}
        </div>
    );
};

const AddInput: React.FC<{
    placeholder: string;
    onAdd: (value: string) => void | boolean;
    buttonText?: string;
    buttonIcon?: React.ReactNode;
    buttonClassName?: string;
}> = ({ placeholder, onAdd, buttonText = '添加', buttonIcon = <PlusIcon className="w-5 h-5"/>, buttonClassName = 'bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900' }) => {
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
                className="flex-grow px-3 py-2.5 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg" />
            <button 
                onClick={handleAdd} 
                className={`px-4 py-2.5 rounded-lg font-semibold flex items-center justify-center gap-1 transition-transform active:scale-95 ${buttonClassName} hover:opacity-90`}
            >
                {buttonIcon} {buttonText}
            </button>
        </div>
    );
};

const SaveAsSetInput: React.FC<{
    onSave: (name: string) => boolean;
    currentStepCount: number;
}> = ({ onSave, currentStepCount }) => {
    const [value, setValue] = useState('');

    const handleSave = () => {
        const success = onSave(value);
        if (success) {
            setValue('');
        } else {
            alert("请输入模板名称并且确保当前事件有步骤。");
        }
    };
    
    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            handleSave();
        }
    };

    return (
        <div className="bg-slate-100 dark:bg-slate-700/50 p-3 rounded-lg flex-shrink-0">
            <label className="text-sm font-medium mb-1 block">将当前 {currentStepCount} 个步骤保存为新的工作流模板</label>
            <div className="flex flex-col sm:flex-row gap-2">
                <input 
                    type="text" 
                    value={value} 
                    onChange={(e) => setValue(e.target.value)} 
                    onKeyDown={handleKeyDown} 
                    placeholder="输入新模板名称..." 
                    className="flex-grow px-3 py-2.5 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg"/>
                <button 
                    onClick={handleSave} 
                    disabled={currentStepCount === 0} 
                    className="px-4 py-2.5 rounded-lg bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900 font-semibold flex items-center justify-center gap-1 hover:bg-slate-700 dark:hover:bg-slate-300 disabled:bg-slate-400 dark:disabled:bg-slate-700 dark:disabled:text-slate-400 disabled:cursor-not-allowed transition-transform active:scale-95"
                >
                    <SaveIcon className="w-5 h-5" /> 保存
                </button>
            </div>
        </div>
    );
};

const DropIndicator: React.FC<{className?: string, orientation?: 'vertical' | 'horizontal'}> = ({className, orientation = 'horizontal'}) => {
    if (orientation === 'vertical') {
        return <div className={`w-1 h-10 bg-slate-800 dark:bg-slate-300 rounded-full self-center ${className}`} />;
    }
    return <div className={`w-full h-1 bg-slate-800 dark:bg-slate-300 rounded-full my-1 ${className}`} />;
};

interface UnifiedActionsHeaderProps {
  selectedCurrentStepIds: Set<string>;
  selectedTemplateIds: Set<string>;
  selectedTemplateSetIds: Set<string>;
  onMoveToArchive: () => void;
  onSaveAsTemplate: () => void;
  onAddToSteps: () => void;
  onAddSetsToSteps: () => void;
  onMoveSetsToArchive: () => void;
  onDelete: () => void;
}

const UnifiedActionsHeader: React.FC<UnifiedActionsHeaderProps> = ({
  selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds,
  onMoveToArchive, onSaveAsTemplate, onAddToSteps, onAddSetsToSteps,
  onMoveSetsToArchive, onDelete,
}) => {
  const hasSteps = selectedCurrentStepIds.size > 0;
  const hasArchive = selectedTemplateIds.size > 0;
  const hasSets = selectedTemplateSetIds.size > 0;
  const totalSelected = selectedCurrentStepIds.size + selectedTemplateIds.size + selectedTemplateSetIds.size;

  const selectionText = useMemo(() => {
    const parts: string[] = [];
    const stepCount = selectedCurrentStepIds.size;
    const archiveCount = selectedTemplateIds.size;
    const setCount = selectedTemplateSetIds.size;

    if (stepCount > 0) {
        parts.push(`${stepCount} 个步骤`);
    }
    if (archiveCount > 0) {
        parts.push(`${archiveCount} 个归档项`);
    }
    if (setCount > 0) {
        parts.push(`${setCount} 个模板`);
    }
    return parts.join(', ');
  }, [selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds]);

  const baseButtonClass = "text-sm font-semibold px-4 py-2 hover:bg-slate-100 dark:hover:bg-slate-600 transition-colors active:scale-95 flex items-center gap-2 border-y border-slate-300 dark:border-slate-600";

  // Determine which buttons are valid for the current selection mix
  const showAddToSteps = (hasArchive || hasSets);
  const showMoveToArchive = hasSteps;
  const showSaveAsTemplate = (hasSteps || hasArchive) && !hasSets;
  const showMoveSetsToArchive = hasSets && !hasSteps && !hasArchive;
  const showDelete = totalSelected > 0;

  return (
    <div className="flex justify-between items-center w-full animate-fade-in-up">
      <h3 className="font-bold text-lg text-slate-800 dark:text-slate-100 flex-shrink-0 truncate">已选中: {selectionText}</h3>
      <div className="inline-flex rounded-lg shadow-sm" role="group">
        {showAddToSteps && (
          <button onClick={hasArchive ? onAddToSteps : onAddSetsToSteps} className={`${baseButtonClass} text-slate-700 dark:text-slate-200 bg-slate-50 dark:bg-slate-700 border-l rounded-l-lg`}>
            <ChevronLeftIcon className="w-4 h-4" /> 步骤
          </button>
        )}
        {showMoveToArchive && (
          <button onClick={onMoveToArchive} className={`${baseButtonClass} text-slate-700 dark:text-slate-200 bg-slate-50 dark:bg-slate-700 ${!showAddToSteps ? 'border-l rounded-l-lg' : '-ml-px'}`}>
            <ChevronRightIcon className="w-4 h-4" /> 归档
          </button>
        )}
         {showMoveSetsToArchive && (
          <button onClick={onMoveSetsToArchive} className={`${baseButtonClass} text-slate-700 dark:text-slate-200 bg-slate-50 dark:bg-slate-700 ${!showAddToSteps ? 'border-l rounded-l-lg' : '-ml-px'}`}>
            <ArrowUpTrayIcon className="w-4 h-4" /> 归档
          </button>
        )}
        {showSaveAsTemplate && (
          <button onClick={onSaveAsTemplate} className={`${baseButtonClass} text-slate-700 dark:text-slate-200 bg-slate-50 dark:bg-slate-700 ${!showAddToSteps && !showMoveToArchive && !showMoveSetsToArchive ? 'border-l rounded-l-lg' : '-ml-px'}`}>
            <SaveIcon className="w-5 h-5" /> 模板
          </button>
        )}
        {showDelete && (
          <button onClick={onDelete} className={`${baseButtonClass} text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/50 hover:bg-red-100 dark:hover:bg-red-900/80 border-r rounded-r-lg ${!showAddToSteps && !showMoveToArchive && !showMoveSetsToArchive && !showSaveAsTemplate ? 'border-l rounded-l-lg' : '-ml-px'}`}>
            <TrashIcon className="w-4 h-4" /> 删除
          </button>
        )}
      </div>
    </div>
  );
};

interface StepsEditorPanelProps {
  isOpen: boolean;
  onClose: () => void;
  event: Event | null;
  templates: StepTemplate[];
  stepSetTemplates: StepSetTemplate[];
  onStepsChange: (eventId: string, newSteps: ProgressStep[]) => void;
  onTemplatesChange: (newTemplates: StepTemplate[]) => void;
  onStepSetTemplatesChange: (newTemplates: StepSetTemplate[]) => void;
}

const StepsEditorPanel: React.FC<StepsEditorPanelProps> = ({ 
    isOpen, onClose, event, templates, stepSetTemplates, 
    onStepsChange, onTemplatesChange, onStepSetTemplatesChange
}) => {
  const prevEventIdRef = useRef<string | null>(null);
  const [activeEvent, setActiveEvent] = useState<Event | null>(null);
  const windowWidth = useWindowWidth();
  const isMobileView = windowWidth < 1024;
  
  const clearAllSelections = () => {
    setSelectedCurrentStepIds(new Set());
    setLastSelectedCurrentStepId(null);
    setSelectedTemplateIds(new Set());
    setLastSelectedTemplateId(null);
    setSelectedTemplateSetIds(new Set());
    setLastSelectedTemplateSetId(null);
  };
  
  const handleClose = () => {
    clearAllSelections();
    prevEventIdRef.current = null; // Also clear this on explicit close
    onClose();
  };

  const [currentSteps, setCurrentSteps] = useState<ProgressStep[]>([]);
  const [draggedIds, setDraggedIds] = useState<Set<string>>(new Set());
  
  const [selectedCurrentStepIds, setSelectedCurrentStepIds] = useState<Set<string>>(new Set());
  const [lastSelectedCurrentStepId, setLastSelectedCurrentStepId] = useState<string | null>(null);

  const [selectedTemplateIds, setSelectedTemplateIds] = useState<Set<string>>(new Set());
  const [lastSelectedTemplateId, setLastSelectedTemplateId] = useState<string | null>(null);
  
  const [selectedTemplateSetIds, setSelectedTemplateSetIds] = useState<Set<string>>(new Set());
  const [lastSelectedTemplateSetId, setLastSelectedTemplateSetId] = useState<string | null>(null);

  const [snackbar, setSnackbar] = useState<{ id: number; message: string; icon?: React.ReactNode } | null>(null);

  const showSnackbar = (message: string, icon?: React.ReactNode) => {
    const id = Date.now();
    setSnackbar({ id, message, icon });
    setTimeout(() => {
        setSnackbar(prev => (prev?.id === id ? null : prev));
    }, 3000);
  };

  const isSelectionMode = useMemo(() => 
    selectedCurrentStepIds.size > 0 || 
    selectedTemplateIds.size > 0 || 
    selectedTemplateSetIds.size > 0,
    [selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds]
  );

  const [contextMenu, setContextMenu] = useState<{ x: number; y: number; type: 'current' | 'template' | 'templateSet'; ids: Set<string> } | null>(null);
  
  const [showClearArchiveConfirm, setShowClearArchiveConfirm] = useState(false);
  const [showClearStepsConfirm, setShowClearStepsConfirm] = useState(false);
  const [newTemplateModalData, setNewTemplateModalData] = useState<{ items: { description: string }[] } | null>(null);
  const [newTemplateName, setNewTemplateName] = useState('');

  const [dropIndicator, setDropIndicator] = useState<{ panel: 'current' | 'archive' | 'templateSet'; index: number } | null>(null);
  const [touchDragState, setTouchDragState] = useState<{
    payload: any | null;
    ghostElement: React.ReactNode | null;
    position: { x: number; y: number };
    offset: { x: number; y: number };
  } | null>(null);

    // Refs for swipe-to-select functionality
    const isSwipingRef = useRef(false);
    const swipeTargetStateRef = useRef(false); // true for select, false for deselect
    const swipedThisActionRef = useRef(false);
    const swipeStartCoords = useRef<{ x: number, y: number } | null>(null);
    const SWIPE_THRESHOLD = 5;

  const currentStepsPanelRef = useRef<HTMLDivElement>(null);
  const archivePanelRef = useRef<HTMLDivElement>(null);
  const templateSetPanelRef = useRef<HTMLDivElement>(null);

  const touchStartRef = useRef<{ x: number; y: number } | null>(null);
  const [activePanelIndex, setActivePanelIndex] = useState(0); // 0: Steps, 1: Archive, 2: Templates
  const panelTitles = useMemo(() => ['步骤', '归档', '模板'], []);
  
  useEffect(() => {
    if (isOpen && event) {
      setActiveEvent(event);
    }
  }, [isOpen, event]);

  useEffect(() => {
    if (activeEvent) {
      // If the panel is opened for a new event, reset all state.
      // Otherwise, if it's the same event, only update the current steps list
      // to reflect changes, but preserve selections.
      if (activeEvent.id !== prevEventIdRef.current) {
        setCurrentSteps(activeEvent.steps.slice().sort((a,b) => a.timestamp.getTime() - b.timestamp.getTime()));
        clearAllSelections();
        setActivePanelIndex(0);
      } else {
        setCurrentSteps(activeEvent.steps.slice().sort((a,b) => a.timestamp.getTime() - b.timestamp.getTime()));
      }
      prevEventIdRef.current = activeEvent.id;
    }
  }, [activeEvent]);

  const handleExited = () => {
    setActiveEvent(null);
    prevEventIdRef.current = null; // Also clear the ref
  };
  
    const updateSelection = useCallback((itemType: string, itemId: string, select: boolean) => {
        const updater = (prev: Set<string>) => {
            const next = new Set(prev);
            if (select) next.add(itemId);
            else next.delete(itemId);
            return next;
        };
        if (itemType === 'current') setSelectedCurrentStepIds(updater);
        else if (itemType === 'archive') setSelectedTemplateIds(updater);
        else if (itemType === 'templateSet') setSelectedTemplateSetIds(updater);
    }, []);

    const handlePointerMove = useCallback((e: PointerEvent) => {
        if (!isSwipingRef.current || !swipeStartCoords.current) return;

        if (!swipedThisActionRef.current) {
            const dx = Math.abs(e.clientX - swipeStartCoords.current.x);
            const dy = Math.abs(e.clientY - swipeStartCoords.current.y);
            if (dx > SWIPE_THRESHOLD || dy > SWIPE_THRESHOLD) {
                swipedThisActionRef.current = true;
            }
        }
        
        if (swipedThisActionRef.current) {
            const element = document.elementFromPoint(e.clientX, e.clientY);
            const itemElement = element?.closest<HTMLElement>('[data-reorder-id]');

            if (itemElement) {
                const itemId = itemElement.dataset.reorderId;
                const itemType = itemElement.dataset.itemType;
                if (itemId && itemType) {
                    updateSelection(itemType, itemId, swipeTargetStateRef.current);
                }
            }
        }
    }, [updateSelection]);

    const handlePointerUp = useCallback((e: PointerEvent) => {
        if (!isSwipingRef.current) return;
        isSwipingRef.current = false;
        swipeStartCoords.current = null;
        
        window.removeEventListener('pointermove', handlePointerMove);
        window.removeEventListener('pointerup', handlePointerUp);
        document.body.style.userSelect = '';
    }, [handlePointerMove]);

    const handleItemPointerDown = useCallback((e: React.PointerEvent, itemType: 'current' | 'archive' | 'templateSet', itemId: string) => {
        (e.target as HTMLElement).setPointerCapture(e.pointerId);

        isSwipingRef.current = true;
        swipedThisActionRef.current = false;
        swipeStartCoords.current = { x: e.clientX, y: e.clientY };

        let isInitiallySelected = false;
        if (itemType === 'current') isInitiallySelected = selectedCurrentStepIds.has(itemId);
        else if (itemType === 'archive') isInitiallySelected = selectedTemplateIds.has(itemId);
        else if (itemType === 'templateSet') isInitiallySelected = selectedTemplateSetIds.has(itemId);
        
        // Don't toggle selection immediately. This allows a clean 'click' to be determined on pointer up.
        const targetState = !isInitiallySelected;
        swipeTargetStateRef.current = targetState;

        window.addEventListener('pointermove', handlePointerMove);
        window.addEventListener('pointerup', handlePointerUp);
        document.body.style.userSelect = 'none';
    }, [selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds, handlePointerMove, handlePointerUp]);


  const handleDragEnd = () => {
      setDraggedIds(new Set());
      setDropIndicator(null);
  };

  const handleCurrentStepsChange = useCallback((newSteps: ProgressStep[]) => {
    if (!activeEvent) return;
    const now = Date.now();
    const orderedSteps = newSteps.map((step, index) => ({
      ...step,
      timestamp: new Date(now + index),
    }));
    setCurrentSteps(orderedSteps);
    onStepsChange(activeEvent.id, orderedSteps);
  }, [activeEvent, onStepsChange]);

  const addStepToCurrent = (desc: string) => {
    const newStep: ProgressStep = { id: `step-${Date.now()}`, description: desc, timestamp: new Date(), completed: false };
    handleCurrentStepsChange([...currentSteps, newStep]);
    showSnackbar(`已添加步骤: "${desc.substring(0, 20)}..."`, <PlusIcon className="w-5 h-5" />);
  };
  const updateCurrentStep = (id: string, newDesc: string) => {
    const newSteps = currentSteps.map(s => s.id === id ? { ...s, description: newDesc } : s);
    handleCurrentStepsChange(newSteps);
  };
  
  const addSingleTemplate = (desc: string) => {
    if(desc.trim() && !templates.some(t => t.description === desc.trim())) {
      const newTemplate: StepTemplate = { id: `template-${Date.now()}`, description: desc.trim() };
      onTemplatesChange([...templates, newTemplate]);
      showSnackbar(`已添加归档项: "${desc.trim().substring(0, 20)}..."`, <ArchiveBoxIcon className="w-5 h-5" />);
      return true;
    }
    return false;
  };
  const updateSingleTemplate = (id: string, newDesc: string) => {
    onTemplatesChange(templates.map(t => t.id === id ? { ...t, description: newDesc } : t));
  };
  
  const handleClearSingleTemplates = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (templates.length > 0) setShowClearArchiveConfirm(true);
  };

  const confirmClearSingleTemplates = () => {
    const count = templates.length;
    onTemplatesChange([]);
    setSelectedTemplateIds(new Set());
    setLastSelectedTemplateId(null);
    setShowClearArchiveConfirm(false);
    if (count > 0) showSnackbar(`已重置 ${count} 个归档项`, <TrashIcon className="w-5 h-5" />);
  };
  
  const handleClearCurrentSteps = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (currentSteps.length > 0) setShowClearStepsConfirm(true);
  };

  const confirmClearCurrentSteps = () => {
    const count = currentSteps.length;
    handleCurrentStepsChange([]);
    setSelectedCurrentStepIds(new Set());
    setLastSelectedCurrentStepId(null);
    setShowClearStepsConfirm(false);
    if (count > 0) showSnackbar(`已重置 ${count} 个步骤`, <TrashIcon className="w-5 h-5" />);
  };

  const handleCurrentStepInteraction = (e: React.MouseEvent | React.TouchEvent, clickedId: string) => {
    e.stopPropagation();
    if (swipedThisActionRef.current) {
        swipedThisActionRef.current = false;
        return;
    }
    const allIds = currentSteps.map(s => s.id);
    
    if ('shiftKey' in e && e.shiftKey && lastSelectedCurrentStepId) {
        const lastIndex = allIds.indexOf(lastSelectedCurrentStepId);
        const currentIndex = allIds.indexOf(clickedId);
        const start = Math.min(lastIndex, currentIndex);
        const end = Math.max(lastIndex, currentIndex);
        if (start !== -1 && end !== -1) {
            const rangeSelection = new Set(allIds.slice(start, end + 1));
            setSelectedCurrentStepIds(rangeSelection);
        }
        setLastSelectedCurrentStepId(clickedId);
        return;
    }

    const newSelection = new Set(selectedCurrentStepIds);
    newSelection.has(clickedId) ? newSelection.delete(clickedId) : newSelection.add(clickedId);
    setSelectedCurrentStepIds(newSelection);
    setLastSelectedCurrentStepId(clickedId);
  };

  const handleTemplateInteraction = (e: React.MouseEvent | React.TouchEvent, clickedId: string) => {
    e.stopPropagation();
     if (swipedThisActionRef.current) {
        swipedThisActionRef.current = false;
        return;
    }
    const allIds = templates.map(t => t.id);

    if ('shiftKey' in e && e.shiftKey && lastSelectedTemplateId) {
        const lastIndex = allIds.indexOf(lastSelectedTemplateId);
        const currentIndex = allIds.indexOf(clickedId);
        const start = Math.min(lastIndex, currentIndex);
        const end = Math.max(lastIndex, currentIndex);
        if (start !== -1 && end !== -1) {
            const rangeSelection = new Set(allIds.slice(start, end + 1));
            setSelectedTemplateIds(rangeSelection);
        }
        setLastSelectedTemplateId(clickedId);
        return;
    }
    
    const newSelection = new Set(selectedTemplateIds);
    newSelection.has(clickedId) ? newSelection.delete(clickedId) : newSelection.add(clickedId);
    setSelectedTemplateIds(newSelection);
    setLastSelectedTemplateId(clickedId);
  };

    const handleTemplateSetInteraction = (e: React.MouseEvent | React.TouchEvent, clickedId: string) => {
        e.stopPropagation();
        if (swipedThisActionRef.current) {
            swipedThisActionRef.current = false;
            return;
        }
        const allIds = stepSetTemplates.map(s => s.id);
        
        if ('shiftKey' in e && e.shiftKey && lastSelectedTemplateSetId) {
            const lastIndex = allIds.indexOf(lastSelectedTemplateSetId);
            const currentIndex = allIds.indexOf(clickedId);
            const start = Math.min(lastIndex, currentIndex);
            const end = Math.max(lastIndex, currentIndex);
            if (start !== -1 && end !== -1) {
                const rangeSelection = new Set(allIds.slice(start, end + 1));
                setSelectedTemplateSetIds(rangeSelection);
            }
            setLastSelectedTemplateSetId(clickedId);
            return;
        }

        const newSelection = new Set(selectedTemplateSetIds);
        newSelection.has(clickedId) ? newSelection.delete(clickedId) : newSelection.add(clickedId);
        setSelectedTemplateSetIds(newSelection);
        setLastSelectedTemplateSetId(clickedId);
    };

  const handleCurrentStepLongPress = (id: string) => {
      const newSelection = new Set(selectedCurrentStepIds);
      newSelection.add(id);
      setSelectedCurrentStepIds(newSelection);
      setLastSelectedCurrentStepId(id);
  };

  const handleTemplateLongPress = (id: string) => {
      const newSelection = new Set(selectedTemplateIds);
      newSelection.add(id);
      setSelectedTemplateIds(newSelection);
      setLastSelectedTemplateId(id);
  };

    const handleTemplateSetLongPress = (id: string) => {
        const newSelection = new Set(selectedTemplateSetIds);
        newSelection.add(id);
        setSelectedTemplateSetIds(newSelection);
        setLastSelectedTemplateSetId(id);
    };

  const handleCloseContextMenu = () => setContextMenu(null);

  const handleCurrentStepContextMenu = (e: React.MouseEvent, rightClickedId: string) => {
    e.preventDefault();
    e.stopPropagation();
    let selection = new Set(selectedCurrentStepIds);
    if (!selection.has(rightClickedId)) {
        selection = new Set([rightClickedId]);
        setSelectedCurrentStepIds(selection);
        setLastSelectedCurrentStepId(rightClickedId);
    }
    if (selection.size > 0) setContextMenu({ x: e.clientX, y: e.clientY, type: 'current', ids: selection });
  };

  const handleTemplateContextMenu = (e: React.MouseEvent, rightClickedId: string) => {
    e.preventDefault();
    e.stopPropagation();
    let selection = new Set(selectedTemplateIds);
    if (!selection.has(rightClickedId)) {
        selection = new Set([rightClickedId]);
        setSelectedTemplateIds(selection);
        setLastSelectedTemplateId(rightClickedId);
    }
    if (selection.size > 0) setContextMenu({ x: e.clientX, y: e.clientY, type: 'template', ids: selection });
  };

    const handleTemplateSetContextMenu = (e: React.MouseEvent, rightClickedId: string) => {
        e.preventDefault();
        e.stopPropagation();
        let selection = new Set(selectedTemplateSetIds);
        if (!selection.has(rightClickedId)) {
            selection = new Set([rightClickedId]);
            setSelectedTemplateSetIds(selection);
            setLastSelectedTemplateSetId(rightClickedId);
        }
        if (selection.size > 0) setContextMenu({ x: e.clientX, y: e.clientY, type: 'templateSet', ids: selection });
    };

  const deleteSelectedCurrentSteps = useCallback(() => {
    const idsToDelete = contextMenu ? contextMenu.ids : selectedCurrentStepIds;
    if (idsToDelete.size === 0) return;
    const newSteps = currentSteps.filter(step => !idsToDelete.has(step.id));
    handleCurrentStepsChange(newSteps);
    setSelectedCurrentStepIds(new Set());
    handleCloseContextMenu();
  }, [contextMenu, selectedCurrentStepIds, currentSteps, handleCurrentStepsChange]);

  const deleteSelectedTemplates = useCallback(() => {
    const idsToDelete = contextMenu ? contextMenu.ids : selectedTemplateIds;
    if (idsToDelete.size === 0) return;
    onTemplatesChange(templates.filter(t => !idsToDelete.has(t.id)));
    setSelectedTemplateIds(new Set());
    handleCloseContextMenu();
  }, [contextMenu, selectedTemplateIds, templates, onTemplatesChange]);
  
    const deleteSelectedTemplateSets = useCallback(() => {
        const idsToDelete = contextMenu ? contextMenu.ids : selectedTemplateSetIds;
        if (idsToDelete.size === 0) return;
        onStepSetTemplatesChange(stepSetTemplates.filter(t => !idsToDelete.has(t.id)));
        setSelectedTemplateSetIds(new Set());
        handleCloseContextMenu();
    }, [contextMenu, selectedTemplateSetIds, stepSetTemplates, onStepSetTemplatesChange]);

  const contextMenuActions = useMemo<ContextMenuAction[]>(() => {
    if (!contextMenu) return [];
    const count = contextMenu.ids.size;
    if (count === 0) return [];
    
    switch (contextMenu.type) {
        case 'current':
            return [{ label: `删除 ${count} 个步骤`, icon: <TrashIcon className="w-5 h-5" />, isDestructive: true, onClick: deleteSelectedCurrentSteps }];
        case 'template':
            return [{ label: `删除 ${count} 个归档步骤`, icon: <TrashIcon className="w-5 h-5" />, isDestructive: true, onClick: deleteSelectedTemplates }];
        case 'templateSet':
            return [{ label: `删除 ${count} 个模板`, icon: <TrashIcon className="w-5 h-5" />, isDestructive: true, onClick: deleteSelectedTemplateSets }];
        default: return [];
    }
  }, [contextMenu, deleteSelectedCurrentSteps, deleteSelectedTemplates, deleteSelectedTemplateSets]);

  const handleGenericDragStart = useCallback((e: React.DragEvent, itemType: 'current' | 'archive' | 'templateSet', itemId: string) => {
    let currentSelection = selectedCurrentStepIds;
    let archiveSelection = selectedTemplateIds;
    let setSelection = selectedTemplateSetIds;

    // If the dragged item is not part of the current selection, create a new selection with just this item.
    if ( (itemType === 'current' && !currentSelection.has(itemId)) ||
         (itemType === 'archive' && !archiveSelection.has(itemId)) ||
         (itemType === 'templateSet' && !setSelection.has(itemId)) ) {
      currentSelection = itemType === 'current' ? new Set([itemId]) : new Set();
      archiveSelection = itemType === 'archive' ? new Set([itemId]) : new Set();
      setSelection = itemType === 'templateSet' ? new Set([itemId]) : new Set();
      setSelectedCurrentStepIds(currentSelection);
      setSelectedTemplateIds(archiveSelection);
      setSelectedTemplateSetIds(setSelection);
    }

    const draggedSteps = currentSteps.filter(s => currentSelection.has(s.id));
    const draggedArchive = templates.filter(t => archiveSelection.has(t.id));
    const draggedSets = stepSetTemplates.filter(s => setSelection.has(s.id));

    const payload = {
      type: 'multi-source-drag',
      sources: {
        steps: draggedSteps.map(s => ({ id: s.id, description: s.description })),
        archive: draggedArchive.map(t => ({ id: t.id, description: t.description })),
        sets: draggedSets.map(s => ({ id: s.id, name: s.name, steps: s.steps })),
      },
    };

    e.dataTransfer.setData('application/json', JSON.stringify(payload));
    e.dataTransfer.effectAllowed = 'copyMove';

    const allDraggedIds = new Set([...currentSelection, ...archiveSelection, ...setSelection]);
    setDraggedIds(allDraggedIds);
  }, [currentSteps, templates, stepSetTemplates, selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds]);
  
  const getClosestIndicatorIndex = (container: HTMLElement, clientY: number, clientX: number, draggedIds: Set<string>) => {
    const originalElements = Array.from(container.querySelectorAll('[data-reorder-id]')) as HTMLElement[];
    const draggableElements = originalElements.filter(el => !draggedIds.has(el.dataset.reorderId || ''));

    if (draggableElements.length === 0) return 0;

    let closest = { offset: Number.NEGATIVE_INFINITY, index: -1 };

    draggableElements.forEach((child) => {
        const box = child.getBoundingClientRect();
        const offset = clientY - (box.top + box.height / 2);
        if (offset < 0 && offset > closest.offset) {
            closest = { offset, index: originalElements.indexOf(child) };
        }
    });

    if (closest.index !== -1) return closest.index;

    const lastEl = draggableElements[draggableElements.length - 1];
    const box = lastEl.getBoundingClientRect();
    if (clientY > box.bottom) return originalElements.length;
    
    return originalElements.indexOf(lastEl) + 1;
  };
  
  const updateDropIndicator = useCallback((clientX: number, clientY: number, data: string) => {
    const el = document.elementFromPoint(clientX, clientY);
    if (!el) {
        setDropIndicator(null);
        return;
    }

    const currentPanel = currentStepsPanelRef.current;
    const archivePanel = archivePanelRef.current;
    const templatePanel = templateSetPanelRef.current;
    
    let payload;
    try { payload = JSON.parse(data); } catch { return; }
    if (!payload || !payload.sources) return;

    const allDraggedIds = new Set([
        ...payload.sources.steps.map((s: any) => s.id),
        ...payload.sources.archive.map((a: any) => a.id),
        ...payload.sources.sets.map((s: any) => s.id),
    ]);
    
    if (isMobileView) {
        const panelMap: Array<'current' | 'archive' | 'templateSet'> = ['current', 'archive', 'templateSet'];
        const activePanelName = panelMap[activePanelIndex];
        let activePanelNode: HTMLDivElement | null = null;
        if (activePanelIndex === 0) activePanelNode = currentPanel;
        else if (activePanelIndex === 1) activePanelNode = archivePanel;
        else if (activePanelIndex === 2) activePanelNode = templatePanel;

        if (activePanelNode && activePanelNode.contains(el)) {
            if (activePanelName === 'templateSet' && payload.sources.sets.length === 0) {
                setDropIndicator(null);
                return;
            }
            const index = getClosestIndicatorIndex(activePanelNode, clientY, clientX, allDraggedIds);
            setDropIndicator({ panel: activePanelName, index });
        } else {
            setDropIndicator(null);
        }
        return;
    }

    if(currentPanel?.contains(el)) {
        const index = getClosestIndicatorIndex(currentPanel, clientY, clientX, allDraggedIds);
        setDropIndicator({ panel: 'current', index });
    } else if (archivePanel?.contains(el)) {
        const index = getClosestIndicatorIndex(archivePanel, clientY, clientX, allDraggedIds);
        setDropIndicator({ panel: 'archive', index });
    } else if (templatePanel?.contains(el)) {
        if(payload.sources.sets.length > 0) {
            const index = getClosestIndicatorIndex(templatePanel, clientY, clientX, allDraggedIds);
            setDropIndicator({ panel: 'templateSet', index });
        } else {
            setDropIndicator(null);
        }
    } else {
        setDropIndicator(null);
    }
  }, [isMobileView, activePanelIndex]);
  
  const handlePanelDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    updateDropIndicator(e.clientX, e.clientY, e.dataTransfer.getData('application/json'));
  };

  const commitDrop = useCallback((payload: any, panel: 'current' | 'archive' | 'templateSet', dropIndex: number) => {
    if (payload.type !== 'multi-source-drag' || !payload.sources) return;
    
    const { steps: sourceSteps, archive: sourceArchive, sets: sourceSets } = payload.sources;
    
    const sourceStepIds = new Set(sourceSteps.map((s: any) => s.id));
    const sourceArchiveIds = new Set(sourceArchive.map((a: any) => a.id));
    const sourceSetIds = new Set(sourceSets.map((s: any) => s.id));

    let nextCurrentSteps = [...currentSteps];
    let nextTemplates = [...templates];
    let nextStepSetTemplates = [...stepSetTemplates];
    
    if (panel === 'current') {
        const stepsFromReorder = nextCurrentSteps.filter(s => sourceStepIds.has(s.id));
        const stepsFromArchive = sourceArchive.map((item: any) => ({ id: `step-${Date.now()}-${Math.random()}`, description: item.description, timestamp: new Date(), completed: false }));
        const stepsFromSets = sourceSets.flatMap((set: any) => set.steps.map((step: any) => ({ id: `step-${Date.now()}-${Math.random()}`, description: step.description, timestamp: new Date(), completed: false })));

        const allNewItems = [...stepsFromReorder, ...stepsFromArchive, ...stepsFromSets];
        
        let remainingSteps = nextCurrentSteps.filter(s => !sourceStepIds.has(s.id));
        
        let adjustedDropIndex = dropIndex;
        const originalItemsBeforeDrop = nextCurrentSteps.slice(0, dropIndex);
        const numDraggedBeforeDrop = originalItemsBeforeDrop.filter(item => sourceStepIds.has(item.id)).length;
        adjustedDropIndex -= numDraggedBeforeDrop;

        remainingSteps.splice(adjustedDropIndex, 0, ...allNewItems);
        handleCurrentStepsChange(remainingSteps);

    } else if (panel === 'archive') {
        const templatesFromSteps = sourceSteps.map((item: any) => ({ id: `template-${Date.now()}-${Math.random()}`, description: item.description }));
        const templatesFromReorder = nextTemplates.filter(t => sourceArchiveIds.has(t.id));
        const templatesFromSets = sourceSets.flatMap((set: any) => set.steps.map((step: any) => ({ id: `template-${Date.now()}-${Math.random()}`, description: step.description })));

        const allPotentialNewItems = [...templatesFromSteps, ...templatesFromSets];
        let remainingTemplates = nextTemplates.filter(t => !sourceArchiveIds.has(t.id));
        
        const existingDescriptions = new Set(remainingTemplates.map(t => t.description));
        const uniqueNewItems = allPotentialNewItems.filter(item => !existingDescriptions.has(item.description));
        
        const allItemsToInsert = [...templatesFromReorder, ...uniqueNewItems];

        let adjustedDropIndex = dropIndex;
        const originalItemsBeforeDrop = nextTemplates.slice(0, dropIndex);
        const numDraggedBeforeDrop = originalItemsBeforeDrop.filter(item => sourceArchiveIds.has(item.id)).length;
        adjustedDropIndex -= numDraggedBeforeDrop;

        remainingTemplates.splice(adjustedDropIndex, 0, ...allItemsToInsert);
        onTemplatesChange(remainingTemplates);

        if (sourceSteps.length > 0) {
            handleCurrentStepsChange(currentSteps.filter(s => !sourceStepIds.has(s.id)));
        }

    } else if (panel === 'templateSet') {
        if (sourceSets.length === 0) return;

        const setsToReorder = nextStepSetTemplates.filter(s => sourceSetIds.has(s.id));
        let remainingSets = nextStepSetTemplates.filter(s => !sourceSetIds.has(s.id));
        
        let adjustedDropIndex = dropIndex;
        const originalItemsBeforeDrop = nextStepSetTemplates.slice(0, dropIndex);
        const numDraggedBeforeDrop = originalItemsBeforeDrop.filter(item => sourceSetIds.has(item.id)).length;
        adjustedDropIndex -= numDraggedBeforeDrop;

        remainingSets.splice(adjustedDropIndex, 0, ...setsToReorder);
        onStepSetTemplatesChange(remainingSets);
    }
    
    setSelectedCurrentStepIds(new Set());
    setSelectedTemplateIds(new Set());
    setSelectedTemplateSetIds(new Set());

  }, [currentSteps, templates, stepSetTemplates, handleCurrentStepsChange, onTemplatesChange, onStepSetTemplatesChange]);

  const handleDrop = (e: React.DragEvent, panel: 'current' | 'archive' | 'templateSet') => {
    e.preventDefault();
    e.stopPropagation();
    
    if (dropIndicator === null) return;
    const dropIndex = dropIndicator.index;
    
    try {
        const payload = JSON.parse(e.dataTransfer.getData('application/json'));
        commitDrop(payload, panel, dropIndex);
    } catch (error) {
        console.error("Drop failed:", error);
    } finally {
        setDropIndicator(null);
    }
  };

  const handleDropOnTemplatePanel = (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      try {
          const payload = JSON.parse(e.dataTransfer.getData('application/json'));
          if (payload.type !== 'multi-source-drag' || !payload.sources) return;
          
          if (payload.sources.sets?.length > 0 && !payload.sources.steps?.length && !payload.sources.archive?.length) {
              handleDrop(e, 'templateSet');
          } else {
              const itemsToTemplate = [...(payload.sources.steps || []), ...(payload.sources.archive || [])];
              if (itemsToTemplate.length > 0) {
                setNewTemplateName(`新模板 ${new Date().toLocaleTimeString()}`);
                setNewTemplateModalData({ items: itemsToTemplate });
              }
          }
      } catch (error) {
          console.error("Failed to create template from drop:", error);
      }
  };

  const handleCreateTemplateFromModal = () => {
      if (newTemplateName.trim() && newTemplateModalData) {
          const newSet: StepSetTemplate = {
              id: `set-${Date.now()}`,
              name: newTemplateName.trim(),
              steps: newTemplateModalData.items.map((item) => ({
                  id: `set-step-${Date.now()}-${Math.random()}`,
                  description: item.description
              }))
          };
          onStepSetTemplatesChange([...stepSetTemplates, newSet]);
          setNewTemplateModalData(null);
          setNewTemplateName('');
          showSnackbar(`已创建模板 "${newSet.name}"`, <CheckIcon className="w-5 h-5" />);
      }
  };
  
    const updateStepSetTemplate = (updatedSet: StepSetTemplate) => {
        onStepSetTemplatesChange(stepSetTemplates.map(s => s.id === updatedSet.id ? updatedSet : s));
    };

    const saveCurrentAsSet = (name: string) => {
        if(name.trim() && currentSteps.length > 0) {
            const newSet: StepSetTemplate = { 
                id: `set-${Date.now()}`, 
                name: name.trim(), 
                steps: currentSteps.map(s => ({ 
                    id: `set-step-${Date.now()}-${Math.random()}`, 
                    description: s.description 
                })) 
            };
            onStepSetTemplatesChange([...stepSetTemplates, newSet]);
            showSnackbar(`已创建模板 "${newSet.name}"`, <CheckIcon className="w-5 h-5" />);
            return true;
        }
        return false;
    };

    const startTouchDrag = useCallback((e: React.TouchEvent, itemType: 'current' | 'archive' | 'templateSet', itemId: string) => {
        e.preventDefault();
        
        let currentSelection = selectedCurrentStepIds;
        let archiveSelection = selectedTemplateIds;
        let setSelection = selectedTemplateSetIds;

        if ( (itemType === 'current' && !currentSelection.has(itemId)) ||
             (itemType === 'archive' && !archiveSelection.has(itemId)) ||
             (itemType === 'templateSet' && !setSelection.has(itemId)) ) {
            currentSelection = itemType === 'current' ? new Set([itemId]) : new Set();
            archiveSelection = itemType === 'archive' ? new Set([itemId]) : new Set();
            setSelection = itemType === 'templateSet' ? new Set([itemId]) : new Set();
        }

        const draggedSteps = currentSteps.filter(s => currentSelection.has(s.id));
        const draggedArchive = templates.filter(t => archiveSelection.has(t.id));
        const draggedSets = stepSetTemplates.filter(s => setSelection.has(s.id));
        
        const payload = {
            type: 'multi-source-drag',
            sources: {
                steps: draggedSteps.map(s => ({ id: s.id, description: s.description })),
                archive: draggedArchive.map(t => ({ id: t.id, description: t.description })),
                sets: draggedSets.map(s => ({ id: s.id, name: s.name, steps: s.steps })),
            },
        };
        
        const allDraggedIds = new Set([...currentSelection, ...archiveSelection, ...setSelection]);
        setDraggedIds(allDraggedIds);

        const touch = e.touches[0];
        const targetRect = (e.currentTarget as HTMLElement).getBoundingClientRect();
        
        const parts = [];
        if (payload.sources.steps?.length > 0) parts.push(`${payload.sources.steps.length} 个步骤`);
        if (payload.sources.archive?.length > 0) parts.push(`${payload.sources.archive.length} 个归档项`);
        if (payload.sources.sets?.length > 0) parts.push(`${payload.sources.sets.length} 个模板`);
        const ghostContent = parts.join(', ');
        const ghost = <div className="p-2 rounded-lg bg-white dark:bg-slate-600 shadow-xl">{ghostContent || '拖动中...'}</div>;

        setTouchDragState({
            payload, ghostElement: ghost,
            position: { x: touch.clientX, y: touch.clientY },
            offset: { x: touch.clientX - targetRect.left, y: touch.clientY - targetRect.top }
        });
    }, [currentSteps, templates, stepSetTemplates, selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds]);

    useEffect(() => {
        const handleTouchMove = (e: TouchEvent) => {
            if (touchDragState) {
                e.preventDefault();
                const touch = e.touches[0];
                setTouchDragState(prev => prev ? { ...prev, position: { x: touch.clientX, y: touch.clientY } } : null);
                updateDropIndicator(touch.clientX, touch.clientY, JSON.stringify(touchDragState.payload));
            }
        };

        const handleTouchEnd = (e: TouchEvent) => {
            if (touchDragState && dropIndicator) {
                commitDrop(touchDragState.payload, dropIndicator.panel, dropIndicator.index);
            }
            setTouchDragState(null);
            setDropIndicator(null);
            setDraggedIds(new Set());
        };

        if (touchDragState) {
            window.addEventListener('touchmove', handleTouchMove, { passive: false });
            window.addEventListener('touchend', handleTouchEnd);
        }

        return () => {
            window.removeEventListener('touchmove', handleTouchMove);
            window.removeEventListener('touchend', handleTouchEnd);
        };
    }, [touchDragState, dropIndicator, commitDrop, updateDropIndicator]);

    const handleSwipeStart = (e: React.TouchEvent) => {
      touchStartRef.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
    };

    const handleSwipeEnd = (e: React.TouchEvent) => {
        if (!touchStartRef.current || touchDragState) return;

        const endX = e.changedTouches[0].clientX;
        const endY = e.changedTouches[0].clientY;
        const startX = touchStartRef.current.x;
        const startY = touchStartRef.current.y;
        const dx = startX - endX;
        const dy = Math.abs(startY - endY);
        const threshold = 75;

        if (Math.abs(dx) > threshold && Math.abs(dx) > dy) { // Horizontal swipe
            if (dx > 0) setActivePanelIndex(i => Math.min(panelTitles.length - 1, i + 1)); // Swipe left
            else setActivePanelIndex(i => Math.max(0, i - 1)); // Swipe right
        }
        touchStartRef.current = null;
    };
    
    const handleMoveSelectedToArchive = () => {
        if (selectedCurrentStepIds.size === 0) return;
        const itemsToMove = currentSteps.filter(step => selectedCurrentStepIds.has(step.id));
        const remainingSteps = currentSteps.filter(step => !selectedCurrentStepIds.has(step.id));
        
        const existingArchiveDescriptions = new Set(templates.map(t => t.description));
        const newTemplatesToAdd = itemsToMove
            .filter(item => !existingArchiveDescriptions.has(item.description))
            .map(item => ({
                id: `template-${Date.now()}-${Math.random()}`,
                description: item.description,
            }));

        if (newTemplatesToAdd.length > 0) {
            onTemplatesChange([...templates, ...newTemplatesToAdd].sort((a, b) => a.description.localeCompare(b.description)));
        }

        handleCurrentStepsChange(remainingSteps);
        setSelectedCurrentStepIds(new Set());
        showSnackbar(`${itemsToMove.length} 个步骤已归档`, <ArchiveBoxIcon className="w-5 h-5" />);
    };

    const handleAddSelectedToSteps = () => {
        const itemsFromArchive = templates.filter(template => selectedTemplateIds.has(template.id));
        const stepsFromSets = stepSetTemplates.flatMap(set => 
            selectedTemplateSetIds.has(set.id) ? set.steps : []
        );

        const newSteps = [...itemsFromArchive, ...stepsFromSets].map(item => ({
            id: `step-${Date.now()}-${Math.random()}`,
            description: item.description,
            timestamp: new Date(),
            completed: false,
        }));
        
        if(newSteps.length > 0) {
            handleCurrentStepsChange([...currentSteps, ...newSteps]);
            showSnackbar(`${newSteps.length} 个项目已添加`, <PlusIcon className="w-5 h-5" />);
        }
    };

    const handleSaveSelectedAsTemplateSet = () => {
        const itemsToSave: {description: string}[] = [];
        if (selectedCurrentStepIds.size > 0) {
            itemsToSave.push(...currentSteps.filter(step => selectedCurrentStepIds.has(step.id)));
        }
        if (selectedTemplateIds.size > 0) {
            itemsToSave.push(...templates.filter(template => selectedTemplateIds.has(template.id)));
        }

        if(itemsToSave.length === 0) return;
        
        setNewTemplateName(`新模板 ${new Date().toLocaleTimeString()}`);
        setNewTemplateModalData({ items: itemsToSave });
    };
    
    const handleMoveSelectedSetsToArchive = () => {
        if (selectedTemplateSetIds.size === 0) return;

        const stepsToArchive: { description: string }[] = [];
        stepSetTemplates.forEach(set => {
            if (selectedTemplateSetIds.has(set.id)) {
                stepsToArchive.push(...set.steps);
            }
        });
        
        const existingArchiveDescriptions = new Set(templates.map(t => t.description));
        const newTemplatesToAdd = stepsToArchive
            .filter(item => !existingArchiveDescriptions.has(item.description))
            .map(item => ({
                id: `template-${Date.now()}-${Math.random()}`,
                description: item.description,
            }));

        if (newTemplatesToAdd.length > 0) {
            onTemplatesChange([...templates, ...newTemplatesToAdd].sort((a, b) => a.description.localeCompare(b.description)));
            showSnackbar(`${newTemplatesToAdd.length} 个步骤已归档`, <ArchiveBoxIcon className="w-5 h-5" />);
        }
    };
    
    const handleDeleteSelected = useCallback(() => {
        const totalDeleted = selectedCurrentStepIds.size + selectedTemplateIds.size + selectedTemplateSetIds.size;
        if(selectedCurrentStepIds.size > 0) {
            handleCurrentStepsChange(currentSteps.filter(step => !selectedCurrentStepIds.has(step.id)));
        }
        if(selectedTemplateIds.size > 0) {
            onTemplatesChange(templates.filter(t => !selectedTemplateIds.has(t.id)));
        }
        if(selectedTemplateSetIds.size > 0) {
            onStepSetTemplatesChange(stepSetTemplates.filter(t => !selectedTemplateSetIds.has(t.id)));
        }
        
        // Clear all selections
        setSelectedCurrentStepIds(new Set());
        setSelectedTemplateIds(new Set());
        setSelectedTemplateSetIds(new Set());
        if (totalDeleted > 0) showSnackbar(`已删除 ${totalDeleted} 个项目`, <TrashIcon className="w-5 h-5" />);
    }, [currentSteps, templates, stepSetTemplates, selectedCurrentStepIds, selectedTemplateIds, selectedTemplateSetIds, handleCurrentStepsChange, onTemplatesChange, onStepSetTemplatesChange]);

    const handleContainerClickToDeselect = (e: React.MouseEvent) => {
        if (e.target === e.currentTarget) {
            clearAllSelections();
        }
    };

    if (!activeEvent) {
      return null;
    }
    
    const renderCurrentStepsPanel = () => (
        <section ref={currentStepsPanelRef} className="border border-slate-200 dark:border-slate-700 rounded-lg flex flex-col min-h-0 w-full animate-fade-in-up flex-grow">
            <div className="flex justify-between items-center mb-3 flex-shrink-0 p-4 pb-0">
                <h3 className="font-bold text-lg">{panelTitles[0]}</h3>
                <button onClick={handleClearCurrentSteps} className="text-sm text-red-500 hover:underline disabled:text-slate-400 disabled:no-underline px-2 py-1 transition-transform active:scale-95" disabled={currentSteps.length === 0}>重置</button>
            </div>
            <div className="flex-grow flex flex-col min-h-0 bg-slate-100 dark:bg-slate-900/50 rounded-b-lg">
                <div onDragOver={handlePanelDragOver} onDrop={(e) => handleDrop(e, 'current')} onDragLeave={() => setDropIndicator(null)} onClick={handleContainerClickToDeselect} className="flex-grow overflow-y-auto flex flex-col gap-2 content-start p-2 mx-2 cursor-default">
                {currentSteps.map((step, index) => (
                    <React.Fragment key={step.id}>
                    {dropIndicator?.panel === 'current' && dropIndicator.index === index && <DropIndicator orientation="horizontal" />}
                    <DraggableItem itemType="current" id={step.id} description={step.description} onUpdate={updateCurrentStep} dragProps={{ onDragStart: (e) => handleGenericDragStart(e, 'current', step.id), onTouchStart: (e) => startTouchDrag(e, 'current', step.id) }} onItemClick={handleCurrentStepInteraction} onItemLongPress={handleCurrentStepLongPress} onItemPointerDown={handleItemPointerDown} onContextMenu={(e) => handleCurrentStepContextMenu(e, step.id)} isGhost={draggedIds.has(step.id)} isSelected={selectedCurrentStepIds.has(step.id)} isSelectionMode={isSelectionMode} />
                    </React.Fragment>
                ))}
                {dropIndicator?.panel === 'current' && dropIndicator.index === currentSteps.length && <DropIndicator orientation="horizontal" />}
                {currentSteps.length === 0 && !dropIndicator && <p className="text-slate-500 text-center py-4 w-full select-none">从归档或模板中添加，或创建新步骤。</p>}
                </div>
                <div className="flex-shrink-0 p-4 pt-3">
                    <AddInput placeholder="添加新步骤..." onAdd={addStepToCurrent} />
                </div>
            </div>
        </section>
    );

    const renderArchivePanel = () => (
         <section ref={archivePanelRef} className="border border-slate-200 dark:border-slate-700 rounded-lg flex flex-col min-h-0 w-full animate-fade-in-up flex-grow" style={{ animationDelay: '100ms' }}>
            <div className="flex justify-between items-center mb-3 flex-shrink-0 p-4 pb-0">
                <h3 className="font-bold text-lg">{panelTitles[1]}</h3>
                <button onClick={handleClearSingleTemplates} className="text-sm text-red-500 hover:underline disabled:text-slate-400 disabled:no-underline px-2 py-1 transition-transform active:scale-95" disabled={templates.length === 0}>重置</button>
            </div>
            <div className="flex-grow flex flex-col min-h-0 bg-slate-100 dark:bg-slate-900/50 rounded-b-lg">
                <div onDragOver={handlePanelDragOver} onDrop={(e) => handleDrop(e, 'archive')} onDragLeave={() => setDropIndicator(null)} onClick={handleContainerClickToDeselect} className="flex-grow overflow-y-auto flex flex-col gap-2 content-start p-2 mx-2 cursor-default">
                    {templates.map((template, index) => (
                    <React.Fragment key={template.id}>
                        {dropIndicator?.panel === 'archive' && dropIndicator.index === index && <DropIndicator orientation="horizontal" />}
                        <DraggableItem itemType="archive" id={template.id} description={template.description} onUpdate={updateSingleTemplate} dragProps={{ onDragStart: (e) => handleGenericDragStart(e, 'archive', template.id), onTouchStart: (e) => startTouchDrag(e, 'archive', template.id), }} onItemClick={handleTemplateInteraction} onItemLongPress={handleTemplateLongPress} onItemPointerDown={handleItemPointerDown} onContextMenu={(e) => handleTemplateContextMenu(e, template.id)} isGhost={draggedIds.has(template.id)} isSelected={selectedTemplateIds.has(template.id)} isSelectionMode={isSelectionMode}/>
                    </React.Fragment>
                    ))}
                    {dropIndicator?.panel === 'archive' && dropIndicator.index === templates.length && <DropIndicator orientation="horizontal" />}
                    {templates.length === 0 && !dropIndicator && <p className="text-slate-500 text-center py-4 w-full select-none">将左侧的步骤拖到此处以备将来使用。</p>}
                </div>
                <div className="flex-shrink-0 p-4 pt-3">
                    <AddInput placeholder="创建可复用的步骤..." onAdd={addSingleTemplate}/>
                </div>
            </div>
        </section>
    );

    const renderTemplatesPanel = () => (
        <section ref={templateSetPanelRef} className={`border border-slate-200 dark:border-slate-700 rounded-lg flex flex-col min-h-0 w-full animate-fade-in-up flex-grow`} style={{ animationDelay: '200ms' }}>
                <h3 className="font-bold mb-3 text-lg flex-shrink-0 p-4 pb-0">{panelTitles[2]}</h3>
                <div className="flex-grow space-y-3 overflow-y-auto px-4 pb-4" onClick={handleContainerClickToDeselect} onDrop={handleDropOnTemplatePanel} onDragOver={(e) => {
                    e.preventDefault();
                    const payloadString = e.dataTransfer.getData('application/json');
                    if (!payloadString) return;
                    try {
                        const payload = JSON.parse(payloadString);
                        if (payload.type === 'multi-source-drag' && payload.sources.sets?.length > 0) {
                            handlePanelDragOver(e);
                            e.dataTransfer.dropEffect = 'move';
                        } else {
                            e.dataTransfer.dropEffect = 'copy';
                            const target = e.target as HTMLElement;
                            if (!target.closest('[data-reorder-id]')) setDropIndicator(null);
                        }
                    } catch (e) {}
                }} onDragLeave={() => setDropIndicator(null)}>
                    <SaveAsSetInput onSave={saveCurrentAsSet} currentStepCount={currentSteps.length}/>
                    {stepSetTemplates.map((templateSet, index) => (
                    <React.Fragment key={templateSet.id}>
                        {dropIndicator?.panel === 'templateSet' && dropIndicator.index === index && <DropIndicator orientation="horizontal" className="mx-2" />}
                        <TemplateSetItem 
                            templateSet={templateSet} 
                            onUpdate={updateStepSetTemplate} 
                            onDragStartSet={(e) => handleGenericDragStart(e, 'templateSet', templateSet.id)} 
                            onTouchStartSet={(e) => startTouchDrag(e, 'templateSet', templateSet.id)} 
                            isGhost={draggedIds.has(templateSet.id)} 
                            draggedStepIds={draggedIds} 
                            onSetDraggedIds={setDraggedIds}
                            isSelectionMode={isSelectionMode}
                            isSelected={selectedTemplateSetIds.has(templateSet.id)}
                            onItemClick={handleTemplateSetInteraction}
                            onItemLongPress={handleTemplateSetLongPress}
                            onItemPointerDown={handleItemPointerDown}
                            onContextMenu={(e) => handleTemplateSetContextMenu(e, templateSet.id)}
                        />
                    </React.Fragment>
                    ))}
                    {dropIndicator?.panel === 'templateSet' && dropIndicator.index === stepSetTemplates.length && <DropIndicator orientation="horizontal" className="mx-2" />}
                </div>
        </section>
    );

    const panels = [renderCurrentStepsPanel(), renderArchivePanel(), renderTemplatesPanel()];
    
    const mobileActionButtonClass = "flex-1 px-1 py-3 text-sm font-semibold text-center transition-all duration-300 border-b-2 border-transparent flex items-center justify-center gap-1.5";
    
    const renderMobileSelectionActions = () => {
      if (!isSelectionMode) return null;
  
      const hasSteps = selectedCurrentStepIds.size > 0;
      const hasArchive = selectedTemplateIds.size > 0;
      const hasSets = selectedTemplateSetIds.size > 0;
  
      const showAddToSteps = hasArchive || hasSets;
      const showMoveToArchive = hasSteps;
      const showSaveAsTemplate = (hasSteps || hasArchive) && !hasSets;
      const showMoveSetsToArchive = hasSets && !hasSteps && !hasArchive;
      const showDelete = true;
  
      return (
          <div className="flex items-center -mb-px">
              {showAddToSteps && (
                  <button onClick={handleAddSelectedToSteps} className={`${mobileActionButtonClass} text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700`}>
                      <ChevronLeftIcon className="w-4 h-4"/>步骤
                  </button>
              )}
              {showMoveToArchive && (
                   <button onClick={handleMoveSelectedToArchive} className={`${mobileActionButtonClass} text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700`}>
                      <ChevronRightIcon className="w-4 h-4"/>归档
                  </button>
              )}
               {showMoveSetsToArchive && (
                  <button onClick={handleMoveSelectedSetsToArchive} className={`${mobileActionButtonClass} text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700`}>
                      <ArrowUpTrayIcon className="w-4 h-4"/>归档
                  </button>
              )}
              {showSaveAsTemplate && (
                  <button onClick={handleSaveSelectedAsTemplateSet} className={`${mobileActionButtonClass} text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700`}>
                      <SaveIcon className="w-4 h-4"/>模板
                  </button>
              )}
              {showDelete && (
                  <button onClick={handleDeleteSelected} className={`${mobileActionButtonClass} text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/50`}>
                      <TrashIcon className="w-4 h-4"/>删除
                  </button>
              )}
          </div>
      );
    };

    const handleHeaderCloseOrClearSelectionClick = () => {
        if (isSelectionMode) {
            clearAllSelections();
        } else {
            handleClose();
        }
    };

    const headerContent = isSelectionMode && !isMobileView ? (
      <UnifiedActionsHeader
          selectedCurrentStepIds={selectedCurrentStepIds}
          selectedTemplateIds={selectedTemplateIds}
          selectedTemplateSetIds={selectedTemplateSetIds}
          onMoveToArchive={handleMoveSelectedToArchive}
          onSaveAsTemplate={handleSaveSelectedAsTemplateSet}
          onAddToSteps={handleAddSelectedToSteps}
          onAddSetsToSteps={handleAddSelectedToSteps}
          onMoveSetsToArchive={handleMoveSelectedSetsToArchive}
          onDelete={handleDeleteSelected}
      />
    ) : (
      <h2 className="text-xl font-bold truncate pr-4">编辑步骤: <span className="text-slate-800 dark:text-slate-200 font-semibold">{activeEvent.title}</span></h2>
    );

    return (
      <>
        <Modal 
            isOpen={isOpen} 
            onClose={handleClose} 
            variant="sheet" 
            maxWidthClass="lg:max-w-7xl" 
            contentClass="h-full max-h-[95vh] lg:h-full lg:max-h-[90vh]"
            headerContent={headerContent}
            overrideCloseAction={handleHeaderCloseOrClearSelectionClick}
            onExited={handleExited}
        >
          <div 
            className="flex flex-col h-full"
            onDragEnd={handleDragEnd} 
            onClick={handleCloseContextMenu}
          >
              {isMobileView ? (
                  <div className="flex-grow flex flex-col min-h-0" onTouchStart={handleSwipeStart} onTouchEnd={handleSwipeEnd}>
                      <div className="flex-shrink-0 border-b border-slate-200 dark:border-slate-700 px-2">
                          {isSelectionMode ? renderMobileSelectionActions() : (
                              <div className="flex items-center -mb-px">
                                  {panelTitles.map((title, index) => (
                                      <button
                                          key={title}
                                          onClick={() => setActivePanelIndex(index)}
                                          className={`flex-1 px-1 py-3 text-base font-semibold text-center transition-all duration-300 border-b-2 ${
                                              activePanelIndex === index
                                                  ? 'text-slate-800 dark:text-slate-100 border-slate-800 dark:border-slate-100'
                                                  : 'text-slate-500 dark:text-slate-400 border-transparent hover:text-slate-700 dark:hover:text-slate-200 hover:border-slate-300 dark:hover:border-slate-600'
                                          }`}
                                      >
                                          {title}
                                      </button>
                                  ))}
                              </div>
                          )}
                      </div>
                      <div className="flex-grow overflow-hidden relative">
                          <div className="flex h-full transition-transform duration-300 ease-in-out" style={{ width: `${panels.length * 100}%`, transform: `translateX(-${activePanelIndex * (100 / panels.length)}%)`}}>
                              {panels.map((panel, index) => <div key={index} className="w-full h-full p-4 flex flex-col">{panel}</div>)}
                          </div>
                      </div>
                  </div>
              ) : (
                  <div className="flex-grow flex flex-col min-h-0">
                      <div className="flex-grow lg:grid lg:grid-cols-3 gap-4 min-h-0">
                          {panels.map((panel, index) => <React.Fragment key={index}>{panel}</React.Fragment>)}
                      </div>
                  </div>
              )}
               
               {touchDragState && (
                  <div 
                      id="touch-drag-ghost"
                      className="fixed top-0 left-0 pointer-events-none z-50" 
                      style={{ transform: `translate(${touchDragState.position.x - touchDragState.offset.x}px, ${touchDragState.position.y - touchDragState.offset.y}px)` }}
                  >
                      {touchDragState.ghostElement}
                  </div>
              )}
              {contextMenu && <ContextMenu x={contextMenu.x} y={contextMenu.y} actions={contextMenuActions} onClose={handleCloseContextMenu}/>}
              <Modal isOpen={showClearStepsConfirm} onClose={() => setShowClearStepsConfirm(false)} title="确认重置步骤" variant="dialog">
                  <div className="space-y-4">
                      <p>此操作将重置当前事件的所有 {currentSteps.length} 个步骤。确定要继续吗？此操作无法撤销。</p>
                      <div className="flex justify-end gap-3 pt-2">
                          <button onClick={() => setShowClearStepsConfirm(false)} className="px-5 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-base font-medium">取消</button>
                          <button onClick={confirmClearCurrentSteps} className="px-5 py-2.5 rounded-lg bg-red-600 text-white font-semibold hover:bg-red-700 transition-all active:scale-95 text-base">确认重置</button>
                      </div>
                  </div>
              </Modal>
              <Modal isOpen={showClearArchiveConfirm} onClose={() => setShowClearArchiveConfirm(false)} title="确认重置归档" variant="dialog">
                  <div className="space-y-4">
                      <p>此操作将重置所有 {templates.length} 个归档步骤。确定要继续吗？此操作无法撤销。</p>
                      <div className="flex justify-end gap-3 pt-2">
                          <button onClick={() => setShowClearArchiveConfirm(false)} className="px-5 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-base font-medium">取消</button>
                          <button onClick={confirmClearSingleTemplates} className="px-5 py-2.5 rounded-lg bg-red-600 text-white font-semibold hover:bg-red-700 transition-all active:scale-95 text-base">确认重置</button>
                      </div>
                  </div>
              </Modal>
              <Modal isOpen={!!newTemplateModalData} onClose={() => setNewTemplateModalData(null)} title={`为 ${newTemplateModalData?.items.length || 0} 个步骤创建新模板`} variant="sheet">
                  <div className="space-y-4">
                      <div>
                          <label htmlFor="newTemplateName" className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">模板名称</label>
                          <input type="text" id="newTemplateName" value={newTemplateName} onChange={(e) => setNewTemplateName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && handleCreateTemplateFromModal()} className="w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg focus:ring-slate-500 focus:border-slate-500"/>
                      </div>
                      <div className="flex justify-end gap-3 pt-2">
                          <button onClick={() => setNewTemplateModalData(null)} className="px-5 py-2.5 rounded-lg text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-base font-medium">取消</button>
                          <button onClick={handleCreateTemplateFromModal} className="px-5 py-2.5 rounded-lg bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900 font-semibold hover:bg-slate-700 dark:hover:bg-slate-300 transition-all active:scale-95 text-base">创建</button>
                      </div>
                  </div>
              </Modal>
          </div>
        </Modal>
        <Snackbar
            isOpen={!!snackbar}
            message={snackbar?.message || ''}
            icon={snackbar?.icon}
            bottomClass="bottom-24 lg:bottom-8"
        />
      </>
    );
  };
  
  export default StepsEditorPanel;