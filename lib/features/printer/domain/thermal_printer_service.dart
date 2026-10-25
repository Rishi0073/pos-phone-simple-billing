import 'package:flutter/foundation.dart';

enum PrinterConnectionState { disconnected, connecting, connected }

class PrinterDevice {
  const PrinterDevice({
    required this.name,
    required this.vid,
    required this.pid,
    this.deviceId,
    this.manufacturer = '',
    this.serialNumber = '',
    this.interfaceClass = -1,
    this.hasBulkOut = false,
    this.hasPermission = false,
  });

  final String name;
  final int vid;
  final int pid;
  final int? deviceId;
  final String manufacturer;
  final String serialNumber;
  final int interfaceClass;
  final bool hasBulkOut;
  final bool hasPermission;

  String get label => name.isEmpty ? 'USB Printer (${_hex(vid)}:${_hex(pid)})' : name;

  static String _hex(int value) => value.toRadixString(16).padLeft(4, '0');

  String get vidPid => '${_hex(vid)}:${_hex(pid)}';

  @override
  String toString() => label;
}

/// ChangeNotifier so the UI can listen for connect/disconnect changes.
abstract class ThermalPrinterService extends ChangeNotifier {
  PrinterConnectionState get state;

  PrinterDevice? get connectedDevice;

  /// Registers USB attach/detach listeners and enables auto-reconnect.
  Future<void> initialize();

  Future<List<PrinterDevice>> detect();

  Future<void> connect(PrinterDevice device);

  Future<void> disconnect();

  Future<void> print(Uint8List bytes);

  Future<void> testPrint(Uint8List bytes);
}