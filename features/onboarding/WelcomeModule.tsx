import React from 'react';
import { useDatabase } from '../../context/DatabaseContext';
import { DEMO_DB_NAME_EXPORT } from '../../services/DatabaseService';
import WelcomeModal from '../../components/WelcomeModal'; // Reuse UI

export const WelcomeModule: React.FC<{ closeWindow: () => void }> = ({ closeWindow }) => {
  const { switchDb } = useDatabase();

  const handleEnterDemo = () => {
      switchDb(DEMO_DB_NAME_EXPORT);
      closeWindow();
      localStorage.setItem('hasSeenWelcomeModal', 'true');
  };
  
  const handleClose = () => {
      closeWindow();
      localStorage.setItem('hasSeenWelcomeModal', 'true');
  };

  return (
    <WelcomeModal
        onClose={handleClose}
        onEnterDemo={handleEnterDemo}
    />
  );
};