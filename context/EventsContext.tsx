import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { Event, StepTemplate, StepSetTemplate, ProgressStep, DEFAULT_ANIMATED_PLACEHOLDER } from '../types';
import { dbService, STORES, DEMO_DB_NAME_EXPORT, DEFAULT_DB_NAME_EXPORT } from '../services/DatabaseService';
import { useDatabase } from './DatabaseContext';
import { useToast } from './ToastContext';

// --- Demo Data Generation ---
const createTimestamp = (daysOffset: number) => {
    const date = new Date();
    date.setDate(date.getDate() + daysOffset);
    return date;
};

const demoEvents: Event[] = [
    {
        id: 'demo-event-1',
        title: '葬送的芙莉莲：旅途的终点',
        description: '记录追番进度。感受时间流逝的魔法，探讨寿命论与回忆的重量。',
        createdAt: createTimestamp(-30),
        imageUrl: DEFAULT_ANIMATED_PLACEHOLDER,
        tags: ['追番', '治愈', '史诗'],
        steps: [
            { id: 's1-1', description: '第1话：冒险的结束', timestamp: createTimestamp(-29), completed: true },
            { id: 's1-2', description: '第2话：魔法师的谎言', timestamp: createTimestamp(-28), completed: true },
            { id: 's1-3', description: '第3话：杀人魔法', timestamp: createTimestamp(-27), completed: true },
            { id: 's1-4', description: '第4话：魂眠之地', timestamp: createTimestamp(-20), completed: true },
            { id: 's1-5', description: '第5话：死者之幻影', timestamp: createTimestamp(-15), completed: true },
            { id: 's1-6', description: '第6话：村里的英雄', timestamp: createTimestamp(-10), completed: false },
            { id: 's1-7', description: '第7话：就像童话一样', timestamp: createTimestamp(-5), completed: false },
        ]
    },
    {
        id: 'demo-event-2',
        title: '构建奥术尖塔 (个人博客重构)',
        description: '使用 Next.js 和 Tailwind CSS 重构个人数字花园。目标是实现全静态生成与极致的性能评分。',
        createdAt: createTimestamp(-15),
        imageUrl: DEFAULT_ANIMATED_PLACEHOLDER,
        tags: ['开发', '创造', '代码'],
        steps: [
            { id: 's2-1', description: '构思：绘制 UI 设计草图', timestamp: createTimestamp(-14), completed: true },
            { id: 's2-2', description: '基石：搭建 Next.js 14 环境', timestamp: createTimestamp(-13), completed: true },
            { id: 's2-3', description: '结构：设计 MDX 内容层', timestamp: createTimestamp(-10), completed: true },
            { id: 's2-4', description: '外观：实现暗色模式主题', timestamp: createTimestamp(-8), completed: false },
            { id: 's2-5', description: '魔法：添加 Framer Motion 动画', timestamp: createTimestamp(-5), completed: false },
            { id: 's2-6', description: '封顶：部署至 Vercel', timestamp: createTimestamp(-1), completed: false },
        ]
    },
    {
        id: 'demo-event-3',
        title: '探索：打造阳台上的生态雨林',
        description: '在钢筋水泥的森林中开辟一方净土，建立一个自维持的植物生态系统。',
        createdAt: createTimestamp(-60),
        imageUrl: DEFAULT_ANIMATED_PLACEHOLDER,
        tags: ['生活', '自然', '园艺'],
        steps: [
            { id: 's3-1', description: '规划：测量光照与空间', timestamp: createTimestamp(-55), completed: true },
            { id: 's3-2', description: '采购：寻找适合的基质与容器', timestamp: createTimestamp(-50), completed: true },
            { id: 's3-3', description: '选种：收集蕨类与苔藓', timestamp: createTimestamp(-45), completed: true },
            { id: 's3-4', description: '构建：铺设排水层与景观石', timestamp: createTimestamp(-20), completed: true },
            { id: 's3-5', description: '种植：定植核心植物', timestamp: createTimestamp(5), completed: false },
            { id: 's3-6', description: '维护：建立微循环系统', timestamp: createTimestamp(6), completed: false },
            { id: 's3-7', description: '观察：记录第一片新叶', timestamp: createTimestamp(10), completed: false },
        ]
    },
    {
        id: 'demo-event-4',
        title: '特训：30天核心肌群重塑',
        description: '为了找回失去的腰线，开启一段汗水与坚持的旅程。',
        createdAt: createTimestamp(-5),
        imageUrl: DEFAULT_ANIMATED_PLACEHOLDER,
        tags: ['健康', '运动', '挑战'],
        steps: [
            { id: 's4-1', description: '评估：记录初始体脂率', timestamp: createTimestamp(-4), completed: true },
            { id: 's4-2', description: '基础：掌握平板支撑的正确姿势', timestamp: createTimestamp(-3), completed: false },
            { id: 's4-3', description: '进阶：卷腹与俄罗斯转体', timestamp: createTimestamp(-2), completed: false },
            { id: 's4-4', description: '冲刺：高强度间歇训练 (HIIT)', timestamp: createTimestamp(-1), completed: false },
        ]
    }
];

