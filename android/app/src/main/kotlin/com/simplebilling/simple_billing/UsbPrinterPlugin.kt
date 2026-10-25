package com.simplebilling.simple_billing

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Direct Android USB Host ESC/POS printing for POS80-class 80 mm thermal printers.
 *
 * Talks to the device over its bulk OUT endpoint, so it works with:
 *  - USB Printer Class (0x07) devices (the common POS80/POS58/H80i layout)
 *  - Vendor-specific (0xFF) devices with bulk OUT endpoints (e.g. CH340-based)
 *  - CDC-ACM serial bridges (baud rate is configured via SET_LINE_CODING)
 *
 * No VID/PID is hardcoded: any device with a printable bulk OUT endpoint is
 * offered to the user. No Bluetooth, no PC, no cloud.
 */
class UsbPrinterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware {

    private companion object {
        const val CHANNEL = "simple_billing/usb_printer"
        const val EVENTS = "simple_billing/usb_printer_events"
        const val PERMISSION_ACTION = "com.simplebilling.simple_billing.USB_PERMISSION"
        const val TAG = "UsbPrinterPlugin"
        const val DEFAULT_BAUD = 19200
        const val WRITE_TIMEOUT_MS = 5000
        const val MAX_CHUNK = 16384
    }

    private lateinit var context: Context
    private var activityBinding: ActivityPluginBinding? = null
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermission: PendingPermission? = null
    private var permissionReceiver: BroadcastReceiver? = null
    private var usbReceiver: BroadcastReceiver? = null

    private val usbManager: UsbManager
        get() = context.getSystemService(Context.USB_SERVICE) as UsbManager

    @Volatile
    private var connection: UsbDeviceConnection? = null

    @Volatile
    private var connectedDevice: UsbDevice? = null

    @Volatile
    private var bulkOutEndpoint: UsbEndpoint? = null

    @Volatile
    private var claimedInterface: UsbInterface? = null

