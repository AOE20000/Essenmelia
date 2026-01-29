import React from 'react';
import { useEvents } from '../../context/EventsContext';
import StepsEditorPanel from '../../components/StepsEditorPanel'; // Reuse logic

export const StepsEditorModule: React.FC<{ 
    eventId: string;
    closeWindow: () => void; 
    setHeader: (node: React.ReactNode) => void;
    setOverrideCloseAction: (action: (() => void) | null) => void;
}> = ({ eventId, closeWindow, setHeader, setOverrideCloseAction }) => {
  const { 
      events, stepTemplates, stepSetTemplates, 
      updateEventSteps, updateStepTemplates, updateStepSetTemplates 
  } = useEvents();

  const event = events.find(e => e.id === eventId);

  if (!event) return <div>事件未找到</div>;

  return (
    <StepsEditorPanel
        onClose={closeWindow}
        event={event}
        templates={stepTemplates}
        stepSetTemplates={stepSetTemplates}
        onStepsChange={(eid, steps) => updateEventSteps(eid, steps)}
        onTemplatesChange={updateStepTemplates}
        onStepSetTemplatesChange={updateStepSetTemplates}
        setHeader={setHeader}
        setOverrideCloseAction={setOverrideCloseAction}
    />
  );
};