const tutorialEvent: Event = {
    id: 'event-tutorial-1', 
    title: "新手导览：探索埃森梅莉亚", 
    description: "欢迎，旅行者。这是一份遗留的卷轴，指引你熟悉这里的操作。请尝试点击下方的步骤来点亮它们。", 
    createdAt: new Date(), 
    tags: ['教程', '指引'], 
    imageUrl: DEFAULT_ANIMATED_PLACEHOLDER,
    steps: [
        { id: 't-1', description: '点击此行文字将步骤标记为“已完成”', timestamp: new Date(), completed: false },
        { id: 't-2', description: '长按任意卡片可进入“多选模式”', timestamp: new Date(), completed: false },
        { id: 't-3', description: '点击右上角的“规划步骤”来修改这些内容', timestamp: new Date(), completed: false },
        { id: 't-4', description: '在设置中备份你的档案以防丢失', timestamp: new Date(), completed: false },
    ], 
};

// Types
type PendingAction =
  | { type: 'ADD_EVENT'; payload: { event: Event, originalImage?: File } }
  | { type: 'UPDATE_EVENT'; payload: { event: Event, originalImage?: File | 'remove' } }
  | { type: 'DELETE_EVENT'; payload: string }
  | { type: 'UPDATE_EVENT_STEPS'; payload: { eventId: string; steps: ProgressStep[] } }
  | { type: 'ADD_TAG'; payload: string }
  | { type: 'DELETE_TAGS'; payload: string[] }
  | { type: 'RENAME_TAG'; payload: { oldTag: string; newTag: string } }
  | { type: 'REORDER_TAGS'; payload: string[] }
  | { type: 'UPDATE_TEMPLATES'; payload: StepTemplate[] }
  | { type: 'UPDATE_SETS'; payload: StepSetTemplate[] };

interface EventsContextType {
  events: Event[];
  tags: string[];
  stepTemplates: StepTemplate[];
  stepSetTemplates: StepSetTemplate[];
  isSyncing: boolean;
  isLoading: boolean;
  addEvent: (event: Event, originalImage?: File) => void;
  updateEvent: (event: Event, originalImage?: File | 'remove') => void;
  deleteEvent: (eventId: string) => void;
  updateEventSteps: (eventId: string, steps: ProgressStep[]) => void;
  addTag: (tag: string) => void;
  deleteTags: (tags: string[]) => void;
  renameTag: (oldTag: string, newTag: string) => boolean;
  reorderTags: (tags: string[]) => void;
  updateStepTemplates: (templates: StepTemplate[]) => void;
  updateStepSetTemplates: (templates: StepSetTemplate[]) => void;
  getOriginalImage: (eventId: string) => Promise<File | undefined>;
}

const EventsContext = createContext<EventsContextType | null>(null);

