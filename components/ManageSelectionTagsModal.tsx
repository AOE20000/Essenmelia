import React, { useState, useEffect, useMemo } from 'react';
import { Event } from '../types';
import { CheckIcon, PlusIcon, MinusIcon } from './icons';

type TagState = 'all' | 'some' | 'none';

interface ManageSelectionTagsModalProps {
  onClose: () => void;
  availableTags: string[];
  selectedEvents: Event[];
  onApply: (updates: { eventId: string; newTags: string[] }[]) => void;
  onAddTag: (newTag: string) => void;
}

const ManageSelectionTagsModal: React.FC<ManageSelectionTagsModalProps> = ({
  onClose, availableTags, selectedEvents, onApply, onAddTag
}) => {
  const [initialTagStates, setInitialTagStates] = useState<Map<string, TagState>>(new Map());
  const [tagUpdates, setTagUpdates] = useState<Map<string, 'add' | 'remove'>>(new Map());
  const [newTagInput, setNewTagInput] = useState('');

  useEffect(() => {
      const newStates = new Map<string, TagState>();
      const eventCount = selectedEvents.length;
      if (eventCount > 0) {
        // Use a combined set of available tags and tags from selected events to ensure all are processed
        const allPossibleTags = new Set([...availableTags, ...selectedEvents.flatMap(e => e.tags || [])]);
        for (const tag of allPossibleTags) {
          const count = selectedEvents.filter(e => e.tags?.includes(tag)).length;
          if (count === eventCount) {
            newStates.set(tag, 'all');
          } else if (count > 0) {
            newStates.set(tag, 'some');
          } else {
            newStates.set(tag, 'none');
          }
        }
      }
      setInitialTagStates(newStates);
      setTagUpdates(new Map());
      setNewTagInput('');
  }, [availableTags, selectedEvents]);

  const handleTagClick = (tag: string) => {
    const initialState = initialTagStates.get(tag) ?? 'none';
    const currentUpdate = tagUpdates.get(tag);

    const nextUpdates = new Map(tagUpdates);

    // Determine current effective state before click
    let effectiveState: TagState = initialState;
    if (currentUpdate === 'add') effectiveState = 'all';
    if (currentUpdate === 'remove') effectiveState = 'none';

    // Cycle through states: (some | none) -> all -> none
    if (effectiveState === 'all') {
      // Transition to 'none'
      if (initialState !== 'none') nextUpdates.set(tag, 'remove');
      else nextUpdates.delete(tag);
    } else {
      // Transition to 'all'
      if (initialState !== 'all') nextUpdates.set(tag, 'add');
      else nextUpdates.delete(tag);
    }
    setTagUpdates(nextUpdates);
  };
  
  const handleAddNewTag = () => {
    const tagsToAdd = newTagInput.trim().split(/\s+/).filter(Boolean);
    if (tagsToAdd.length > 0) {
        const nextUpdates = new Map(tagUpdates);
        tagsToAdd.forEach(newTag => {
            onAddTag(newTag);
            nextUpdates.set(newTag, 'add');
        });
        setTagUpdates(nextUpdates);
        setNewTagInput('');
    }
  };

  const handleApplyChanges = () => {
    const updates = selectedEvents.map(event => {
      const originalTags = new Set(event.tags || []);
      tagUpdates.forEach((action, tag) => {
        if (action === 'add') {
          originalTags.add(tag);
        } else if (action === 'remove') {
          originalTags.delete(tag);
        }
      });
      return { eventId: event.id, newTags: Array.from(originalTags).sort() };
    });
    onApply(updates);
    onClose();
  };
  
  const allCurrentTags = useMemo(() => {
    const tagSet = new Set(Array.from(initialTagStates.keys()));
    tagUpdates.forEach((_, tag) => tagSet.add(tag));
    return Array.from(tagSet).sort();
  }, [initialTagStates, tagUpdates]);


  const getTagDisplay = (tag: string): { state: TagState; Icon?: React.ComponentType<{className?: string}> } => {
    const initialState = initialTagStates.get(tag) ?? 'none';
    const update = tagUpdates.get(tag);
    
    if (update === 'add') return { state: 'all', Icon: CheckIcon };
    if (update === 'remove') return { state: 'none', Icon: undefined };

    if (initialState === 'all') return { state: 'all', Icon: CheckIcon };
    if (initialState === 'some') return { state: 'some', Icon: MinusIcon };
    return { state: 'none', Icon: undefined };
  };

  return (
    <div className="flex flex-col flex-1 min-h-0">
      <div className="flex-grow overflow-y-auto pr-2 -mr-4 pb-4">
        <p className="text-sm text-slate-500 dark:text-slate-400 mb-4">
          点击标签以将其添加或移除出所选项目。
          <MinusIcon className="w-4 h-4 inline-block mx-1" /> 表示该标签存在于部分项目中。
        </p>
        <div className="flex flex-wrap gap-2">
          {allCurrentTags.map(tag => {
            const { state, Icon } = getTagDisplay(tag);
            return (
              <button
                key={tag}
                onClick={() => handleTagClick(tag)}
                className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-bold transition-all duration-300 active:scale-95 border
                  ${state === 'all' ? 'bg-brand-500 text-white border-brand-500 shadow-glow-sm hover:bg-brand-600' : ''}
                  ${state === 'some' ? 'bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 border-slate-300 dark:border-slate-500 border-dashed hover:border-brand-400' : ''}
                  ${state === 'none' ? 'bg-white/50 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-brand-300 dark:hover:border-brand-700 hover:bg-white dark:hover:bg-slate-800' : ''}
                `}
              >
                {Icon && <Icon className="w-4 h-4" />}
                {tag}
              </button>
            );
          })}
        </div>
      </div>
      <div className="flex-shrink-0 pt-4 border-t border-slate-200 dark:border-slate-700">
        <div className="flex gap-2">
           <input
              type="text"
              value={newTagInput}
              onChange={(e) => setNewTagInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleAddNewTag()}
              placeholder="新标签 (用空格分隔)..."
              className="flex-grow px-4 py-2.5 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm border border-slate-300 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-brand-500/20 outline-none shadow-sm"
          />
          <button
              onClick={handleAddNewTag}
              className="px-4 py-2.5 rounded-xl font-bold flex items-center justify-center gap-1 transition-transform active:scale-95 bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 hover:bg-slate-300 dark:hover:bg-slate-600"
          >
              <PlusIcon className="w-5 h-5" />
          </button>
        </div>
        <div className="flex justify-end gap-3 pt-4">
          <button onClick={onClose} className="px-5 py-2.5 rounded-xl text-slate-700 dark:text-slate-200 bg-slate-200 dark:bg-slate-600 hover:bg-slate-300 dark:hover:bg-slate-500 transition-all active:scale-95 text-sm font-bold">取消</button>
          <button onClick={handleApplyChanges} className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-brand-600 to-brand-500 text-white font-bold hover:shadow-lg hover:shadow-brand-500/30 transition-all active:scale-95 text-sm">应用更改</button>
        </div>
      </div>
    </div>
  );
};

export default ManageSelectionTagsModal;