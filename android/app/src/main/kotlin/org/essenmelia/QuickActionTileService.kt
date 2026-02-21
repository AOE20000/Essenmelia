package org.essenmelia

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService

class QuickActionTileService : TileService() {
    override fun onClick() {
        super.onClick()
        
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "ACTION_QUICK_EVENT"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 
            0, 
            intent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // 针对不同 Android 版本的 Activity 启动适配
        if (Build.VERSION.SDK_INT >= 34) { // Android 14+
            startActivityAndCollapse(pendingIntent)
        } else {
            if (isLocked) {
                unlockAndRun {
                    @Suppress("DEPRECATION")
                    startActivityAndCollapse(intent)
                }
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        // 移除冗余的 updateTile() 调用。
        // 如果标签是静态的，已经在 AndroidManifest 中定义，
        // 这里频繁调用 updateTile() 会在下拉通知栏时触发系统重复渲染，导致卡顿。
    }
}
