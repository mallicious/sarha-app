package com.malvina.sarha_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.malvina.sarha_app/ar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openAR") {
                try {
                    val intent = Intent(this, ARActivity::class.java)
                    startActivity(intent)
                    result.success("AR opened successfully")
                } catch (e: Exception) {
                    result.error("AR_ERROR", "Failed to open AR: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}