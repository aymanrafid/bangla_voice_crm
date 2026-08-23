package com.example.bangla_voice_crm

import android.media.MediaRecorder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "bangla_crm/recorder"
    private var mediaRecorder: MediaRecorder? = null
    private var currentPath: String? = null

    /** Always clears the field, even if release() throws, so the mic is never held. */
    private fun releaseRecorder() {
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
            // Already released or never prepared; nothing useful to do.
        }
        mediaRecorder = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    val filePath = call.argument<String>("path") ?: ""
                    try {
                        releaseRecorder()
                        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            MediaRecorder(this)
                        } else {
                            @Suppress("DEPRECATION")
                            MediaRecorder()
                        }
                        mediaRecorder!!.apply {
                            setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                            setAudioSamplingRate(16000)
                            setAudioChannels(1)
                            setAudioEncodingBitRate(128000)
                            setOutputFile(filePath)
                            prepare()
                            start()
                        }
                        currentPath = filePath
                        result.success("started")
                    } catch (e: Exception) {
                        // Without this the half-built recorder keeps the mic, and
                        // every later recording fails with "start failed".
                        releaseRecorder()
                        currentPath = null
                        result.error("RECORDING_ERROR", e.message, null)
                    }
                }

                "stopRecording" -> {
                    val recorder = mediaRecorder
                    val path = currentPath
                    // Detach first: whatever happens below, this handler must not
                    // leave a live recorder behind holding the microphone.
                    mediaRecorder = null
                    currentPath = null

                    var failure: String? = null
                    if (recorder != null) {
                        try {
                            recorder.stop()
                        } catch (e: Exception) {
                            // MediaRecorder.stop() throws IllegalStateException when
                            // too little audio was captured - a very common case for
                            // a quick tap.
                            failure = e.message ?: "Recording stopped before any audio was captured."
                        }
                        try {
                            recorder.release()
                        } catch (_: Exception) {
                            // Best effort; the field is already cleared.
                        }
                    }

                    if (failure != null) {
                        // An MPEG-4 file only gets its moov atom on a clean stop, so
                        // this one is undecodable. Delete it rather than let it be
                        // uploaded and transcribed as if it were valid audio.
                        if (path != null) {
                            try {
                                File(path).delete()
                            } catch (_: Exception) {
                            }
                        }
                        result.error("STOP_ERROR", failure, null)
                    } else {
                        result.success("stopped")
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        releaseRecorder()
        super.onDestroy()
    }
}
