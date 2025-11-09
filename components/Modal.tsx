import React, { useEffect, useState, useRef } from 'react';
import { XIcon } from './icons';

// 一个简单的 hook，用于获取窗口宽度，因为这是一个独立的组件。
const useWindowWidth = () => {
    const [windowWidth, setWindowWidth] = useState(window.innerWidth);
    useEffect(() => {
        const handleResize = () => setWindowWidth(window.innerWidth);
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);
    return windowWidth;
};

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  headerContent?: React.ReactNode;
  overrideCloseAction?: () => void;
  children: React.ReactNode;
  variant?: 'dialog' | 'sheet';
  maxWidthClass?: string;
  contentClass?: string;
  onExited?: () => void;
}

const Modal: React.FC<ModalProps> = ({ 
  isOpen, onClose, title, headerContent, overrideCloseAction, children, 
  variant = 'dialog', maxWidthClass, contentClass, onExited
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
  
  const handleClose = () => {
    onClose();
  };

  const closeAction = overrideCloseAction || handleClose;

  const handleAnimationEnd = (e: React.AnimationEvent) => {
    if (e.target === e.currentTarget && isClosing) {
      setIsRendered(false);
      if (onExited) {
        onExited();
      }
    }
  };

  const isSheet = variant === 'sheet';
  const isMobileView = windowWidth < 640;

  const handlePointerDown = (e: React.PointerEvent) => {
    if (!isSheet || !isMobileView || !contentRef.current) return;

    const target = e.target as HTMLElement;
    const handle = target.closest('[data-drag-handle="true"]');
    const scrollableContent = contentRef.current.querySelector('[data-scrollable-content="true"]');
    
    let canDrag = false;
    if (handle) {
      canDrag = true;
    } else if (scrollableContent && scrollableContent.contains(target)) {
      if (scrollableContent.scrollTop === 0) {
        canDrag = true;
      }
    } else {
      // Allow dragging from non-scrollable areas like padding inside the modal content
      canDrag = true;
    }

    if (canDrag) {
      dragState.startY = e.clientY;
      dragState.isDragging = true;
      contentRef.current.style.transition = 'none';
      target.setPointerCapture(e.pointerId);
    }
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!dragState.isDragging || !contentRef.current) return;
    
    const deltaY = e.clientY - dragState.startY;

    if (deltaY > 0) {
      e.preventDefault();
      contentRef.current.style.transform = `translateY(${deltaY}px)`;
    } else {
      // If user starts dragging up, release to allow native scroll
      dragState.isDragging = false;
      contentRef.current.style.transform = '';
      (e.target as HTMLElement).releasePointerCapture(e.pointerId);
    }
  };
  
  const handlePointerUp = (e: React.PointerEvent) => {
    if (!dragState.isDragging || !contentRef.current) return;
    
    dragState.isDragging = false;
    (e.target as HTMLElement).releasePointerCapture(e.pointerId);

    const deltaY = e.clientY - dragState.startY;
    const dragThreshold = contentRef.current.offsetHeight * 0.4; // Close if dragged 40%

    if (deltaY > dragThreshold) {
      handleClose();
    } else {
      contentRef.current.style.transition = 'transform 0.3s ease-out';
      contentRef.current.style.transform = '';
      setTimeout(() => {
        if (contentRef.current) {
          contentRef.current.style.transition = '';
        }
      }, 300);
    }
  };

  if (!isRendered) {
    return null;
  }

  const backdropAnimation = isClosing ? 'animate-backdrop-exit' : 'animate-backdrop-enter';

  let contentAnimation: string;
  if (isSheet) {
    if (isMobileView) {
        contentAnimation = isClosing ? 'animate-sheet-exit' : 'animate-sheet-enter';
    } else {
        contentAnimation = isClosing ? 'animate-dialog-exit' : 'animate-dialog-enter';
    }
  } else { // dialog
    contentAnimation = isClosing ? 'animate-dialog-exit' : 'animate-dialog-enter';
  }

  const backdropClasses = `
    fixed inset-0 z-50 flex bg-black bg-opacity-60 backdrop-blur-sm
    ${isSheet ? 'items-end sm:items-center' : 'items-center'}
    justify-center
    ${backdropAnimation}
  `;

  const contentBaseClasses = `bg-slate-50 dark:bg-slate-800 shadow-2xl w-full relative flex flex-col ${contentClass || 'max-h-[90vh]'}`;
  
  const sheetClasses = `rounded-t-2xl sm:rounded-2xl max-w-full ${maxWidthClass || 'sm:max-w-md'} sm:m-4`;
  const dialogClasses = `rounded-2xl ${maxWidthClass || 'max-w-md'} m-4`;

  const contentClasses = `${contentBaseClasses} ${isSheet ? sheetClasses : dialogClasses} ${contentAnimation}`;

  return (
    <div 
      className={backdropClasses}
      onClick={handleClose}
      role="dialog"
      aria-modal="true"
    >
      <div 
        ref={contentRef}
        className={contentClasses}
        onClick={(e) => e.stopPropagation()}
        onAnimationEnd={handleAnimationEnd}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
      >
        {isSheet && <div data-drag-handle="true" className="absolute top-0 left-1/2 -translate-x-1/2 w-12 h-1.5 bg-slate-300 dark:bg-slate-600 rounded-full mt-2 sm:hidden" />}
        
        {(title || headerContent) && (
            <div data-drag-handle="true" className={`flex justify-between items-center gap-4 flex-shrink-0 ${isSheet ? 'pt-8 sm:pt-4' : 'pt-4'} p-4 border-b border-slate-200 dark:border-slate-700`}>
              <div className="flex-grow min-w-0">
                {headerContent ? headerContent : (
                  <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100 truncate">{title}</h2>
                )}
              </div>
              <button 
                onClick={closeAction} 
                className="flex-shrink-0 text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg p-2 transition-colors"
                aria-label="关闭"
              >
                <XIcon className="h-6 w-6" />
              </button>
            </div>
        )}
        <div data-scrollable-content="true" className={`flex-grow min-h-0 flex flex-col overflow-y-auto no-scrollbar ${(title || headerContent) ? 'p-4' : ''}`}>{children}</div>
      </div>
    </div>
  );
};

export default Modal;