    // ---------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // ---------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS)
        eventChannel.setStreamHandler(this)
        registerUsbReceiver()
        registerPermissionReceiver()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        permissionReceiver?.let { runCatching { context.unregisterReceiver(it) } }
        usbReceiver?.let { runCatching { context.unregisterReceiver(it) } }
        permissionReceiver = null
        usbReceiver = null
        executor.execute { closeInternal() }
        executor.shutdown()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    // ---------------------------------------------------------------------
    // EventChannel.StreamHandler
    // ---------------------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        val data = mutableMapOf<String, Any?>("type" to type)
        data.putAll(payload)
        sink.success(data)
    }

    // ---------------------------------------------------------------------
    // MethodChannel.MethodCallHandler
    // ---------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "listDevices" -> result.success(listDevices())
            "requestPermission" ->
                requestPermission(call.argument<Int>("deviceId") ?: -1, result)
            "connect" -> connect(call.argument<Int>("deviceId") ?: -1, result)
            "write" -> write(call.arguments as? ByteArray, result)
            "disconnect" -> {
                executor.execute { closeInternal() }
                result.success(null)
            }
            "isConnected" -> result.success(connectedInfo())
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------------
    // Device discovery (VID/PID agnostic)
    // ---------------------------------------------------------------------

    private fun listDevices(): List<Map<String, Any?>> {
        val devices = usbManager.deviceList.values
            .filter { hasPrintingCapability(it) }
            .map { deviceInfo(it) }
        return devices
    }

    /** A device is offered if any interface is Printer Class or has a bulk OUT endpoint. */
    private fun hasPrintingCapability(device: UsbDevice): Boolean {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return true
            for (e in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(e)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    ep.direction == UsbConstants.USB_DIR_OUT
                ) {
                    return true
                }
            }
        }
        return false
    }

    private fun findBulkOut(intf: UsbInterface): UsbEndpoint? {
        for (e in 0 until intf.endpointCount) {
            val ep = intf.getEndpoint(e)
            if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                ep.direction == UsbConstants.USB_DIR_OUT
            ) {
                return ep
            }
        }
        return null
    }

    private fun firstPrintableInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (findBulkOut(intf) != null) return intf
        }
        return null
    }

    private fun deviceInfo(device: UsbDevice): Map<String, Any?> {
        val intf = firstPrintableInterface(device)
        return mapOf(
            "deviceId" to device.deviceId,
            "name" to (device.productName ?: device.deviceName ?: "USB Printer"),
            "manufacturer" to (device.manufacturerName ?: ""),
            "product" to (device.productName ?: ""),
            "serialNumber" to (device.serialNumber ?: ""),
            "vid" to device.vendorId,
            "pid" to device.productId,
            "interfaceClass" to (intf?.interfaceClass ?: -1),
            "hasBulkOut" to (intf != null),
            "hasPermission" to usbManager.hasPermission(device),
        )
    }

    private fun connectedInfo(): Map<String, Any?> {
        val device = connectedDevice
        return mapOf(
            "connected" to (device != null && connection != null),
            "deviceId" to (device?.deviceId ?: -1),
            "name" to (device?.productName ?: ""),
            "vid" to (device?.vendorId ?: 0),
            "pid" to (device?.productId ?: 0),
        )
    }

    // ---------------------------------------------------------------------
    // USB permission
    // ---------------------------------------------------------------------

    private fun requestPermission(deviceId: Int, result: Result) {
        val device = usbManager.deviceList[deviceId]
        if (device == null) {
            result.success(false)
            return
        }
        if (usbManager.hasPermission(device)) {
            result.success(true)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null || activity.isFinishing || activity.isDestroyed) {
            result.success(false)
            return
        }
        pendingPermission = PendingPermission(deviceId, result)
        val intent = Intent(PERMISSION_ACTION).putExtra(UsbManager.EXTRA_DEVICE, device)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            deviceId,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        usbManager.requestPermission(device, pendingIntent)
    }

    private fun registerPermissionReceiver() {
        if (permissionReceiver != null) return
        val filter = IntentFilter(PERMISSION_ACTION)
        permissionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != PERMISSION_ACTION) return
                val device = parcelableExtra(intent, UsbManager.EXTRA_DEVICE)
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                val deviceId = device?.deviceId ?: -1
                val pending = pendingPermission
                pendingPermission = null
                pending?.let {
                    if (it.deviceId == deviceId || deviceId == -1) {
                        it.result.success(granted)
                    } else {
                        it.result.success(false)
                    }
                }
                emit("permissionResult", mapOf("deviceId" to deviceId, "granted" to granted))
            }
        }
        registerReceiverCompat(permissionReceiver!!, filter, exported = true)
    }

    // ---------------------------------------------------------------------
    // Connect / write / disconnect
    // ---------------------------------------------------------------------

    private fun connect(deviceId: Int, result: Result) {
        executor.execute {
            try {
                val device = usbManager.deviceList[deviceId]
                if (device == null) {
                    fail(result, "device_not_found", "USB device no longer available.")
                    return@execute
                }
                if (!usbManager.hasPermission(device)) {
                    fail(result, "permission_denied", "USB permission was not granted.")
                    return@execute
                }
                closeInternal()
                val conn = usbManager.openDevice(device)
                if (conn == null) {
                    fail(result, "open_failed", "Could not open the USB device.")
                    return@execute
                }
                for (i in 0 until device.interfaceCount) {
                    val intf = device.getInterface(i)
                    val out = findBulkOut(intf) ?: continue
                    if (conn.claimInterface(intf, true)) {
                        configureSerialLineCoding(intf, conn)
                        connection = conn
                        connectedDevice = device
                        bulkOutEndpoint = out
                        claimedInterface = intf
                        emit(
                            "connected",
                            mapOf(
                                "deviceId" to device.deviceId,
                                "name" to (device.productName ?: ""),
                                "vid" to device.vendorId,
                                "pid" to device.productId,
                            ),
                        )
                        result.success(true)
                        return@execute
                    }
                }
                conn.close()
                fail(result, "no_endpoint", "No printable bulk OUT endpoint found on this device.")
            } catch (e: Exception) {
                Log.e(TAG, "connect failed", e)
                fail(result, "connect_failed", e.message ?: "Connection failed.")
            }
        }
    }

    /** CDC-ACM bridges (CH340/CP210x/FTDI) need the baud rate set before writing. */
    private fun configureSerialLineCoding(intf: UsbInterface, conn: UsbDeviceConnection) {
        if (intf.interfaceClass != UsbConstants.USB_CLASS_CDC_DATA &&
            intf.interfaceClass != UsbConstants.USB_CLASS_COMM
        ) {
            return
        }
        try {
            val data = ByteArray(7)
            val baud = DEFAULT_BAUD
            data[0] = (baud and 0xFF).toByte()
            data[1] = ((baud shr 8) and 0xFF).toByte()
            data[2] = ((baud shr 16) and 0xFF).toByte()
            data[3] = ((baud shr 24) and 0xFF).toByte()
            data[4] = 0 // 1 stop bit
            data[5] = 0 // no parity
            data[6] = 8 // 8 data bits
            conn.controlTransfer(0x21, 0x20, 0, intf.id, data, data.size, 0)
        } catch (e: Exception) {
            Log.w(TAG, "SET_LINE_CODING failed (ignored)", e)
        }
    }

    private fun write(bytes: ByteArray?, result: Result) {
        if (bytes == null || bytes.isEmpty()) {
            fail(result, "empty", "Nothing to print.")
            return
        }
        executor.execute {
            val conn = connection
            val ep = bulkOutEndpoint
            if (conn == null || ep == null || connectedDevice == null) {
                fail(result, "not_connected", "Printer is not connected.")
                return@execute
            }
            try {
                var offset = 0
                while (offset < bytes.size) {
                    val chunk = minOf(MAX_CHUNK, bytes.size - offset)
                    val sent = conn.bulkTransfer(ep, bytes.copyOfRange(offset, offset + chunk), chunk, WRITE_TIMEOUT_MS)
                    if (sent < 0) {
                        closeInternal()
                        fail(result, "write_failed", "USB write failed.")
                        return@execute
                    }
                    offset += sent
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "write failed", e)
                closeInternal()
                fail(result, "write_failed", e.message ?: "USB write failed.")
            }
        }
    }

    private fun closeInternal() {
        val dev = connectedDevice
        val conn = connection
        val intf = claimedInterface
        connectedDevice = null
        connection = null
        bulkOutEndpoint = null
        claimedInterface = null
        try {
            intf?.let { runCatching { conn?.releaseInterface(it) } }
            conn?.close()
        } catch (_: Exception) {
            // Device may already be gone; state is what matters.
        }
        emit("disconnected", mapOf("deviceId" to (dev?.deviceId ?: -1)))
    }

    // ---------------------------------------------------------------------
    // Attach / detach broadcast handling
    // ---------------------------------------------------------------------

    private fun registerUsbReceiver() {
        if (usbReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        val device = parcelableExtra(intent, UsbManager.EXTRA_DEVICE)
                        if (device != null && hasPrintingCapability(device)) {
                            emit("deviceAttached", deviceInfo(device))
                        }
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        val device = parcelableExtra(intent, UsbManager.EXTRA_DEVICE)
                        device?.let { d ->
                            emit(
                                "deviceDetached",
                                mapOf(
                                    "deviceId" to d.deviceId,
                                    "name" to (d.productName ?: ""),
                                ),
                            )
                            if (connectedDevice?.deviceId == d.deviceId) {
                                closeInternal()
                            }
                        }
                    }
                }
            }
        }
        registerReceiverCompat(usbReceiver!!, filter, exported = false)
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    @Suppress("DEPRECATION")
    private fun parcelableExtra(intent: Intent, key: String): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, UsbDevice::class.java)
        } else {
            intent.getParcelableExtra(key)
        }

    private fun registerReceiverCompat(
        receiver: BroadcastReceiver,
        filter: IntentFilter,
        exported: Boolean,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                receiver,
                filter,
                if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            context.registerReceiver(receiver, filter)
        }
    }

    private fun fail(result: Result, code: String, message: String) {
        result.error(code, message, null)
    }

    private data class PendingPermission(val deviceId: Int, val result: Result)
}