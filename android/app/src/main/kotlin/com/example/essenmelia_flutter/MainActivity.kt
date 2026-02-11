package com.example.essenmelia_flutter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.essenmelia/intent"
    private var pendingAction: String? = null

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
            pendingAction = "ACTION_QUICK_EVENT"
            // 如果引擎已经加载，可以直接发送通知
            flutterEngine?.let {
                MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onNewIntent", pendingAction)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialIntent") {
                result.success(pendingAction)
                pendingAction = null // 消费掉
            } else {
                result.notImplemented()
            }
        }
    }
}
