package com.duesapp.dues

import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.net.Uri
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.duesapp.dues/sms"
    private val smsPermissionRequest = 9012
    private var permissionResult: MethodChannel.Result? = null
    private var printSoundPool: SoundPool? = null
    private var printSoundId = 0
    private var printStreamId = 0
    private var printSoundLoaded = false
    private var playPrintWhenLoaded = false

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.duesapp.dues/receipt_audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        playPrintSound()
                        result.success(null)
                    }
                    "stop" -> {
                        stopPrintSound()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playPrintSound() {
        if (printSoundPool == null) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            printSoundPool = SoundPool.Builder()
                .setMaxStreams(1)
                .setAudioAttributes(attributes)
                .build()
                .also { pool ->
                    pool.setOnLoadCompleteListener { loadedPool, sampleId, status ->
                        printSoundLoaded = status == 0 && sampleId == printSoundId
                        if (printSoundLoaded && playPrintWhenLoaded) {
                            playPrintWhenLoaded = false
                            printStreamId = loadedPool.play(sampleId, 1f, 1f, 1, 0, 1f)
                        }
                    }
                    printSoundId = pool.load(this, R.raw.receipt_print, 1)
                }
        }
        stopPrintSound()
        if (printSoundLoaded) {
            printStreamId = printSoundPool?.play(printSoundId, 1f, 1f, 1, 0, 1f) ?: 0
        } else {
            playPrintWhenLoaded = true
        }
    }

    private fun stopPrintSound() {
        playPrintWhenLoaded = false
        if (printStreamId != 0) {
            printSoundPool?.stop(printStreamId)
            printStreamId = 0
        }
    }

    override fun onStop() {
        stopPrintSound()
        super.onStop()
    }

    override fun onDestroy() {
        stopPrintSound()
        printSoundPool?.release()
        printSoundPool = null
        super.onDestroy()
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
