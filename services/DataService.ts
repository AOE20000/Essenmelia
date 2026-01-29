import { dbService, STORES } from './DatabaseService';
import { Event, StepTemplate, StepSetTemplate } from '../types';

export const exportDatabase = async (dbName: string): Promise<void> => {
  try {
    const [events, tags, stepTemplates, stepSetTemplates] = await Promise.all([
      dbService.getAll<Event>(dbName, STORES.events),
      dbService.getByKey(dbName, STORES.tags, 'allTags'),
      dbService.getAll<StepTemplate>(dbName, STORES.stepTemplates),
      dbService.getAll<StepSetTemplate>(dbName, STORES.stepSetTemplates),
    ]);

    const data = {
      version: 1,
      timestamp: new Date().toISOString(),
      events,
      tags: tags || [],
      stepTemplates,
      stepSetTemplates,
    };

    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `essenmelia-backup-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Export failed:', error);
    throw new Error('导出数据失败');
  }
};

export const importDatabase = async (dbName: string, file: File): Promise<void> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = async (e) => {
      try {
        const result = e.target?.result as string;
        const data = JSON.parse(result);

        if (!data || !data.events) {
          throw new Error('无效的数据格式');
        }

        // 恢复日期对象
        const reviveEvent = (evt: any): Event => ({
            ...evt,
            createdAt: new Date(evt.createdAt),
            steps: evt.steps.map((s: any) => ({ ...s, timestamp: new Date(s.timestamp) }))
        });

        const events = (data.events as any[]).map(reviveEvent);
        const tags = data.tags || [];
        const stepTemplates = data.stepTemplates || [];
        const stepSetTemplates = data.stepSetTemplates || [];

        // 导入数据 (使用 bulkPut 或 put 逐个添加，这里简单起见假设我们想保留现有数据并添加新的)
        // 注意：ID 冲突会覆盖
        if (events.length > 0) await dbService.bulkPut(dbName, STORES.events, events);
        if (stepTemplates.length > 0) await dbService.bulkPut(dbName, STORES.stepTemplates, stepTemplates);
        if (stepSetTemplates.length > 0) await dbService.bulkPut(dbName, STORES.stepSetTemplates, stepSetTemplates);
        
        // Tags 是单个 key 存储的，需要合并
        const currentTags = (await dbService.getByKey(dbName, STORES.tags, 'allTags')) || [];
        const newTags = Array.from(new Set([...currentTags, ...tags]));
        await dbService.put(dbName, STORES.tags, newTags, 'allTags');

        resolve();
      } catch (error) {
        console.error('Import failed:', error);
        reject(error);
      }
    };
    reader.onerror = () => reject(new Error('读取文件失败'));
    reader.readAsText(file);
  });
};