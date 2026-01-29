import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { dbService, DB_PREFIX, DEFAULT_DB_NAME_EXPORT, TEMP_STORAGE_DB_NAME_EXPORT, DEMO_DB_NAME_EXPORT, SETTINGS_DB_NAME, STORES } from '../services/DatabaseService';
import { useToast } from './ToastContext';

interface DatabaseContextType {
  activeDbName: string;
  userDbNames: string[];
  isTempStorageMode: boolean;
  isLoading: boolean;
  dbError: Error | null;
  refreshDbList: () => Promise<void>;
  switchDb: (dbName: string) => Promise<void>;
  createDb: (dbName: string) => Promise<void>;
  deleteDb: (dbName: string) => Promise<void>;
  resetApp: () => Promise<void>;
  globalSettings: {
      cardDensity: number;
      collapseCardImages: boolean;
      overviewBlockSize: 'sm' | 'md' | 'lg';
  };
  updateGlobalSettings: (settings: any) => Promise<void>;
}

const DatabaseContext = createContext<DatabaseContextType | null>(null);

export const DatabaseProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { showToast, setDbStatus } = useToast();
  const [activeDbName, setActiveDbName] = useState<string>('');
  const [userDbNames, setUserDbNames] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [dbError, setDbError] = useState<Error | null>(null);
  
  // Global Settings State
  const [globalSettings, setGlobalSettings] = useState({
      cardDensity: 75,
      collapseCardImages: false,
      overviewBlockSize: 'md' as 'sm' | 'md' | 'lg',
  });

  const isTempStorageMode = activeDbName === TEMP_STORAGE_DB_NAME_EXPORT;

  const refreshDbList = useCallback(async () => {
    const names = await dbService.listDatabases();
    setUserDbNames(names);
  }, []);

  // Initialize App
  useEffect(() => {
    const init = async () => {
      setIsLoading(true);
      try {
        await refreshDbList();
        
        // Load Global Settings
        try {
            await dbService.initDB(SETTINGS_DB_NAME);
            const [density, collapse, size] = await Promise.all([
                dbService.getByKey(SETTINGS_DB_NAME, STORES.metadata, 'cardDensity'),
                dbService.getByKey(SETTINGS_DB_NAME, STORES.metadata, 'collapseCardImages'),
                dbService.getByKey(SETTINGS_DB_NAME, STORES.metadata, 'overviewBlockSize'),
            ]);
            setGlobalSettings({
                cardDensity: density ?? 75,
                collapseCardImages: collapse ?? false,
                overviewBlockSize: size ?? 'md',
            });
        } catch (e) {
            console.warn("Failed to load settings", e);
        }

        // Determine Active DB
        const hasLaunchedBefore = localStorage.getItem('hasLaunchedBefore') === 'true';
        let targetDb = DEFAULT_DB_NAME_EXPORT;

        if (!hasLaunchedBefore) {
             localStorage.setItem('hasLaunchedBefore', 'true');
             localStorage.setItem('activeDbName', DEFAULT_DB_NAME_EXPORT);
             // Ensure default DB exists
             await dbService.initDB(DEFAULT_DB_NAME_EXPORT);
             await refreshDbList();
        } else {
            const storedDb = localStorage.getItem('activeDbName');
            const dbs = await dbService.listDatabases();
            if (storedDb && (dbs.includes(storedDb) || storedDb === DEMO_DB_NAME_EXPORT)) {
                targetDb = storedDb;
            } else if (dbs.length > 0) {
                targetDb = dbs.includes(DEFAULT_DB_NAME_EXPORT) ? DEFAULT_DB_NAME_EXPORT : dbs[0];
            } else {
                targetDb = TEMP_STORAGE_DB_NAME_EXPORT;
            }
        }
        
        setActiveDbName(targetDb);
        if (targetDb !== TEMP_STORAGE_DB_NAME_EXPORT) {
            // Attempt connection check
            await dbService.initDB(targetDb);
        }

      } catch (err) {
        console.error("Initialization error:", err);
        setDbError(err as Error);
        setDbStatus({ message: '数据库初始化失败', type: 'error' });
      } finally {
        setIsLoading(false);
      }
    };
    init();
  }, [refreshDbList, setDbStatus]);

  const switchDb = async (dbName: string) => {
      setDbStatus({ message: `正在连接到 ${dbName.replace(DB_PREFIX + '-', '')}...`, type: 'loading' });
      try {
          if (dbName !== TEMP_STORAGE_DB_NAME_EXPORT) {
              await dbService.initDB(dbName);
          }
          setActiveDbName(dbName);
          if (dbName !== TEMP_STORAGE_DB_NAME_EXPORT) {
              localStorage.setItem('activeDbName', dbName);
          } else {
              localStorage.removeItem('activeDbName');
          }
          setDbStatus({ message: '数据库已切换', type: 'success' });
          setDbError(null);
      } catch (e) {
          console.error("Switch failed", e);
          setDbError(e as Error);
          setDbStatus({ message: '无法连接到数据库', type: 'error' });
      }
  };

  const createDb = async (rawName: string) => {
      const fullName = `${DB_PREFIX}-${rawName}`;
      if (userDbNames.includes(fullName)) throw new Error("数据库已存在");
      
      await dbService.initDB(fullName);
      await refreshDbList();
      showToast(`数据库 "${rawName}" 已创建`, 'success');
  };

  const deleteDb = async (fullName: string) => {
      await dbService.deleteDatabase(fullName);
      await refreshDbList();
      
      if (activeDbName === fullName) {
          const remaining = userDbNames.filter(n => n !== fullName);
          if (remaining.includes(DEFAULT_DB_NAME_EXPORT)) {
              switchDb(DEFAULT_DB_NAME_EXPORT);
          } else if (remaining.length > 0) {
              switchDb(remaining[0]);
          } else {
              switchDb(TEMP_STORAGE_DB_NAME_EXPORT);
          }
      }
      showToast('数据库已删除', 'success');
  };

  const resetApp = async () => {
      dbService.closeAllConnections();
      const allDbs = [SETTINGS_DB_NAME, DEMO_DB_NAME_EXPORT, ...userDbNames];
      for (const db of allDbs) {
          await dbService.deleteDatabase(db);
      }
      localStorage.clear();
      window.location.reload();
  };
  
  const updateGlobalSettings = async (newSettings: any) => {
      setGlobalSettings(prev => ({ ...prev, ...newSettings }));
      // Persist individually
      try {
          if (newSettings.cardDensity !== undefined) await dbService.put(SETTINGS_DB_NAME, STORES.metadata, newSettings.cardDensity, 'cardDensity');
          if (newSettings.collapseCardImages !== undefined) await dbService.put(SETTINGS_DB_NAME, STORES.metadata, newSettings.collapseCardImages, 'collapseCardImages');
          if (newSettings.overviewBlockSize !== undefined) await dbService.put(SETTINGS_DB_NAME, STORES.metadata, newSettings.overviewBlockSize, 'overviewBlockSize');
      } catch (e) {
          console.error("Failed to save settings", e);
      }
  };

  return (
    <DatabaseContext.Provider value={{
      activeDbName,
      userDbNames,
      isTempStorageMode,
      isLoading,
      dbError,
      refreshDbList,
      switchDb,
      createDb,
      deleteDb,
      resetApp,
      globalSettings,
      updateGlobalSettings
    }}>
      {children}
    </DatabaseContext.Provider>
  );
};

export const useDatabase = () => {
  const context = useContext(DatabaseContext);
  if (!context) throw new Error("useDatabase must be used within DatabaseProvider");
  return context;
};