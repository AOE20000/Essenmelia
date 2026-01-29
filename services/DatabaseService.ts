import { Event, StepTemplate, StepSetTemplate } from '../types';

export const DB_VERSION = 1;
export const STORES = {
    events: 'events',
    tags: 'tags',
    stepTemplates: 'stepTemplates',
    stepSetTemplates: 'stepSetTemplates',
    metadata: 'metadata',
    originalImages: 'originalImages',
};
export const DB_PREFIX = 'essenmelia-db';
export const DEFAULT_DB_NAME_EXPORT = 'essenmelia-db-default';
export const DEMO_DB_NAME_EXPORT = 'essenmelia-db-demo';
export const TEMP_STORAGE_DB_NAME_EXPORT = 'essenmelia-db-temp-storage';
export const SETTINGS_DB_NAME = 'essenmelia-db-settings';

class DatabaseService {
    private connections: Map<string, IDBDatabase> = new Map();

    async initDB(dbName: string): Promise<IDBDatabase> {
        if (this.connections.has(dbName)) {
            return this.connections.get(dbName)!;
        }

        return new Promise((resolve, reject) => {
            const request = indexedDB.open(dbName, DB_VERSION);

            request.onerror = () => {
                console.error(`数据库错误 (${dbName}):`, request.error);
                reject(request.error);
            };

            request.onsuccess = (event) => {
                const dbInstance = (event.target as IDBOpenDBRequest).result;
                this.connections.set(dbName, dbInstance);
                resolve(dbInstance);
            };

            request.onupgradeneeded = (event) => {
                const dbInstance = (event.target as IDBOpenDBRequest).result;
                Object.values(STORES).forEach(storeName => {
                    if (!dbInstance.objectStoreNames.contains(storeName)) {
                        if (storeName === STORES.events || storeName === STORES.stepTemplates || storeName === STORES.stepSetTemplates) {
                            dbInstance.createObjectStore(storeName, { keyPath: 'id' });
                        } else if (storeName === STORES.originalImages) {
                            dbInstance.createObjectStore(storeName);
                        } else {
                            dbInstance.createObjectStore(storeName);
                        }
                    }
                });
            };
        });
    }

    private async getStore(dbName: string, storeName: string, mode: IDBTransactionMode): Promise<IDBObjectStore> {
        const dbInstance = await this.initDB(dbName);
        const transaction = dbInstance.transaction(storeName, mode);
        return transaction.objectStore(storeName);
    }

    async getAll<T>(dbName: string, storeName: string): Promise<T[]> {
        const store = await this.getStore(dbName, storeName, 'readonly');
        return new Promise((resolve, reject) => {
            const request = store.getAll();
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }

    async getByKey(dbName: string, storeName: string, key: IDBValidKey): Promise<any> {
        const store = await this.getStore(dbName, storeName, 'readonly');
        return new Promise((resolve, reject) => {
            const request = store.get(key);
            request.onsuccess = () => resolve(request.result);
            request.onerror = (e) => reject((e.target as IDBRequest).error);
        });
    }

    async put(dbName: string, storeName: string, value: any, key?: IDBValidKey): Promise<void> {
        const store = await this.getStore(dbName, storeName, 'readwrite');
        return new Promise((resolve, reject) => {
            const request = store.put(value, key);
            request.onsuccess = () => resolve();
            request.onerror = (e) => reject((e.target as IDBRequest).error);
        });
    }

    async delete(dbName: string, storeName: string, key: IDBValidKey): Promise<void> {
        const store = await this.getStore(dbName, storeName, 'readwrite');
        return new Promise((resolve, reject) => {
            const request = store.delete(key);
            request.onsuccess = () => resolve();
            request.onerror = (e) => reject((e.target as IDBRequest).error);
        });
    }

    async clear(dbName: string, storeName: string): Promise<void> {
        const store = await this.getStore(dbName, storeName, 'readwrite');
        return new Promise((resolve, reject) => {
            const request = store.clear();
            request.onsuccess = () => resolve();
            request.onerror = (e) => reject((e.target as IDBRequest).error);
        });
    }

    async bulkPut<T>(dbName: string, storeName: string, items: T[]): Promise<void> {
        if (items.length === 0) return;
        const store = await this.getStore(dbName, storeName, 'readwrite');
        return new Promise((resolve, reject) => {
            const transaction = store.transaction;
            transaction.oncomplete = () => resolve();
            transaction.onerror = (e) => reject((e.target as IDBRequest).error);
            items.forEach(item => store.put(item));
        });
    }
    
    async replaceAll<T>(dbName: string, storeName: string, items: T[]): Promise<void> {
        const store = await this.getStore(dbName, storeName, 'readwrite');
        return new Promise((resolve, reject) => {
            const clearReq = store.clear();
            clearReq.onerror = (e) => reject((e.target as IDBRequest).error);
            clearReq.onsuccess = () => {
                if (items.length === 0) {
                    resolve();
                    return;
                }
                const transaction = store.transaction;
                transaction.oncomplete = () => resolve();
                transaction.onerror = (e) => reject((e.target as IDBRequest).error);
                items.forEach(item => store.put(item));
            }
        });
    }

    async deleteDatabase(dbName: string): Promise<void> {
        this.connections.get(dbName)?.close();
        this.connections.delete(dbName);
        return new Promise((resolve, reject) => {
            const req = indexedDB.deleteDatabase(dbName);
            req.onsuccess = () => resolve();
            req.onerror = () => reject(req.error);
            req.onblocked = () => resolve(); // Handle blocked politely
        });
    }

    async listDatabases(): Promise<string[]> {
        if (!indexedDB.databases) return [];
        try {
            const dbs = await indexedDB.databases();
            return dbs
                .filter(db => db.name?.startsWith(DB_PREFIX) && db.name !== SETTINGS_DB_NAME)
                .map(db => db.name!);
        } catch (e) {
            console.error("Failed to list databases", e);
            return [];
        }
    }
    
    closeAllConnections() {
        this.connections.forEach(conn => conn.close());
        this.connections.clear();
    }
}

export const dbService = new DatabaseService();