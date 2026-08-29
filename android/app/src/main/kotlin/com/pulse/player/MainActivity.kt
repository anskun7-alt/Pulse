package com.pulse.player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.pulse.player/media_intent"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger, CHANNEL
    ).setMethodCallHandler { call, result ->
      if (call.method == "getInitialFile") {
        result.success(intent?.data?.toString())
      } else {
        result.notImplemented()
      }
    }
  }

  override fun onNewIntent(intent: android.content.Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val uri = intent.data?.toString() ?: return
    flutterEngine?.let {
      MethodChannel(
        it.dartExecutor.binaryMessenger, CHANNEL
      ).invokeMethod("onNewFile", uri)
    }
  }
}
