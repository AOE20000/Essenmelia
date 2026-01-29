import React, { useState } from 'react';
import Button from '../../components/ui/Button';

interface PromptModuleProps {
    title?: string;
    message?: string;
    defaultValue?: string;
    placeholder?: string;
    confirmText?: string;
    cancelText?: string;
    onConfirm: (value: string) => void;
    closeWindow: () => void;
}

export const PromptModule: React.FC<PromptModuleProps> = ({ 
    message, defaultValue = '', placeholder, confirmText = '确定', cancelText = '取消', onConfirm, closeWindow 
}) => {
    const [value, setValue] = useState(defaultValue);

    const handleSubmit = (e?: React.FormEvent) => {
        e?.preventDefault();
        if (value.trim()) {
            onConfirm(value.trim());
            closeWindow();
        }
    };

    return (
        <form onSubmit={handleSubmit} className="space-y-6">
            {message && <p className="text-slate-600 dark:text-slate-300 text-lg leading-relaxed">{message}</p>}
            <div>
                <input
                    autoFocus
                    type="text"
                    value={value}
                    onChange={(e) => setValue(e.target.value)}
                    placeholder={placeholder}
                    className="w-full px-4 py-3 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm border border-slate-300 dark:border-slate-600 rounded-xl focus:ring-2 focus:ring-brand-500/20 outline-none transition-all shadow-sm focus:bg-white dark:focus:bg-slate-800 text-slate-900 dark:text-slate-100 text-lg"
                />
            </div>
            <div className="flex justify-end gap-3 pt-2">
                <Button type="button" variant="secondary" onClick={closeWindow}>{cancelText}</Button>
                <Button type="submit" disabled={!value.trim()}>{confirmText}</Button>
            </div>
        </form>
    );
};