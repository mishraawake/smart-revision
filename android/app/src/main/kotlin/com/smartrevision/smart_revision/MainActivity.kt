package com.smartrevision.smart_revision

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the system share sheet (WhatsApp, SMS, ...) with plain text.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "revup/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") return@setMethodCallHandler result.notImplemented()
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                }
                startActivity(Intent.createChooser(send, null))
                result.success(true)
            }
    }
}
