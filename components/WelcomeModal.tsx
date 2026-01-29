import React, { useState, useEffect } from 'react';
import { PlusIcon, PencilIcon, ArchiveBoxIcon, SettingsIcon } from './icons';

interface WelcomeModalProps {
  onClose: () => void;
  onEnterDemo: () => void;
}

const WelcomeModal: React.FC<WelcomeModalProps> = ({ onClose, onEnterDemo }) => {
  const [browserName, setBrowserName] = useState('您的浏览器');

  useEffect(() => {
      const getBrowserName = () => {
        const userAgent = navigator.userAgent;
        if (userAgent.includes("Firefox/")) return "Firefox";
        if (userAgent.includes("Edg/")) return "Edge";
        if (userAgent.includes("Chrome/") && !userAgent.includes("Edg/")) return "Chrome";
        if (userAgent.includes("Safari/") && !userAgent.includes("Chrome/")) return "Safari";
        return "您的浏览器";
      };
      setBrowserName(getBrowserName());
  }, []);

  const Feature: React.FC<{ icon: React.ReactNode; title: string; description: string; color: string }> = ({ icon, title, description, color }) => (
    <div className="flex items-start gap-4 p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors">
      <div className={`flex-shrink-0 w-12 h-12 rounded-2xl flex items-center justify-center shadow-sm text-white ${color}`}>
        {icon}
      </div>
      <div>
        <h4 className="font-bold text-slate-900 dark:text-slate-100">{title}</h4>
        <p className="text-sm text-slate-600 dark:text-slate-400 leading-relaxed mt-1">{description}</p>
      </div>
    </div>
  );

  return (
    <div className="space-y-8">
      <div className="text-center">
          <h2 className="text-3xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-brand-600 to-purple-600 dark:from-brand-300 dark:to-purple-300">
            欢迎来到 Essenmelia 档案馆
          </h2>
          <p className="mt-2 text-lg text-slate-600 dark:text-slate-400">
            编织你的史诗，铭刻你的旅程。
          </p>
      </div>
      
      <div className="space-y-2">
        <Feature
          icon={<PlusIcon className="w-6 h-6" />}
          title="1. 开启新编年史"
          description="点击右下角的法阵（+按钮）开始记录一个新的事件、故事或目标。"
          color="bg-gradient-to-br from-blue-500 to-blue-600"
        />
        <Feature
          icon={<PencilIcon className="w-6 h-6" />}
          title="2. 拆解符文步骤"
          description="点击卡片进入详情，使用“规划步骤”将宏大的任务拆解为可执行的节点。"
          color="bg-gradient-to-br from-purple-500 to-purple-600"
        />
        <Feature
          icon={<ArchiveBoxIcon className="w-6 h-6" />}
          title="3. 传承智慧"
          description="将常用的流程拖入“归档”或保存为模板，在未来的旅程中复用这些智慧。"
          color="bg-gradient-to-br from-orange-500 to-orange-600"
        />
         <Feature
          icon={<div className="font-bold text-xl select-none">꾹</div>}
          title="4. 掌控之力"
          description="长按卡片或列表项以进入多选模式，批量管理你的档案。"
          color="bg-gradient-to-br from-slate-600 to-slate-700"
        />
      </div>

      <div className="p-4 rounded-xl bg-slate-100 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700">
          <div className="flex items-center gap-2 mb-2">
             <SettingsIcon className="w-5 h-5 text-slate-500" />
             <h4 className="font-bold text-slate-800 dark:text-slate-200 text-sm">位面存储说明</h4>
          </div>
          <div className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
            <p>您的所有数据都安全地封存在 <strong>{browserName}</strong> 的本地水晶（数据库）中，绝不会通过星界传送（上传）至任何服务器。您随时可以在设置中导出档案备份。</p>
          </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
        <button
          onClick={onEnterDemo}
          className="w-full px-5 py-3.5 rounded-xl bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 font-bold hover:bg-slate-300 dark:hover:bg-slate-600 transition-all active:scale-95"
        >
          参观演示档案馆
        </button>
        <button
          onClick={onClose}
          className="w-full px-5 py-3.5 rounded-xl bg-gradient-to-r from-brand-600 to-brand-500 text-white font-bold hover:shadow-lg hover:shadow-brand-500/30 transition-all active:scale-95"
        >
          开始铭刻
        </button>
      </div>
    </div>
  );
};

export default WelcomeModal;