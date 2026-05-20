package it.poggi.companion_device_manager

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.view.FlutterCallbackInformation
import io.flutter.FlutterInjector

class CompanionDeviceBackgroundService : CompanionDeviceService() {
    private val tag = "CDMBackgroundService"
    private var activeEngine: FlutterEngine? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(tag, "Service onCreate called - service is alive")
    }

    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        Log.d(tag, "onDeviceAppeared id=${associationInfo.id} mac=${associationInfo.deviceMacAddress}")
        handleDeviceEvent("device_appeared", associationInfo)
    }

    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
        Log.d(tag, "onDeviceDisappeared id=${associationInfo.id} mac=${associationInfo.deviceMacAddress}")
        handleDeviceEvent("device_disappeared", associationInfo)
    }

    private fun handleDeviceEvent(type: String, associationInfo: AssociationInfo) {
        val context = applicationContext
        val payload = mapOf<String, Any?>(
            "type" to type,
            "timestampMs" to System.currentTimeMillis(),
            "association" to mapOf<String, Any?>(
                "associationId" to associationInfo.id,
                "macAddress" to associationInfo.deviceMacAddress?.toString(),
                "displayName" to associationInfo.displayName?.toString(),
                "deviceProfile" to associationInfo.deviceProfile,
                "selfManaged" to associationInfo.isSelfManaged,
                "lastTimeConnectedMs" to null,
            ),
            "rawPayload" to mapOf<String, Any?>(
                "type" to type,
            ),
        )

        CompanionDeviceStorage.persistEvent(context, payload)
        CompanionDeviceEventStream.emit(payload)
        Log.d(tag, "Persisted and emitted event type=$type")

        val callbackHandle = CompanionDeviceStorage.getBackgroundCallbackHandle(context)
        if (callbackHandle == null) {
            Log.w(tag, "No registered background callback handle; event will not execute Dart callback")
            return
        }
        Log.d(tag, "Found registered callback handle=$callbackHandle")
        runOnMainThread {
            startBackgroundCallbackEngine(context, callbackHandle)
        }
    }

    private fun runOnMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            Handler(Looper.getMainLooper()).post(block)
        }
    }

    private fun startBackgroundCallbackEngine(context: Context, callbackHandle: Long) {
        activeEngine?.destroy()
        activeEngine = null

        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
            ?: run {
                Log.e(tag, "Unable to resolve Flutter callback info for handle=$callbackHandle")
                return
            }

        val flutterLoader: FlutterLoader = FlutterInjector.instance().flutterLoader()
        flutterLoader.startInitialization(context)
        flutterLoader.ensureInitializationComplete(context, null)

        val engine = FlutterEngine(context)
        activeEngine = engine

        runCatching {
            Class.forName("io.flutter.plugins.GeneratedPluginRegistrant")
                .getDeclaredMethod("registerWith", FlutterEngine::class.java)
                .invoke(null, engine)
        }

        val dartCallback = DartExecutor.DartCallback(
            context.assets,
            flutterLoader.findAppBundlePath(),
            callbackInfo,
        )
        engine.dartExecutor.executeDartCallback(dartCallback)
        Log.d(tag, "Executed Dart background callback for event")
    }

    override fun onDestroy() {
        activeEngine?.destroy()
        activeEngine = null
        Log.d(tag, "Service onDestroy called")
        super.onDestroy()
    }
}

