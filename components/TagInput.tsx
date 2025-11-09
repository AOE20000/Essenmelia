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
      <div className="flex flex-wrap items-center gap-2 p-2.5 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-700" onClick={() => inputRef.current?.focus()}>
        {selectedTags.map((tag) => (
          <span key={tag} className="flex items-center gap-1.5 bg-slate-200 dark:bg-slate-600 text-slate-800 dark:text-slate-100 text-sm font-medium px-2.5 py-1 rounded-full">
            {tag}
            <button
              type="button"
              onClick={() => handleRemoveTag(tag)}
              className="text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200 -mr-1 p-0.5 rounded-full transition-transform active:scale-90"
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
          placeholder={selectedTags.length > 0 ? "添加更多..." : "添加标签 (用空格分隔)..."}
          className="flex-grow bg-transparent focus:outline-none p-1 text-slate-800 dark:text-slate-100"
        />
      </div>
      {suggestions.length > 0 && (
        <ul className="absolute z-10 w-full mt-1 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 rounded-lg shadow-lg max-h-40 overflow-y-auto">
          {suggestions.map((suggestion) => (
            <li
              key={suggestion}
              onClick={() => handleAddTags(suggestion)}
              className="px-4 py-2 cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700"
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