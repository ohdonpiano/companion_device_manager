package it.poggi.companion_device_manager

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal object CompanionDeviceEventStream {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    fun attachSink(sink: EventChannel.EventSink) {
        mainHandler.post {
            eventSink = sink
        }
    }

    fun detachSink() {
        mainHandler.post {
            eventSink = null
        }
    }

    fun emit(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }
}

