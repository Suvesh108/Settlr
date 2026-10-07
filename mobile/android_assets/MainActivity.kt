package com.settlr.settlr_mobile

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val UPDATER_CHANNEL = "com.settlr.updater"
    private val SMS_CHANNEL = "com.settlr.sms"
    private val SMS_PERMISSION_CODE = 1001

    private var smsChannel: MethodChannel? = null
    private var smsReceiver: BroadcastReceiver? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. In-App Updater Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
                            return@setMethodCallHandler
                        }
                        val context = applicationContext
                        val uri: Uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                        }
                        val resInfoList = context.packageManager.queryIntentActivities(
                            intent,
                            PackageManager.MATCH_DEFAULT_ONLY
                        )
                        for (resolveInfo in resInfoList) {
                            val packageName = resolveInfo.activityInfo.packageName
                            context.grantUriPermission(packageName, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
                    }
                } else {
                    result.error("INVALID_PATH", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Native SMS Detection Channel
        smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    if (hasReceive && hasRead) {
                        registerSmsReceiver()
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                            SMS_PERMISSION_CODE
                        )
                    }
                }
                "checkSmsPermission" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(hasReceive)
                }
                "getLatestSms" -> {
                    try {
                        val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        if (!hasRead) {
                            result.success(emptyList<Map<String, Any>>())
                            return@setMethodCallHandler
                        }
                        // Strictly query SMS received in the last 120 seconds to prevent detecting old past bills
                        val twoMinutesAgo = System.currentTimeMillis() - (120 * 1000)
                        val cursor = contentResolver.query(
                            Uri.parse("content://sms/inbox"),
                            arrayOf("body", "address", "date"),
                            "date >= ?",
                            arrayOf(twoMinutesAgo.toString()),
                            "date DESC LIMIT 5"
                        )
                        val messages = mutableListOf<Map<String, Any>>()
                        cursor?.use {
                            while (it.moveToNext()) {
                                val body = it.getString(it.getColumnIndexOrThrow("body")) ?: ""
                                val address = it.getString(it.getColumnIndexOrThrow("address")) ?: ""
                                val date = it.getLong(it.getColumnIndexOrThrow("date"))
                                messages.add(mapOf("body" to body, "sender" to address, "date" to date, "timestamp" to date))
                            }
                        }
                        result.success(messages)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any>>())
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Auto-register receiver if permissions already granted
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED) {
            registerSmsReceiver()
        }
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                    val fullBody = StringBuilder()
                    var sender = ""
                    for (sms in messages) {
                        fullBody.append(sms.displayMessageBody)
                        if (sender.isEmpty()) {
                            sender = sms.displayOriginatingAddress ?: ""
                        }
                    }
                    if (fullBody.isNotEmpty()) {
                        val now = System.currentTimeMillis()
                        smsChannel?.invokeMethod("onSmsReceived", mapOf(
                            "body" to fullBody.toString(),
                            "sender" to sender,
                            "timestamp" to now
                        ))
                    }
                }
            }
        }
        val filter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION).apply {
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        registerReceiver(smsReceiver, filter)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (granted) {
                registerSmsReceiver()
            }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            smsReceiver = null
        }
    }
}
