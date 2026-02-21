package org.essenmelia

import android.content.Intent
import android.os.Bundle
import android.app.Activity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.essenmelia/intent"
    private val DEBUG_CHANNEL = "org.essenmelia/debug"
    private var pendingAction: String? = null
    private var debugChannel: MethodChannel? = null
    private var methodChannel: MethodChannel? = null
    
    // 暂存待返回结果的 Intent
    private val pendingResults = mutableMapOf<String, Intent>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        if (intent.action == "ACTION_QUICK_EVENT") {
            val action = "ACTION_QUICK_EVENT"
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("onQuickAction", action)
                pendingAction = null
            } else {
                pendingAction = action
            }
        } else if (intent.action == "org.essenmelia.INVOKE_API") {
            val method = intent.getStringExtra("method")
            val params = intent.getStringExtra("params") ?: "{}"
            val isUntrusted = intent.getBooleanExtra("isUntrusted", false)
            val requestId = intent.getStringExtra("requestId")
            
            // 如果提供了 requestId，记录这个请求以便返回结果
            if (requestId != null) {
                pendingResults[requestId] = intent
            }

            val channel = debugChannel
            if (channel != null) {
                channel.invokeMethod("invokeApi", mapOf(
                    "method" to method,
                    "params" to params,
                    "isUntrusted" to isUntrusted,
                    "requestId" to requestId
                ))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val dc = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEBUG_CHANNEL)
        debugChannel = dc

        dc.setMethodCallHandler { call, result ->
            if (call.method == "apiResult") {
                val requestId = call.argument<String>("requestId")
                val success = call.argument<Boolean>("success") ?: false
                val apiResult = call.argument<String>("result")
                val error = call.argument<String>("error")

                if (requestId != null && pendingResults.containsKey(requestId)) {
                    val resultIntent = Intent()
                    resultIntent.putExtra("requestId", requestId)
                    resultIntent.putExtra("success", success)
                    if (success) {
                        resultIntent.putExtra("result", apiResult)
                    } else {
                        resultIntent.putExtra("error", error)
                    }
                    
                    setResult(Activity.RESULT_OK, resultIntent)
                    // 如果不是由 startActivityForResult 启动的，setResult 可能无效
                    // 但这里作为标准的 API 返回逻辑保留
                    pendingResults.remove(requestId)
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        
        // 延迟发送初始 Intent，确保 Flutter 端 listener 已挂载
        Handler(Looper.getMainLooper()).postDelayed({
            pendingAction?.let { action ->
                methodChannel?.invokeMethod("onQuickAction", action)
                pendingAction = null
            }
        }, 800)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel = null
        debugChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
