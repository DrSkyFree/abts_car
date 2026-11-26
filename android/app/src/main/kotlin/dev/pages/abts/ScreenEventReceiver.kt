package dev.pages.abts

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log

/**
 * 熄屏/开机兜底接收器。
 *
 * 长安 Android 9 车机熄火不完全杀 AudioService 进程（仅 MainActivity 被销毁），
 * MainActivity.onCreate() 里的动态 SCREEN_OFF receiver 跟着 Activity 走会漏收。
 * 这里静态注册（Android 9 允许静态 SCREEN_OFF），确保 AudioService 进程活着时也能收到。
 *
 * 两层防线：
 * 1. SharedPreferences 锁播放门闩（跨进程/重启可靠）
 * 2. AudioManager.abandonAudioFocus 丢焦点（如果 AudioService 还在播，我们的
 *    onFocusLost 会触发 pause()）
 */
class ScreenEventReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "ScreenEventReceiver: $action")

        when (action) {
            Intent.ACTION_SCREEN_OFF -> {
                // 熄屏 → 锁门闩（禁止下次自动播放）+ 丢焦点（让 AudioService 主动 pause）
                persistPlayAllowed(context, false)
                tryAbandonAudioFocus(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // 开机冷启动 → 清所有播放状态，等用户打开 app 手动操作
                persistPlayAllowed(context, false)
                tryAbandonAudioFocus(context)
            }
        }
    }

    private fun persistPlayAllowed(context: Context, allowed: Boolean) {
        try {
            val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            sp.edit().putBoolean(KEY_PLAY_ALLOWED, allowed).apply()
        } catch (e: Exception) {
            Log.e(TAG, "persistPlayAllowed failed: $e")
        }
    }

    private fun tryAbandonAudioFocus(context: Context) {
        try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // abandonAudioFocus 会让我们的 AudioFocus.onFocusLost 触发 pause()
            // 如果我们当前根本没持有焦点（正常情况），这个调用是幂等的
            am.abandonAudioFocusRequest(AudioManager.OnAudioFocusChangeListener {})
        } catch (_: Exception) {
            // 某些 ROM 上 abandonAudioFocus 需要有效 request，忽略
        }
    }

    companion object {
        private const val TAG = "ScreenEventReceiver"
        // 与 Flutter SharedPreferences.getInstance() 读写的文件名保持一致
        private const val PREFS_NAME = "flutter.dev.pages.abts"
        private const val KEY_PLAY_ALLOWED = "play_allowed"
    }
}
