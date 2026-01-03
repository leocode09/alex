import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/printer_service.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});
