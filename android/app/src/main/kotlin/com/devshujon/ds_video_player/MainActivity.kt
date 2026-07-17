package com.devshujon.ds_video_player

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.devshujon.ds_video_player/player"
    }

    private var playerChannel: MethodChannel? = null
    private var autoPipOnLeave = false
    var isInPipMode = false
        private set

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        playerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPip" -> result.success(enterPip())
                    "isPipSupported" ->
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    "isInPipMode" -> result.success(isInPipMode)
                    "setAutoPipOnLeave" -> {
                        autoPipOnLeave = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun enterPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        return try {
            enterPictureInPictureMode(params)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        isInPipMode = isInPictureInPictureMode
        playerChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        if (autoPipOnLeave && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPip()
        }
        super.onUserLeaveHint()
    }
}
