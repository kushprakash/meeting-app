package com.bestrecharge.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val EASEBUZZ_METHOD_CHANNEL = "com.bestrecharge.app/easebuzz_pg"
        const val EASEBUZZ_REQUEST_CODE = 9088
    }

    private var easebuzzMethodChannel: MethodChannel? = null
    private var pendingEasebuzzResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == EASEBUZZ_REQUEST_CODE) {
            val pendingResult = pendingEasebuzzResult
            pendingEasebuzzResult = null
            if (pendingResult != null) {
                try {
                    val responseMap = hashMapOf<String, Any?>()
                    if (data != null) {
                        val resultStr = data.getStringExtra("result") ?: ""
                        val paymentResponseStr = data.getStringExtra("payment_response") ?: ""
                        responseMap["result"] = resultStr
                        responseMap["payment_response"] = paymentResponseStr
                    } else {
                        responseMap["result"] = "user_cancelled"
                        responseMap["payment_response"] = "No response data"
                    }
                    pendingResult.success(responseMap)
                } catch (e: Exception) {
                    Log.e("EASEBUZZ_PG", "Error returning result from onActivityResult", e)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        easebuzzMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EASEBUZZ_METHOD_CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "payWithEasebuzz" -> {
                        val accessKey = call.argument<String>("access_key")
                        val env = call.argument<String>("pay_mode") ?: call.argument<String>("env") ?: "test"
                        
                        if (accessKey.isNullOrEmpty()) {
                            result.error("INVALID_ARGUMENT", "access_key is required", null)
                            return@setMethodCallHandler
                        }

                        // Clear any previous pending result to ensure subsequent payment attempts always launch cleanly
                        try {
                            pendingEasebuzzResult?.success(mapOf("result" to "user_cancelled", "payment_response" to "Overridden"))
                        } catch (_: Exception) {}

                        try {
                            pendingEasebuzzResult = result
                            val payMode = if (env.equals("prod", ignoreCase = true) || env.equals("production", ignoreCase = true)) {
                                "production"
                            } else {
                                "test"
                            }

                            val intent = Intent(this@MainActivity, com.easebuzz.payment.kit.PWECouponsActivity::class.java).apply {
                                putExtra("access_key", accessKey)
                                putExtra("pay_mode", payMode)
                            }
                            startActivityForResult(intent, EASEBUZZ_REQUEST_CODE)
                        } catch (e: Exception) {
                            Log.e("EASEBUZZ_PG", "Error launching Easebuzz SDK", e)
                            pendingEasebuzzResult = null
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        easebuzzMethodChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }
}
