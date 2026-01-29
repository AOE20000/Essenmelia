import React from 'react';
import { useEvents } from '../../context/EventsContext';
import ManageSelectionTagsModal from '../../components/ManageSelectionTagsModal'; // Reuse logic

export const SelectionTagManagerModule: React.FC<{ closeWindow: () => void, selectedEventIds: string[] }> = ({ closeWindow, selectedEventIds }) => {
  const { events, tags, addTag, updateEvent } = useEvents();
  
  const selectedEvents = events.filter(e => selectedEventIds.includes(e.id));

  const handleApply = (updates: { eventId: string; newTags: string[] }[]) => {
      updates.forEach(update => {
          const evt = events.find(e => e.id === update.eventId);
          if (evt) {
              updateEvent({ ...evt, tags: update.newTags });
          }
      });
  };

  return (
    <ManageSelectionTagsModal
        onClose={closeWindow}
        availableTags={tags}
        selectedEvents={selectedEvents}
        onAddTag={addTag}
        onApply={handleApply}
    />
  );
};