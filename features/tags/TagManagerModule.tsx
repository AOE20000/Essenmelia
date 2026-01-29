import React from 'react';
import { useEvents } from '../../context/EventsContext';
import ManageTagsModal from '../../components/ManageTagsModal'; // Reusing logic but wrapping with context

export const TagManagerModule: React.FC<{ closeWindow: () => void, setHeader: (node: React.ReactNode) => void, setOverrideCloseAction: (action: (() => void) | null) => void }> = ({ closeWindow, setHeader, setOverrideCloseAction }) => {
  const { tags, addTag, deleteTags, renameTag, reorderTags } = useEvents();

  return (
    <ManageTagsModal
        onClose={closeWindow}
        tags={tags}
        onAddTag={addTag}
        onDeleteTags={deleteTags}
        onRenameTag={renameTag}
        onReorderTags={reorderTags}
        setHeader={setHeader}
        setOverrideCloseAction={setOverrideCloseAction}
    />
  );
};