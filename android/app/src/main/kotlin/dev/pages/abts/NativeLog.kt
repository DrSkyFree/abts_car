package dev.pages.abts

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 原生层追加日志——熄火/上电取证的唯一可靠通道。
 *
 * Dart 侧 LogCollector 在进程冻结/被杀时来不及保存；媒体按键到达的是
 * 原生 MediaButtonReceiver（清单注册，系统直接拉起），Dart 埋点整条链
 * 都无记录。这里在收到广播的第一时间同步追加写 filesDir/abts-native-log.txt
 * （私有目录，无需任何权限，进程活着就写得了），Dart 导出时合并。
 * 超 256KB 截掉前半，防止无限膨胀。
 */
object NativeLog {
    private const val TAG = "NativeLog"
    const val FILE_NAME = "abts-native-log.txt"
    private const val MAX_BYTES = 256 * 1024

    private val fmt = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)

    fun append(context: Context, tag: String, msg: String) {
        try {
            val f = File(context.filesDir, FILE_NAME)
            if (f.exists() && f.length() > MAX_BYTES) {
                // 简单轮转：保留后半段，旧的丢弃
                f.writeText(f.readText().takeLast(MAX_BYTES / 2))
            }
            f.appendText("${fmt.format(Date())} [$tag] $msg\n")
        } catch (e: Exception) {
            Log.w(TAG, "append failed: $e")
        }
    }
}
