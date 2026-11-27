package dev.pages.abts

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log
import android.view.KeyEvent
import com.ryanheise.audioservice.MediaButtonReceiver
import java.io.File

/**
 * 熄屏/开机兜底接收器。
 *
 * 长安 Android 9 车机熄火不完全杀 AudioService 进程（仅 MainActivity 被销毁），
 * MainActivity.onCreate() 里的动态 SCREEN_OFF receiver 跟着 Activity 走会漏收。
 * 这里静态注册（Android 9 允许静态 SCREEN_OFF），确保 AudioService 进程活着时也能收到。
 *
 * 两层防线（均与 Dart 侧 BookPlayer._loadPlayAllowed 对齐）：
 * 1. SharedPreferences「FlutterSharedPreferences」写 key「flutter.play_allowed」= false
 *    （这是 Dart SharedPreferences.getInstance() 实际使用的文件与键名）
 * 2. filesDir/abts_play_gate 标记文件写「locked」——Dart 启动时优先读它，
 *    绕开 shared_preferences 版本差异导致的文件名/键名不一致
 * 3. AudioManager 发 MEDIA_PAUSE 按键给 MediaButtonReceiver（AudioService 还在播时触发 pause）
 */
class ScreenEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "ScreenEventReceiver: $action")

        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                lockPlayGate(context, "SCREEN_OFF")
                trySendMediaPause(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                lockPlayGate(context, "BOOT")
                trySendMediaPause(context)
            }
        }
    }

    /// 锁播放门闩：prefs + 标记文件双写
    private fun lockPlayGate(context: Context, reason: String) {
        try {
            // 与 Dart SharedPreferences.getInstance() 对齐的文件与键名
            val sp = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            sp.edit().putBoolean(KEY_PLAY_ALLOWED, false).apply()
            Log.d(TAG, "lockPlayGate($reason): prefs written")
        } catch (e: Exception) {
            Log.e(TAG, "lockPlayGate prefs failed: $e")
        }
        try {
            // 标记文件双保险：Dart 侧启动时优先读它
            File(context.filesDir, MARKER_NAME).writeText(MARKER_LOCKED)
            Log.d(TAG, "lockPlayGate($reason): marker written")
        } catch (e: Exception) {
            Log.e(TAG, "lockPlayGate marker failed: $e")
        }
        // 诊断：列出 shared_prefs 目录实际文件（一次性的排查信息）
        try {
            val prefsDir = File(context.filesDir.parentFile, "shared_prefs")
            Log.d(TAG, "shared_prefs files: ${prefsDir.list()?.joinToString()}")
        } catch (_: Exception) {
        }
    }

    private fun trySendMediaPause(context: Context) {
        try {
            // 发 MEDIA_PAUSE 按键给 audio_service 的 MediaButtonReceiver，
            // 让 AudioService 主动 pause()。如果 AudioService 没在播，这个 intent 无副作用。
            val pauseIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setComponent(ComponentName(context, MediaButtonReceiver::class.java))
                putExtra(Intent.EXTRA_KEY_EVENT,
                    KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }
            context.sendBroadcast(pauseIntent)
        } catch (e: Exception) {
            Log.w(TAG, "send MEDIA_PAUSE failed: $e")
        }
    }

    companion object {
        private const val TAG = "ScreenEventReceiver"
        // Dart shared_preferences 2.x 在 Android 上的实际文件名与键名前缀
        private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_PLAY_ALLOWED = "flutter.play_allowed"
        // 门闩标记文件（filesDir 下），Dart 侧读取的文件名与内容常量保持一致
        const val MARKER_NAME = "abts_play_gate"
        const val MARKER_LOCKED = "locked"
        const val MARKER_OPEN = "open"
    }
}
