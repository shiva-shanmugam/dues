package com.duesapp.dues

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.duesapp.dues/sms"
    private val smsPermissionRequest = 9012
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.duesapp.dues/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "openSettings") {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null))
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("SETTINGS_UNAVAILABLE", error.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleSmsCall)
    }

    private fun handleSmsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasSmsPermission())
            "requestPermission" -> requestSmsPermission(result)
            "readInbox" -> readInbox(call.argument<Int>("limit") ?: 2000, result)
            else -> result.notImplemented()
        }
    }

    private fun hasSmsPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "An SMS permission request is already active", null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_SMS), smsPermissionRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == smsPermissionRequest) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    private fun readInbox(limit: Int, result: MethodChannel.Result) {
        if (!hasSmsPermission()) {
            result.error("PERMISSION_DENIED", "READ_SMS permission is required", null)
            return
        }
        try {
            val messages = mutableListOf<Map<String, Any>>()
            val projection = arrayOf("_id", "address", "body", "date")
            val sortOrder = "date DESC LIMIT ${limit.coerceIn(1, 5000)}"
            contentResolver.query(
                Uri.parse("content://sms/inbox"),
                projection,
                null,
                null,
                sortOrder,
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow("_id")
                val senderIndex = cursor.getColumnIndexOrThrow("address")
                val bodyIndex = cursor.getColumnIndexOrThrow("body")
                val dateIndex = cursor.getColumnIndexOrThrow("date")
                while (cursor.moveToNext()) {
                    messages.add(
                        mapOf(
                            "id" to cursor.getString(idIndex),
                            "sender" to (cursor.getString(senderIndex) ?: "Unknown"),
                            "body" to (cursor.getString(bodyIndex) ?: ""),
                            "date" to cursor.getLong(dateIndex),
                        ),
                    )
                }
            }
            result.success(messages)
        } catch (error: Exception) {
            result.error("SMS_READ_FAILED", error.message, null)
        }
    }
}
