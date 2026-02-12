package com.example.essenmelia_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.essenmelia/intent"
    private var pendingAction: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == "ACTION_QUICK_EVENT") {
            val action = "ACTION_QUICK_EVENT"
            val channel = methodChannel
            if (channel != null) {
                // 如果 Channel 已经就绪，立即发送并清除状态
                channel.invokeMethod("onQuickAction", action)
                pendingAction = null
            } else {
                // 否则暂存，等待 configureFlutterEngine 中的延迟任务处理
                pendingAction = action
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // 延迟发送初始 Intent，确保 Flutter 端 listener 已挂载
        Handler(Looper.getMainLooper()).postDelayed({
            pendingAction?.let { action ->
                methodChannel?.invokeMethod("onQuickAction", action)
                pendingAction = null
            }
        }, 800) // 稍微增加延迟以确保万无一失
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
