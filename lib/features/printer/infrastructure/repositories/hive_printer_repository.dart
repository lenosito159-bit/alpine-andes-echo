import 'package:hive_flutter/hive_flutter.dart';
import 'package:zivlo/features/printer/domain/entities/printer_device.dart';
import 'package:zivlo/features/printer/infrastructure/models/printer_device_hive_model.dart';

/// Preferences stay compatible with the original typed printer_settings box.
/// Each recent printer has its own key; a List cannot be stored in this box.
class HivePrinterRepository {
  static const _boxName = 'printer_settings';
  static const _defaultPrinterKey = 'default_printer';
  static const _recentPrefix = 'recent_printer_';
  Box<PrinterDeviceHiveModel>? _box;

  Box<PrinterDeviceHiveModel> get _settings =>
      _box ?? Hive.box<PrinterDeviceHiveModel>(_boxName);

  Future<void> initialize() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<PrinterDeviceHiveModel>(_boxName);
    } else {
      _box = await Hive.openBox<PrinterDeviceHiveModel>(_boxName);
    }
  }

  Future<bool> saveDefaultPrinter(PrinterDevice printer) async {
    try {
      await _settings.put(_defaultPrinterKey, PrinterDeviceHiveModel.fromEntity(printer));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PrinterDevice?> getDefaultPrinter() async =>
      _settings.get(_defaultPrinterKey)?.toEntity();

  Future<bool> clearDefaultPrinter() async {
    try {
      await _settings.delete(_defaultPrinterKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addRecentPrinter(PrinterDevice printer) async {
    try {
      final recent = await getRecentPrinters();
      recent.removeWhere((entry) => entry.address == printer.address);
      recent.insert(0, printer.copyWith(isConnected: false));
      await _writeRecent(recent.take(5).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PrinterDevice>> getRecentPrinters() async => [
        for (var index = 0; index < 5; index++)
          if (_settings.get('$_recentPrefix$index') case final model?) model.toEntity(),
      ];

  Future<void> _writeRecent(List<PrinterDevice> recent) async {
    await _settings.putAll({
      for (var index = 0; index < recent.length; index++)
        '$_recentPrefix$index': PrinterDeviceHiveModel.fromEntity(recent[index]),
    });
    await _settings.deleteAll([
      for (var index = recent.length; index < 5; index++) '$_recentPrefix$index',
    ]);
  }

  Future<bool> clearRecentPrinters() async {
    try {
      await _writeRecent([]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updatePrinterConnectionStatus(String address, bool isConnected) async {
    try {
      final printer = await getDefaultPrinter();
      if (printer != null && printer.address == address &&
          !await saveDefaultPrinter(printer.copyWith(isConnected: isConnected))) {
        return false;
      }
      final recent = await getRecentPrinters();
      await _writeRecent([
        for (final item in recent)
          item.address == address ? item.copyWith(isConnected: isConnected) : item,
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async => _box?.close();
}
