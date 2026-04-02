package com.example.kidreminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED || 
            intent?.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            context?.let { ctx ->
                // 在后台启动 Flutter 引擎并调用恢复闹钟的方法
                try {
                    val flutterEngine = FlutterEngine(ctx)
                    flutterEngine.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint.createDefault()
                    )
                    
                    // 调用 Flutter 端的恢复方法
                    val channel = MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.example.kidreminder/boot"
                    )
                    
                    channel.invokeMethod("rescheduleNotifications", null, object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            // 恢复成功，清理引擎
                            flutterEngine.destroy()
                        }
                        
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            // 恢复失败，记录日志
                            android.util.Log.e("BootReceiver", "Failed to reschedule: $errorMessage")
                            flutterEngine.destroy()
                        }
                        
                        override fun notImplemented() {
                            android.util.Log.e("BootReceiver", "Method not implemented")
                            flutterEngine.destroy()
                        }
                    })
                } catch (e: Exception) {
                    android.util.Log.e("BootReceiver", "Error starting Flutter engine: ${e.message}")
                }
            }
        }
    }
}