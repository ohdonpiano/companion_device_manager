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
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class CompanionDeviceBackgroundService : CompanionDeviceService() {
    private val tag = "CDMBackgroundService"
    private var activeEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private val pendingEvents: ArrayDeque<Pair<Map<String, Any?>, Long>> = ArrayDeque()
    private var dispatcherReady: Boolean = false

    override fun onCreate() {
        super.onCreate()
        Log.d(tag, "Service onCreate called - service is alive")
        CompanionDeviceStorage.appendNativeDebugLog(applicationContext, "$tag onCreate")
    }

    override fun onDeviceAppeared(associationInfo: AssociationInfo) {
        val mac = associationInfo.deviceMacAddress?.toString()
        Log.d(tag, "onDeviceAppeared id=${associationInfo.id} mac=$mac")
        CompanionDeviceStorage.appendNativeDebugLog(
            applicationContext,
            "$tag callback_received type=device_appeared id=${associationInfo.id} mac=$mac",
        )
        handleDeviceEvent("device_appeared", associationInfo)
    }

    override fun onDeviceDisappeared(associationInfo: AssociationInfo) {
        val mac = associationInfo.deviceMacAddress?.toString()
        Log.d(tag, "onDeviceDisappeared id=${associationInfo.id} mac=$mac")
        CompanionDeviceStorage.appendNativeDebugLog(
            applicationContext,
            "$tag callback_received type=device_disappeared id=${associationInfo.id} mac=$mac",
        )
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
        CompanionDeviceStorage.appendNativeDebugLog(
            context,
            "$tag event=$type id=${associationInfo.id} mac=${associationInfo.deviceMacAddress}",
        )

        val callbackHandle = CompanionDeviceStorage.getBackgroundCallbackHandle(context)
        val dispatcherHandle = CompanionDeviceStorage.getBackgroundDispatcherHandle(context)
        if (callbackHandle == null) {
            Log.w(tag, "No registered background callback handle; event will not execute Dart callback")
            CompanionDeviceStorage.appendNativeDebugLog(
                context,
                "$tag callback_not_dispatched type=$type reason=missing_callback_handle",
            )
            return
        }
        if (dispatcherHandle == null) {
            Log.e(tag, "Missing background dispatcher handle. Re-register callback from Dart.")
            CompanionDeviceStorage.appendNativeDebugLog(
                context,
                "$tag callback_not_dispatched type=$type reason=missing_dispatcher_handle",
            )
            return
        }

        Log.d(tag, "Found registered callback handle=$callbackHandle dispatcherHandle=$dispatcherHandle")
        CompanionDeviceStorage.appendNativeDebugLog(
            context,
            "$tag callback_dispatch_queued type=$type callback=$callbackHandle dispatcher=$dispatcherHandle",
        )
        runOnMainThread {
            pendingEvents.addLast(payload to callbackHandle)
            startBackgroundCallbackEngine(context, dispatcherHandle)
        }
    }

    private fun runOnMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            block()
        } else {
            Handler(Looper.getMainLooper()).post(block)
        }
    }

    private fun startBackgroundCallbackEngine(
        context: Context,
        dispatcherHandle: Long,
    ) {
        if (activeEngine != null && dispatcherReady) {
            dispatchPendingEventToDart()
            return
        }

        val callbackInfo = try {
            FlutterCallbackInformation.lookupCallbackInformation(dispatcherHandle)
        } catch (error: Throwable) {
            CompanionDeviceStorage.appendNativeDebugLog(
                context,
                "$tag callback_lookup_failed handle=$dispatcherHandle error_class=${error.javaClass.name} error_message=${error.message ?: "<none>"}",
            )
            Log.e(tag, "Unable to resolve Flutter callback info for dispatcherHandle=$dispatcherHandle", error)
            null
        } ?: run {
            Log.e(tag, "Unable to resolve Flutter callback info for dispatcherHandle=$dispatcherHandle")
            return
        }

        val flutterLoader: FlutterLoader = FlutterInjector.instance().flutterLoader()
        flutterLoader.startInitialization(context)
        flutterLoader.ensureInitializationComplete(context, null)

        val engine = FlutterEngine(context)
        activeEngine = engine
        dispatcherReady = false

        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL_NAME)
        backgroundChannel = channel
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            if (call.method == "backgroundDispatcherInitialized") {
                dispatcherReady = true
                dispatchPendingEventToDart()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }


        val dartCallback = DartExecutor.DartCallback(
            context.assets,
            flutterLoader.findAppBundlePath(),
            callbackInfo,
        )
        engine.dartExecutor.executeDartCallback(dartCallback)
        Log.d(tag, "Executed Dart background dispatcher callback")
        CompanionDeviceStorage.appendNativeDebugLog(
            context,
            "$tag headless_engine_started dispatcher=$dispatcherHandle",
        )
    }

    private fun dispatchPendingEventToDart() {
        val channel = backgroundChannel
        if (channel == null || !dispatcherReady) {
            return
        }

        while (pendingEvents.isNotEmpty()) {
            val (eventPayload, callbackHandle) = pendingEvents.removeFirst()
            channel.invokeMethod(
                "dispatchBackgroundEvent",
                mapOf<String, Any?>(
                    "event" to eventPayload,
                    "callbackHandle" to callbackHandle,
                ),
            )
            CompanionDeviceStorage.appendNativeDebugLog(
                applicationContext,
                "$tag callback_dispatched type=${eventPayload["type"]} callback=$callbackHandle",
            )
        }
        Log.d(tag, "Delivered background event payload(s) to Dart dispatcher")
    }

    override fun onDestroy() {
        backgroundChannel?.setMethodCallHandler(null)
        backgroundChannel = null
        pendingEvents.clear()
        dispatcherReady = false
        activeEngine?.destroy()
        activeEngine = null
        Log.d(tag, "Service onDestroy called")
        CompanionDeviceStorage.appendNativeDebugLog(applicationContext, "$tag onDestroy")
        super.onDestroy()
    }

    companion object {
        private const val BACKGROUND_CHANNEL_NAME = "companion_device_manager/background"
    }
}
