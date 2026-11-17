package dev.pages.abts

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.app.NotificationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val CACHE_CHANNEL_ID = "dev.pages.abts.channel.cache"
        private const val CACHE_NOTIFY_ID = 4201
    }

    private var audioManager: AudioManager? = null
    private var focusCallback: EventChannel.EventSink? = null
    private var focusRequest: AudioFocusRequest? = null
    private var cacheNotifyManager: NotificationManager? = null

    /// 全屏模式（由 Dart 侧 `abts/device` 的 setFullscreen 控制）
    private var fullscreen = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        disableSystemFocusHighlight(window.decorView)
    }

    override fun onPostResume() {
        super.onPostResume()
        // FlutterView 在 onCreate 后挂载，这里再扫一遍，确保系统焦点框被关掉
        disableSystemFocusHighlight(window.decorView)
        // 个别车机在恢复前台时会重置窗口 flag，回到前台重新套一次全屏
        if (fullscreen) applyFullscreen(true)
    }

    /// 全屏：API 30+ 用 WindowInsetsController，24~29 用 systemUiVisibility；
    /// 同时加 FLAG_LAYOUT_NO_LIMITS，让内容铺满整个屏幕（含被系统覆盖层占用的区域）。
    private fun applyFullscreen(on: Boolean) {
        val w = window ?: return
        if (on) {
            w.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        } else {
            w.clearFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            w.setDecorFitsSystemWindows(!on)
            val controller = w.insetsController
            if (on) {
                controller?.hide(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
                )
                controller?.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                controller?.show(
                    WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars(),
                )
            }
        } else {
            @Suppress("DEPRECATION")
            w.decorView.systemUiVisibility = if (on) {
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            } else {
                View.SYSTEM_UI_FLAG_VISIBLE
            }
        }
    }

    /// Flutter 自己绘制焦点态；关掉 Android 给 FlutterView 套的默认焦点框，
    /// 否则电视上用遥控器操作时整个画面四周会出现一圈系统配色的边框。
    private fun disableSystemFocusHighlight(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        view.defaultFocusHighlightEnabled = false
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                disableSystemFocusHighlight(view.getChildAt(i))
            }
        }
    }

    /// 拔耳机 / 蓝牙断开：系统广播 AUDIO_BECOMING_NOISY，通知 Dart 侧暂停
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                focusCallback?.success("noisy")
            }
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                // 打断结束：通知 Dart 侧续播
                focusCallback?.success("gained")
            }

            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // 来电/导航等暂时打断：暂停并等待恢复
                focusCallback?.success("interrupted")
            }

            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                // 短暂提示音：仅降低音量，不中断播放
                focusCallback?.success("ducked")
            }

            AudioManager.AUDIOFOCUS_LOSS -> {
                // 被其他播放器永久抢占：暂停且不自动恢复
                focusCallback?.success("lost")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // 注册「即将变噪音」广播（拔耳机/蓝牙断开）→ 自动暂停
        try {
            val noisyFilter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // targetSdk 33+ 必须显式声明导出属性；系统受保护广播照常送达
                registerReceiver(noisyReceiver, noisyFilter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(noisyReceiver, noisyFilter)
            }
        } catch (e: Exception) {
            // 个别 ROM 限制隐式广播时忽略，不影响播放
        }

        // 音频焦点
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/audio_focus",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> result.success(requestFocus())
                "abandon" -> {
                    abandonFocus()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/audio_focus_events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                focusCallback = events
            }

            override fun onCancel(arguments: Any?) {
                focusCallback = null
            }
        })

        // 保存图片到相册
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/gallery",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                "saveImage" -> {
                    val base64 = call.argument<String>("base64")
                    val name = call.argument<String>("name") ?: "image"
                    if (base64 == null) {
                        result.success(null)
                    } else {
                        result.success(saveImageToGallery(base64, name))
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 打开外部链接（浏览器）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/browser",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        result.success(openExternal(url))
                    }
                }

                else -> result.notImplemented()
            }
        }

        // 离线缓存进度通知（后台缓存时显示）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/cache_notify",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val title = call.argument<String>("title") ?: "正在缓存"
                    val text = call.argument<String>("text") ?: ""
                    val progress = call.argument<Int>("progress") ?: -1
                    updateCacheNotification(title, text, progress)
                    result.success(true)
                }

                "cancel" -> {
                    cacheNotifyManager?.cancel(CACHE_NOTIFY_ID)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // 存储可用空间（缓存前预检，避免下到一半才失败）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/storage",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> {
                    try {
                        // 传入路径时按该分区算（缓存切到 SD 卡后要检测对应分区）；
                        // 不传就按应用内部存储算
                        val path = call.argument<String>("path")
                        val stat = if (path.isNullOrBlank()) {
                            StatFs(filesDir.absolutePath)
                        } else {
                            StatFs(path)
                        }
                        result.success(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                            stat.availableBytes
                        } else {
                            @Suppress("DEPRECATION")
                            stat.availableBlocks.toLong() * stat.blockSize.toLong()
                        })
                    } catch (e: Exception) {
                        result.success(-1L)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // 设备形态（宽屏无触摸 / 方向键设备判定：车机中控、遥控盒子）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLeanback" -> {
                    try {
                        val pm = packageManager
                        val leanback =
                            pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
                                pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY)
                        val touch =
                            pm.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN)
                        // 部分车机盒子未声明 leanback 特性，但用方向键导航且无触摸屏，同样按宽屏对待
                        val dpad = resources.configuration.navigation ==
                            android.content.res.Configuration.NAVIGATION_DPAD
                        result.success((leanback && !touch) || (!touch && dpad))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // 重建布局参数后自动重启（切换「使用设备」为车机时使用）
                "restart" -> {
                    result.success(true)
                    try {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        intent?.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP,
                        )
                        if (intent != null) startActivity(intent)
                    } catch (_: Exception) {
                        // 个别车机限制自启动时忽略，用户手动重开同样生效
                    }
                    android.os.Handler(mainLooper).postDelayed({
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }, 400)
                }

                // 全屏模式：隐藏系统状态栏/导航栏（沉浸式），兼容 API 24 ~ 最新
                "setFullscreen" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    fullscreen = on
                    applyFullscreen(on)
                    result.success(true)
                }

                // 完全退出：车机没有后台任务管理，结束前台服务与进程
                "exit" -> {
                    result.success(true)
                    try {
                        stopService(
                            Intent(this, com.ryanheise.audioservice.AudioService::class.java),
                        )
                    } catch (_: Exception) {
                        // 服务未启动时忽略
                    }
                    // 一并移除最近任务里的条目，避免车机点开又回到旧画面
                    try {
                        finishAndRemoveTask()
                    } catch (_: Exception) {
                        // 个别 ROM 不支持时忽略
                    }
                    android.os.Handler(mainLooper).postDelayed({
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }, 300)
                }

                else -> result.notImplemented()
            }
        }

        // 电池优化（后台留存）
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "abts/battery",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoring" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }

                "requestIgnore" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS))
                        } catch (_: Exception) {
                            // 系统无对应设置页时忽略
                        }
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(noisyReceiver)
        } catch (e: Exception) {
            // 未注册过则忽略
        }
        super.onDestroy()
    }

    private fun requestFocus(): Boolean {
        val am = audioManager ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setOnAudioFocusChangeListener(focusListener)
                .setAcceptsDelayedFocusGain(true)
                .build()
            focusRequest = request
            val r = am.requestAudioFocus(request)
            r == AudioManager.AUDIOFOCUS_REQUEST_GRANTED || r == AudioManager.AUDIOFOCUS_REQUEST_DELAYED
        } else {
            val r = am.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            )
            r == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonFocus() {
        val am = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 必须使用同一个 AudioFocusRequest 实例才能真正释放
            val request = focusRequest ?: return
            am.abandonAudioFocusRequest(request)
            focusRequest = null
        } else {
            am.abandonAudioFocus(focusListener)
        }
    }

    /** 用系统浏览器打开链接；没有可用浏览器时返回 false */
    private fun openExternal(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun updateCacheNotification(title: String, text: String, progress: Int) {
        try {
            val nm = cacheNotifyManager ?: run {
                val n = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                createCacheChannel(n)
                cacheNotifyManager = n
                n
            }
            val b = android.app.Notification.Builder(this, CACHE_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
            if (progress >= 0) {
                b.setProgress(100, progress, false)
            }
            nm.notify(CACHE_NOTIFY_ID, b.build())
        } catch (e: Exception) {
            // 没有通知权限等情况，忽略即可，不影响下载
        }
    }

    private fun createCacheChannel(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = android.app.NotificationChannel(
                CACHE_CHANNEL_ID,
                "离线缓存",
                NotificationManager.IMPORTANCE_LOW,
            )
            ch.setShowBadge(false)
            ch.enableVibration(false)
            ch.setSound(null, null)
            nm.createNotificationChannel(ch)
        }
    }

    /** 保存 PNG 到系统相册，返回保存路径；失败返回 null */
    private fun saveImageToGallery(base64: String, name: String): String? {
        return try {
            val bytes = android.util.Base64.decode(base64, android.util.Base64.DEFAULT)
            val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: return null
            val fileName = if (name.endsWith(".png")) name else "$name.png"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, fileName)
                    put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        android.provider.MediaStore.Images.Media.RELATIVE_PATH,
                        "Pictures/阿B听书",
                    )
                    put(android.provider.MediaStore.Images.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(
                    android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: return null
                contentResolver.openOutputStream(uri)?.use { os ->
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, os)
                }
                values.clear()
                values.put(android.provider.MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                uri.toString()
            } else {
                @Suppress("DEPRECATION")
                val dir = java.io.File(
                    android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_PICTURES,
                    ),
                    "阿B听书",
                )
                if (!dir.exists() && !dir.mkdirs()) return null
                val file = java.io.File(dir, fileName)
                java.io.FileOutputStream(file).use { os ->
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, os)
                }
                android.media.MediaScannerConnection.scanFile(
                    this,
                    arrayOf(file.absolutePath),
                    arrayOf("image/png"),
                    null,
                )
                file.absolutePath
            }
        } catch (e: Exception) {
            null
        }
    }
}