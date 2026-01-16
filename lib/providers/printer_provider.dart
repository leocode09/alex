import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/printer_service.dart';

// Use a single persistent instance so the printer connection is maintained
final _printerServiceInstance = PrinterService();

final printerServiceProvider = Provider<PrinterService>((ref) {
  return _printerServiceInstance;
});
