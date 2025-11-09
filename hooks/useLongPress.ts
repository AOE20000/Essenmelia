import React, { useCallback, useRef, useEffect } from 'react';

const isTouchEvent = (ev: React.MouseEvent | React.TouchEvent): ev is React.TouchEvent => {
  return 'touches' in ev;
};

interface LongPressOptions {
  shouldPreventDefault?: boolean;
  delay?: number;
  onDrag?: (e: React.TouchEvent) => void;
}

const useLongPress = (
  onLongPress: (e: React.MouseEvent | React.TouchEvent) => void,
  onClick: (e: React.MouseEvent | React.TouchEvent) => void,
  { shouldPreventDefault = true, delay = 300, onDrag }: LongPressOptions = {}
) => {
  const timeout = useRef<ReturnType<typeof window.setTimeout>>();
  const pressCoordinates = useRef<{ x: number; y: number } | null>(null);
  const isLongPressTriggered = useRef(false);
  const isSwipe = useRef(false);
  const isDragging = useRef(false);
  const SWIPE_THRESHOLD = 10; // pixels
  
  // Cleanup timeout on unmount
  useEffect(() => () => {
    if (timeout.current) {
        clearTimeout(timeout.current);
    }
  }, []);

  const start = useCallback(
    (event: React.MouseEvent | React.TouchEvent) => {
      // Prevent context menu on long touch
      if (shouldPreventDefault && isTouchEvent(event)) {
          // This helps prevent the context menu on Android Chrome when holding a touch
          event.preventDefault();
      }
      isLongPressTriggered.current = false;
      isSwipe.current = false;
      isDragging.current = false;

      if (isTouchEvent(event)) {
        pressCoordinates.current = { x: event.touches[0].clientX, y: event.touches[0].clientY };
      } else {
        pressCoordinates.current = { x: event.clientX, y: event.clientY };
      }

      timeout.current = window.setTimeout(() => {
        onLongPress(event);
        isLongPressTriggered.current = true;
      }, delay);
    },
    [onLongPress, delay, shouldPreventDefault]
  );

  const clear = useCallback(
    (event: React.MouseEvent | React.TouchEvent) => {
      const wasLongPress = isLongPressTriggered.current;

      if (timeout.current) {
        window.clearTimeout(timeout.current);
        timeout.current = undefined;
      }
      
      // After any 'up' event, reset the long press flag for the next interaction.
      isLongPressTriggered.current = false;

      if (wasLongPress) {
        if (shouldPreventDefault) {
          event.preventDefault();
        }
        return;
      }
      
      if (!isSwipe.current) {
         onClick(event);
      }
    },
    [shouldPreventDefault, onClick]
  );
  
  const onMouseDown = (e: React.MouseEvent) => {
    if (e.button === 2) return;
    start(e);
  };
  
  const onMouseUp = (e: React.MouseEvent) => {
    if (e.button === 2) return;
    // Only process 'up' if a 'down' event started the timer.
    // This prevents clicks from firing if the user presses outside, moves over the element, and releases.
    if (timeout.current !== undefined) {
      clear(e);
    }
  };
  
  const onMouseLeave = (e: React.MouseEvent) => {
    if (timeout.current) {
        window.clearTimeout(timeout.current);
        timeout.current = undefined;
    }
  };
  
  const onMouseMove = (e: React.MouseEvent) => {
    if (!pressCoordinates.current || !timeout.current) return;
    
    const deltaX = Math.abs(e.clientX - pressCoordinates.current.x);
    const deltaY = Math.abs(e.clientY - pressCoordinates.current.y);
    
    if(deltaX > SWIPE_THRESHOLD || deltaY > SWIPE_THRESHOLD) {
        isSwipe.current = true;
        window.clearTimeout(timeout.current);
        timeout.current = undefined;
    }
  };

  const onTouchStart = (e: React.TouchEvent) => {
    start(e);
  };
  
  const onTouchEnd = (e: React.TouchEvent) => {
    clear(e);
    isDragging.current = false;
  };
  
  const onTouchMove = (e: React.TouchEvent) => {
    if (isDragging.current || isLongPressTriggered.current || !timeout.current || !pressCoordinates.current) return;
    
    const { clientX, clientY } = e.touches[0];
    const deltaX = Math.abs(clientX - pressCoordinates.current.x);
    const deltaY = Math.abs(clientY - pressCoordinates.current.y);

    if (deltaX > SWIPE_THRESHOLD || deltaY > SWIPE_THRESHOLD) {
      isSwipe.current = true;
      window.clearTimeout(timeout.current);
      timeout.current = undefined;
      
      if (onDrag) {
        isDragging.current = true;
        onDrag(e);
      }
    }
  };

  return {
    onMouseDown,
    onMouseUp,
    onMouseLeave,
    onMouseMove,
    onTouchStart,
    onTouchEnd,
    onTouchMove,
  };
};

export default useLongPress;