export const EventsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { activeDbName, isTempStorageMode, dbError, isLoading: isDbLoading } = useDatabase();
  const { showToast, setDbStatus } = useToast();

  const [events, setEvents] = useState<Event[]>([]);
  const [tags, setTags] = useState<string[]>([]);
  const [stepTemplates, setStepTemplates] = useState<StepTemplate[]>([]);
  const [stepSetTemplates, setStepSetTemplates] = useState<StepSetTemplate[]>([]);
  const [pendingActions, setPendingActions] = useState<PendingAction[]>([]);
  const [isSyncing, setIsSyncing] = useState(false);

  // Helper to process date strings back to Date objects
  const reviveEvents = (list: any[]): Event[] => list.map(e => ({
      ...e,
      createdAt: new Date(e.createdAt),
      steps: e.steps.map((s: any) => ({ ...s, timestamp: new Date(s.timestamp) }))
  }));

  // Load Data
  useEffect(() => {
    if (isDbLoading || !activeDbName) return;

    const load = async () => {
      if (activeDbName === DEMO_DB_NAME_EXPORT) {
          setEvents(demoEvents); 
          setTags(['追番', '治愈', '史诗', '开发', '创造', '代码', '生活', '自然', '园艺', '健康', '运动', '挑战']);
          setStepTemplates([
              {id: 'tpl-1', description: '撰写大纲'},
              {id: 'tpl-2', description: '绘制草图'},
              {id: 'tpl-3', description: '最终润色'},
          ]);
          setStepSetTemplates([
              { id: 'set-1', name: '追番通用模板 (12集)', steps: Array.from({length: 12}, (_, i) => ({ id: `ep-${i+1}`, description: `第${i+1}话` })) }
          ]);
          return;
      }

      if (isTempStorageMode) {
          setEvents([]); setTags([]); setStepTemplates([]); setStepSetTemplates([]);
          return;
      }

      try {
          // Check seeding
          const isSeeded = await dbService.getByKey(activeDbName, STORES.metadata, 'isSeeded');
          if (!isSeeded && activeDbName === DEFAULT_DB_NAME_EXPORT) {
              await dbService.bulkPut(activeDbName, STORES.events, [tutorialEvent]);
              await dbService.put(activeDbName, STORES.tags, ['教程', '指引'], 'allTags');
              await dbService.put(activeDbName, STORES.metadata, true, 'isSeeded');
          } else if (!isSeeded) {
              await dbService.put(activeDbName, STORES.metadata, true, 'isSeeded');
          }

          const [e, t, st, sst] = await Promise.all([
              dbService.getAll<Event>(activeDbName, STORES.events),
              dbService.getByKey(activeDbName, STORES.tags, 'allTags'),
              dbService.getAll<StepTemplate>(activeDbName, STORES.stepTemplates),
              dbService.getAll<StepSetTemplate>(activeDbName, STORES.stepSetTemplates),
          ]);
          
          setEvents(reviveEvents(e));
          setTags(t || []);
          setStepTemplates(st);
          setStepSetTemplates(sst);
      } catch (err) {
          console.error("Failed to load events", err);
          showToast("数据加载失败", 'error');
      }
    };
    load();
  }, [activeDbName, isTempStorageMode, isDbLoading, showToast]);

  // Pending Action Processor / Sync
  useEffect(() => {
      if (pendingActions.length === 0 || isDbLoading || isTempStorageMode || activeDbName === DEMO_DB_NAME_EXPORT || dbError) return;

      const sync = async () => {
          setIsSyncing(true);
          setDbStatus({ message: '正在铭刻...', type: 'loading' });
          
          const actionsToProcess = [...pendingActions];
          setPendingActions([]); // Optimistic clear

          try {
              for (const action of actionsToProcess) {
                  switch(action.type) {
                      case 'ADD_EVENT':
                      case 'UPDATE_EVENT':
                          await dbService.put(activeDbName, STORES.events, action.payload.event);
                          if (action.payload.originalImage === 'remove') {
                              await dbService.delete(activeDbName, STORES.originalImages, action.payload.event.id);
                          } else if (action.payload.originalImage) {
                              await dbService.put(activeDbName, STORES.originalImages, action.payload.originalImage, action.payload.event.id);
                          }
                          break;
                      case 'DELETE_EVENT':
                          await dbService.delete(activeDbName, STORES.events, action.payload);
                          await dbService.delete(activeDbName, STORES.originalImages, action.payload);
                          break;
                      case 'UPDATE_EVENT_STEPS':
                          const evt = events.find(e => e.id === action.payload.eventId);
                          if (evt) await dbService.put(activeDbName, STORES.events, { ...evt, steps: action.payload.steps });
                          break;
                      case 'ADD_TAG':
                      case 'DELETE_TAGS':
                      case 'RENAME_TAG':
                      case 'REORDER_TAGS':
                          await dbService.put(activeDbName, STORES.tags, tags, 'allTags');
                          if (action.type === 'DELETE_TAGS' || action.type === 'RENAME_TAG') {
                              await dbService.bulkPut(activeDbName, STORES.events, events);
                          }
                          break;
                      case 'UPDATE_TEMPLATES':
                          await dbService.replaceAll(activeDbName, STORES.stepTemplates, action.payload);
                          break;
                      case 'UPDATE_SETS':
                          await dbService.replaceAll(activeDbName, STORES.stepSetTemplates, action.payload);
                          break;
                  }
              }
              setDbStatus({ message: '铭刻完成', type: 'success' });
          } catch (e) {
              console.error("Sync failed", e);
              setPendingActions(prev => [...actionsToProcess, ...prev]); // Revert
              setDbStatus({ message: '铭刻受阻', type: 'error' });
          } finally {
              setIsSyncing(false);
          }
      };
      
      const timer = setTimeout(sync, 500); // Debounce
      return () => clearTimeout(timer);
  }, [pendingActions, activeDbName, isTempStorageMode, isDbLoading, dbError, events, tags, setDbStatus]);


  // --- Actions ---

  const addEvent = (event: Event, originalImage?: File) => {
      setEvents(prev => [event, ...prev]);
      setPendingActions(prev => [...prev, { type: 'ADD_EVENT', payload: { event, originalImage } }]);
      
      // Auto-add new tags
      const newTags = event.tags?.filter(t => !tags.includes(t)) || [];
      if(newTags.length > 0) {
          setTags(prev => [...prev, ...newTags]);
          setPendingActions(prev => [...prev, ...newTags.map(t => ({ type: 'ADD_TAG' as const, payload: t }))]);
      }
  };

  const updateEvent = (updatedEvent: Event, originalImage?: File | 'remove') => {
      setEvents(prev => prev.map(e => e.id === updatedEvent.id ? updatedEvent : e));
      setPendingActions(prev => [...prev, { type: 'UPDATE_EVENT', payload: { event: updatedEvent, originalImage } }]);
      
      const newTags = updatedEvent.tags?.filter(t => !tags.includes(t)) || [];
      if(newTags.length > 0) {
          setTags(prev => [...prev, ...newTags]);
          setPendingActions(prev => [...prev, ...newTags.map(t => ({ type: 'ADD_TAG' as const, payload: t }))]);
      }
  };

  const deleteEvent = (eventId: string) => {
      setEvents(prev => prev.filter(e => e.id !== eventId));
      setPendingActions(prev => [...prev, { type: 'DELETE_EVENT', payload: eventId }]);
  };

  const updateEventSteps = (eventId: string, newSteps: ProgressStep[]) => {
      setEvents(prev => prev.map(e => e.id === eventId ? { ...e, steps: newSteps } : e));
      setPendingActions(prev => [...prev, { type: 'UPDATE_EVENT_STEPS', payload: { eventId, steps: newSteps } }]);
  };

  const addTag = (tag: string) => {
      if(tags.includes(tag)) return;
      setTags(prev => [...prev, tag]);
      setPendingActions(prev => [...prev, { type: 'ADD_TAG', payload: tag }]);
  };

  const deleteTags = (tagsToDelete: string[]) => {
      const deleteSet = new Set(tagsToDelete);
      setTags(prev => prev.filter(t => !deleteSet.has(t)));
      setEvents(prev => prev.map(e => ({ ...e, tags: e.tags?.filter(t => !deleteSet.has(t)) })));
      setPendingActions(prev => [...prev, { type: 'DELETE_TAGS', payload: tagsToDelete }]);
  };

  const renameTag = (oldTag: string, newTag: string) => {
      if (tags.includes(newTag) && newTag !== oldTag) return false;
      setTags(prev => prev.map(t => t === oldTag ? newTag : t));
      setEvents(prev => prev.map(e => ({ ...e, tags: e.tags?.map(t => t === oldTag ? newTag : t) })));
      setPendingActions(prev => [...prev, { type: 'RENAME_TAG', payload: { oldTag, newTag } }]);
      return true;
  };

  const reorderTags = (newTags: string[]) => {
      setTags(newTags);
      setPendingActions(prev => [...prev, { type: 'REORDER_TAGS', payload: newTags }]);
  };

  const updateStepTemplates = (newTemplates: StepTemplate[]) => {
      setStepTemplates(newTemplates);
      setPendingActions(prev => [...prev, { type: 'UPDATE_TEMPLATES', payload: newTemplates }]);
  };

  const updateStepSetTemplates = (newTemplates: StepSetTemplate[]) => {
      setStepSetTemplates(newTemplates);
      setPendingActions(prev => [...prev, { type: 'UPDATE_SETS', payload: newTemplates }]);
  };

  const getOriginalImage = async (eventId: string) => {
      if (activeDbName === DEMO_DB_NAME_EXPORT || isTempStorageMode) return undefined;
      return dbService.getByKey(activeDbName, STORES.originalImages, eventId);
  };

  return (
    <EventsContext.Provider value={{
      events, tags, stepTemplates, stepSetTemplates, isSyncing,
      isLoading: isDbLoading, // Include isLoading here
      addEvent, updateEvent, deleteEvent, updateEventSteps,
      addTag, deleteTags, renameTag, reorderTags,
      updateStepTemplates, updateStepSetTemplates,
      getOriginalImage
    }}>
      {children}
    </EventsContext.Provider>
  );
};

export const useEvents = () => {
  const context = useContext(EventsContext);
  if (!context) throw new Error("useEvents must be used within EventsProvider");
  return context;
};