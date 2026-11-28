package dev.pages.abts

import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import com.ryanheise.audioservice.MediaButtonReceiver

/**
 * 记录所有到达的媒体按键（原生层落盘，进程活着就必然能写）。
 *
 * 长安车机熄火/上电瞬间 ROM 投递的 PLAY 会直接到达这里——这是
 * 「熄火自动播」根源取证的唯一可靠通道。记录后转交 audio_service
 * 处理原有逻辑，行为完全不变。
 */
class LoggingMediaButtonReceiver : MediaButtonReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MEDIA_BUTTON) {
            @Suppress("DEPRECATION")
            val ke = intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT) as? KeyEvent
            if (ke != null) {
                NativeLog.append(
                    context, "MediaButton",
                    "KeyEvent action=${ke.action} keycode=${ke.keyCode}"
                )
            } else {
                NativeLog.append(context, "MediaButton", "无 KeyEvent extras")
            }
        }
        super.onReceive(context, intent)
    }
}
