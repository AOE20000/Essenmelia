import React, { useState, useRef, useEffect } from 'react';
import { XIcon, TagIcon } from './icons';

interface TagInputProps {
  availableTags: string[];
  selectedTags: string[];
  onChange: (tags: string[]) => void;
}

const TagInput: React.FC<TagInputProps> = ({ availableTags, selectedTags, onChange }) => {
  const [inputValue, setInputValue] = useState('');
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (inputValue) {
      const filtered = availableTags.filter(
        (tag) =>
          tag.toLowerCase().includes(inputValue.toLowerCase()) &&
          !selectedTags.includes(tag)
      );
      setSuggestions(filtered);
    } else {
      setSuggestions([]);
    }
  }, [inputValue, availableTags, selectedTags]);

  const handleRemoveTag = (tagToRemove: string) => {
    onChange(selectedTags.filter((tag) => tag !== tagToRemove));
  };

  const handleAddTags = (tagsString: string) => {
    const trimmedString = tagsString.trim();
    if (!trimmedString) {
      if (inputValue === tagsString) {
        setInputValue('');
      }
      return;
    }

    const tagsToAdd = trimmedString.split(/\s+/).filter(Boolean);
    const newSelectedTags = new Set(selectedTags);
    
    tagsToAdd.forEach((tag) => {
      if (!newSelectedTags.has(tag)) {
        newSelectedTags.add(tag);
      }
    });

    if (newSelectedTags.size > selectedTags.length) {
      onChange(Array.from(newSelectedTags));
    }

    setInputValue('');
    setSuggestions([]);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault();
      handleAddTags(inputValue);
    }
    if (e.key === 'Backspace' && !inputValue && selectedTags.length > 0) {
      handleRemoveTag(selectedTags[selectedTags.length - 1]);
    }
  };

  return (
    <div className="relative">
      <div className="flex flex-wrap items-center gap-2 p-2.5 border border-slate-300 dark:border-slate-600 rounded-xl bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm focus-within:ring-2 focus-within:ring-brand-500/20 focus-within:bg-white dark:focus-within:bg-slate-800 transition-all cursor-text" onClick={() => inputRef.current?.focus()}>
        {selectedTags.map((tag) => (
          <span key={tag} className="flex items-center gap-1.5 bg-brand-100 dark:bg-brand-900/30 text-brand-800 dark:text-brand-200 border border-brand-200 dark:border-brand-800 text-sm font-bold px-3 py-1 rounded-full animate-scale-in">
            {tag}
            <button
              type="button"
              onClick={(e) => { e.stopPropagation(); handleRemoveTag(tag); }}
              className="text-brand-600 hover:text-brand-900 dark:text-brand-400 dark:hover:text-white -mr-1 p-0.5 rounded-full transition-transform active:scale-90"
              aria-label={`移除标签 ${tag}`}
            >
              <XIcon className="w-3.5 h-3.5" />
            </button>
          </span>
        ))}
        <input
          ref={inputRef}
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={handleKeyDown}
          onBlur={() => handleAddTags(inputValue)}
          placeholder={selectedTags.length > 0 ? "" : "添加标签..."}
          className="flex-grow bg-transparent focus:outline-none p-1 text-slate-800 dark:text-slate-100 min-w-[80px]"
        />
      </div>
      {suggestions.length > 0 && (
        <ul className="absolute z-10 w-full mt-2 bg-white/90 dark:bg-slate-800/90 backdrop-blur-xl border border-slate-200 dark:border-slate-700 rounded-xl shadow-xl max-h-40 overflow-y-auto animate-dialog-enter p-1">
          {suggestions.map((suggestion) => (
            <li
              key={suggestion}
              onClick={() => handleAddTags(suggestion)}
              className="px-4 py-2 cursor-pointer hover:bg-brand-50 dark:hover:bg-brand-900/30 text-slate-700 dark:text-slate-200 rounded-lg transition-colors"
            >
              {suggestion}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
};

export default TagInput;