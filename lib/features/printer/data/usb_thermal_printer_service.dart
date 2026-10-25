import 'dart:async';

import 'package:flutter/services.dart';

import 'package:simple_billing/core/errors/app_failures.dart';
import 'package:simple_billing/features/printer/domain/thermal_printer_service.dart';

/// POS80 over Android USB OTG through the native USB Host plugin.
///
/// Talks directly to the printer's bulk OUT endpoint (USB Printer Class,
/// vendor-specific or CDC-ACM bridges) with no Bluetooth and no PC.
/// Disconnecting the printer must never crash the app (PRD FR-13).
class UsbThermalPrinterService extends ThermalPrinterService {
  static const _channel = MethodChannel('simple_billing/usb_printer');
  static const _events = EventChannel('simple_billing/usb_printer_events');

  PrinterConnectionState _state = PrinterConnectionState.disconnected;
  PrinterDevice? _connected;
  PrinterDevice? _lastConnected;
  bool _manualDisconnect = false;
  StreamSubscription<dynamic>? _subscription;

  @override
  PrinterConnectionState get state => _state;

  @override
  PrinterDevice? get connectedDevice => _connected;

  void _setState(PrinterConnectionState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    if (_subscription != null) return;
    _subscription = _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(dynamic raw) {
    final data = raw is Map ? Map<dynamic, dynamic>.from(raw) : <dynamic, dynamic>{};
    switch (data['type'] as String?) {
      case 'deviceAttached':
        final attached = _fromMap(data);
        final last = _lastConnected;
        if (!_manualDisconnect &&
            last != null &&
            last.deviceId != null &&
            attached.deviceId == last.deviceId) {
          unawaited(_reconnect(last));
        }
      case 'deviceDetached':
        final deviceId = data['deviceId'] as int?;
        if (_connected?.deviceId == deviceId) {
          unawaited(disconnect());
        }
      case 'permissionResult':
        // Permission outcome is already surfaced by [connect]'s future.
      case 'connected':
      case 'disconnected':
        break;
    }
  }

  Future<void> _reconnect(PrinterDevice device) async {
    if (_state == PrinterConnectionState.connected) return;
    try {
      await connect(device);
    } catch (_) {
      // Device may have been removed again; state stays disconnected.
    }
  }

  @override
  Future<List<PrinterDevice>> detect() async {
    final list =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('listDevices');
    return (list ?? const []).map(_fromMap).toList();
  }

  PrinterDevice _fromMap(Map<dynamic, dynamic> m) => PrinterDevice(
        name: (m['name'] as String?) ?? '',
        vid: (m['vid'] as int?) ?? 0,
        pid: (m['pid'] as int?) ?? 0,
        deviceId: m['deviceId'] as int?,
        manufacturer: (m['manufacturer'] as String?) ?? '',
        serialNumber: (m['serialNumber'] as String?) ?? '',
        interfaceClass: (m['interfaceClass'] as int?) ?? -1,
        hasBulkOut: (m['hasBulkOut'] as bool?) ?? false,
        hasPermission: (m['hasPermission'] as bool?) ?? false,
      );

  @override
  Future<void> connect(PrinterDevice device) async {
    if (_connected?.deviceId == device.deviceId &&
        _state == PrinterConnectionState.connected) {
      return;
    }
    _setState(PrinterConnectionState.connecting);
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestPermission',
        {'deviceId': device.deviceId},
      );
      if (granted != true) {
        throw const UsbPermissionDenied();
      }
      final ok = await _channel.invokeMethod<bool>(
        'connect',
        {'deviceId': device.deviceId},
      );
      if (ok != true) {
        throw const UsbConnectFailed();
      }
      _connected = device;
      _lastConnected = device;
      _manualDisconnect = false;
      _setState(PrinterConnectionState.connected);
    } on AppFailure {
      _setState(PrinterConnectionState.disconnected);
      rethrow;
    } on PlatformException catch (e) {
      _setState(PrinterConnectionState.disconnected);
      throw _failureFromCode(e.code);
    } catch (_) {
      _setState(PrinterConnectionState.disconnected);
      throw const UsbConnectFailed();
    }
  }

  @override
  Future<void> disconnect() async {
    _manualDisconnect = true;
    try {
      await _channel.invokeMethod<void>('disconnect');
    } catch (_) {
      // Device may already be gone; state is what matters.
    }
    _connected = null;
    _setState(PrinterConnectionState.disconnected);
  }

  @override
  Future<void> print(Uint8List bytes) async {
    if (_connected == null) {
      throw const PrinterNotConnected();
    }
    try {
      final ok = await _channel.invokeMethod<bool>('write', bytes);
      if (ok != true) {
        throw const PrinterWriteFailed();
      }
    } on PlatformException catch (e) {
      if (e.code == 'not_connected' || e.code == 'write_failed') {
        await disconnect();
      }
      throw const PrinterNotConnected();
    }
  }

  @override
  Future<void> testPrint(Uint8List bytes) => print(bytes);

  AppFailure _failureFromCode(String code) => switch (code) {
        'not_connected' => const PrinterNotConnected(),
        'permission_denied' => const UsbPermissionDenied(),
        _ => const UsbConnectFailed(),
      };
}