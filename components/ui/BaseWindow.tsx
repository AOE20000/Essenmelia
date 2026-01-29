import React, { useEffect, useState, useRef } from 'react';
import { useWindowWidth } from '../../hooks/useWindowWidth';

export type WindowVariant = 'dialog' | 'sheet';

export interface BaseWindowProps {
  isOpen: boolean;
  onClose: () => void;
  title?: React.ReactNode;
  variant?: WindowVariant;
  zIndex?: number;
  width?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  hideCloseButton?: boolean;
  children: React.ReactNode;
  headerContent?: React.ReactNode;
  contentClass?: string;
  onExited?: () => void;
}

const BaseWindow: React.FC<BaseWindowProps> = ({
  isOpen, 
  onClose, 
  title, 
  variant = 'dialog', 
  zIndex = 50, 
  width = 'md', 
  children,
  headerContent,
  contentClass,
  onExited
}) => {
  const [isRendered, setIsRendered] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  
  const contentRef = useRef<HTMLDivElement>(null);
  const dragState = useRef({ startY: 0, isDragging: false }).current;
  const windowWidth = useWindowWidth();

  useEffect(() => {
    if (isOpen) {
      setIsRendered(true);
      setIsClosing(false);
    } else {
      setIsClosing(true);
    }
  }, [isOpen]);

  const handleAnimationEnd = (e: React.AnimationEvent) => {
    if (e.target === contentRef.current && isClosing) {
      setIsRendered(false);
      if (onExited) onExited();
    }
  };

  const isMobileView = windowWidth < 640;
  const effectiveVariant = isMobileView && variant === 'sheet' ? 'sheet' : 'dialog';

  // --- Drag Logic for Sheets ---
  const handlePointerDown = (e: React.PointerEvent) => {
    if (effectiveVariant !== 'sheet' || !contentRef.current) return;

    const target = e.target as HTMLElement;
    const handle = target.closest('[data-drag-handle="true"]');
    
    if (handle) {
      dragState.startY = e.clientY;
      dragState.isDragging = true;
      contentRef.current.style.transition = 'none';
      target.setPointerCapture(e.pointerId);
      e.preventDefault(); 
    }
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!dragState.isDragging || !contentRef.current) return;
    
    e.preventDefault();

    const deltaY = e.clientY - dragState.startY;

    if (deltaY > 0) {
      contentRef.current.style.transform = `translateY(${deltaY}px)`;
    } else {
      contentRef.current.style.transform = `translateY(${deltaY * 0.2}px)`; 
    }
  };
  
  const handlePointerUp = (e: React.PointerEvent) => {
    if (!dragState.isDragging || !contentRef.current) return;
    
    dragState.isDragging = false;
    const target = e.target as HTMLElement;
    if (target.hasPointerCapture(e.pointerId)) {
        target.releasePointerCapture(e.pointerId);
    }

    const deltaY = e.clientY - dragState.startY;
    const dragThreshold = 100; 

    if (deltaY > dragThreshold) {
      onClose();
    } else {
      contentRef.current.style.transition = 'transform 0.3s cubic-bezier(0.25, 1, 0.5, 1)';
      contentRef.current.style.transform = '';
      setTimeout(() => {
        if (contentRef.current) {
          contentRef.current.style.transition = '';
        }
      }, 300);
    }
  };

  if (!isRendered) return null;

  // Animation Classes
  let animationClass = '';
  if (effectiveVariant === 'sheet') {
      animationClass = isClosing ? 'animate-sheet-exit' : 'animate-sheet-enter';
  } else {
      animationClass = isClosing ? 'animate-dialog-exit' : 'animate-dialog-enter';
  }
  
  const backdropAnimation = isClosing ? 'animate-backdrop-exit' : 'animate-backdrop-enter';

  // Width Classes
  const widthClassMap = {
    sm: 'max-w-sm',
    md: 'max-w-md',
    lg: 'max-w-2xl',
    xl: 'max-w-5xl',
    full: 'max-w-full'
  };
  const widthClass = widthClassMap[width] || widthClassMap.md;

  // Container Classes
  // Updated for Glassmorphism
  const containerStyle = effectiveVariant === 'sheet'
    ? `fixed bottom-0 left-0 right-0 rounded-t-3xl max-h-[95vh] w-full border-t border-l border-r border-white/40 dark:border-white/10`
    : `relative rounded-3xl ${widthClass} w-full m-4 max-h-[90vh] border border-white/40 dark:border-white/10`;

  return (
    <div 
      className={`fixed inset-0 flex items-center justify-center z-[${zIndex}]`}
      style={{ zIndex }}
      role="dialog"
      aria-modal="true"
    >
      {/* Backdrop */}
      <div 
        className={`absolute inset-0 bg-slate-900/40 dark:bg-black/60 backdrop-blur-sm ${backdropAnimation}`}
        onClick={onClose}
        aria-hidden="true"
      />
      
      <div 
        ref={contentRef}
        className={`bg-white/90 dark:bg-slate-900/90 backdrop-blur-xl shadow-2xl overflow-hidden flex flex-col pointer-events-auto ${containerStyle} ${animationClass} ${contentClass || ''}`}
        onAnimationEnd={handleAnimationEnd}
      >
        {effectiveVariant === 'sheet' && (
           <div 
             data-drag-handle="true" 
             className="w-full flex justify-center pt-4 pb-2 cursor-grab active:cursor-grabbing shrink-0 touch-none"
             onPointerDown={handlePointerDown}
             onPointerMove={handlePointerMove}
             onPointerUp={handlePointerUp}
             onPointerCancel={handlePointerUp}
           >
             <div className="w-12 h-1.5 bg-slate-300 dark:bg-slate-700 rounded-full" />
           </div>
        )}

        {(title || headerContent) && (
          <header className={`flex justify-between items-center px-6 py-4 border-b border-slate-200/50 dark:border-slate-700/50 shrink-0 ${effectiveVariant === 'sheet' ? 'pt-2' : ''}`}>
             <div className="flex-1 min-w-0">
               {headerContent ? headerContent : (
                 title && <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100 truncate">{title}</h2>
               )}
             </div>
          </header>
        )}

        <div data-scrollable-content="true" className="flex-1 overflow-y-auto no-scrollbar p-6">
          {children}
        </div>
      </div>
    </div>
  );
};

export default BaseWindow;