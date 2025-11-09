import React, { useState, useEffect } from 'react';
import Modal from './Modal';
import { PlusIcon, PencilIcon, ArchiveBoxIcon, SettingsIcon } from './icons';

interface WelcomeModalProps {
  isOpen: boolean;
  onClose: () => void;
  onEnterDemo: () => void;
}

const WelcomeModal: React.FC<WelcomeModalProps> = ({ isOpen, onClose, onEnterDemo }) => {
  const [browserName, setBrowserName] = useState('您的浏览器');

  useEffect(() => {
    if (isOpen) {
        const getBrowserName = () => {
          const userAgent = navigator.userAgent;
          if (userAgent.includes("Firefox/")) return "Firefox";
          if (userAgent.includes("Edg/")) return "Edge";
          if (userAgent.includes("Chrome/") && !userAgent.includes("Edg/")) return "Chrome";
          if (userAgent.includes("Safari/") && !userAgent.includes("Chrome/")) return "Safari";
          return "您的浏览器";
        };
        setBrowserName(getBrowserName());
    }
  }, [isOpen]);

  const Feature: React.FC<{ icon: React.ReactNode; title: string; description: string }> = ({ icon, title, description }) => (
    <div className="flex items-start gap-4">
      <div className="flex-shrink-0 w-10 h-10 bg-slate-200 dark:bg-slate-700 rounded-lg flex items-center justify-center">
        {icon}
      </div>
      <div>
        <h4 className="font-semibold text-slate-800 dark:text-slate-100">{title}</h4>
        <p className="text-sm text-slate-600 dark:text-slate-400">{description}</p>
      </div>
    </div>
  );

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="欢迎来到 埃森梅莉亚！" variant="sheet">
      <div className="space-y-6">
        <p className="text-center text-lg text-slate-600 dark:text-slate-400 -mt-2">
          一个优雅的进度跟踪器，助您掌控一切。
        </p>
        
        <div className="space-y-5">
          <Feature
            icon={<PlusIcon className="w-6 h-6 text-slate-600 dark:text-slate-300" />}
            title="1. 创建您的第一个项目"
            description="点击右下角的 “+” 按钮开始一个新的事件或目标。"
          />
          <Feature
            icon={<PencilIcon className="w-6 h-6 text-slate-600 dark:text-slate-300" />}
            title="2. 分解任务"
            description="点击一个事件卡片查看详情，然后使用“编辑步骤”按钮将其分解为可管理的步骤。"
          />
          <Feature
            icon={<ArchiveBoxIcon className="w-6 h-6 text-slate-600 dark:text-slate-300" />}
            title="3. 重用工作流程"
            description="在步骤编辑器中，您可以将常用步骤拖到“归档”中，或将一组步骤保存为“模板”以便快速复用。"
          />
           <Feature
            icon={<div className="font-bold text-lg text-slate-600 dark:text-slate-300 select-none">꾹</div>}
            title="4. 高级操作"
            description="长按任何卡片或项目以进入多选模式或打开上下文菜单，进行批量删除等操作。"
          />
          <Feature
            icon={<SettingsIcon className="w-6 h-6 text-slate-600 dark:text-slate-300" />}
            title="5. 管理您的数据"
            description="通过设置菜单，您可以创建多个数据库（例如“工作”和“个人”），并随时导入/导出您的数据。"
          />
        </div>

        <div className="mt-6 pt-4 border-t border-slate-200 dark:border-slate-700">
            <h4 className="font-semibold text-slate-800 dark:text-slate-100 mb-2">关于数据库模式</h4>
            <div className="space-y-2 text-sm text-slate-600 dark:text-slate-400">
            <p>
                <strong>临时存储:</strong> 如果没有可用的数据库（例如在隐私模式下），您的更改将临时保存在此会话中。关闭标签页将丢失数据。
            </p>
            <p>
                <strong>演示模式:</strong> 探索一个包含示例数据的预填充数据库。您在此模式下所做的任何更改都不会被保存。
            </p>
            <p>
                您可以随时通过 <strong className="text-slate-700 dark:text-slate-300">设置 &gt; 管理数据库</strong> 切换模式或创建新数据库。
            </p>
            <p className="!mt-3 pt-3 border-t border-slate-200 dark:border-slate-700/80">
                <strong className="text-slate-700 dark:text-slate-300">当前数据库位于：</strong>{browserName} 中。您的所有数据都安全地存储在本地，并且永远不会发送到任何服务器。
            </p>
            </div>
        </div>

        <div className="pt-4 space-y-3">
          <button
            onClick={onClose}
            className="w-full px-5 py-3 rounded-lg bg-slate-900 dark:bg-slate-200 text-white dark:text-slate-900 font-semibold hover:bg-slate-700 dark:hover:bg-slate-300 transition-all active:scale-95 text-base"
          >
            开始使用 (我的数据库)
          </button>
          <button
            onClick={onEnterDemo}
            className="w-full px-5 py-3 rounded-lg bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200 font-semibold hover:bg-slate-300 dark:hover:bg-slate-600 transition-all active:scale-95 text-base"
          >
            进入演示模式
          </button>
        </div>
      </div>
    </Modal>
  );
};

export default WelcomeModal;
