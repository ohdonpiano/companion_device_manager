package it.poggi.companion_device_manager

import android.companion.AssociationInfo
import android.companion.CompanionDeviceService
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.view.FlutterCallbackInformation
import io.flutter.FlutterInjector

class CompanionDeviceBackgroundService : CompanionDeviceService() {
    private var activeEngine: FlutterEngine? = null

    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        handleDeviceEvent("device_appeared", associationInfo)
    }

    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
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
                "lastTimeConnectedMs" to associationInfo.lastTimeConnected,
            ),
            "rawPayload" to mapOf<String, Any?>(
                "type" to type,
            ),
        )

        CompanionDeviceStorage.persistEvent(context, payload)

        val callbackHandle = CompanionDeviceStorage.getBackgroundCallbackHandle(context) ?: return
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
            ?: return

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
    }

    override fun onDestroy() {
        activeEngine?.destroy()
        activeEngine = null
        super.onDestroy()
    }
}

