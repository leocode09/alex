import 'package:alex/services/receipt_print_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReceiptPrintService', () {
    late ReceiptPrintService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ReceiptPrintService();
    });

    test('starts with zero print count for unknown sale', () async {
      final count = await service.getPrintCount('sale-1');
      expect(count, 0);
    });

    test('increments through markPrinted and returns next print number',
        () async {
      const saleId = 'sale-2';

      expect(await service.getNextPrintNumber(saleId), 1);

      await service.markPrinted(saleId, printNumber: 1);
      expect(await service.getPrintCount(saleId), 1);
      expect(await service.getNextPrintNumber(saleId), 2);

      await service.markPrinted(saleId, printNumber: 2);
      expect(await service.getPrintCount(saleId), 2);
      expect(await service.getNextPrintNumber(saleId), 3);
    });

    test('does not reduce count when older print number is saved', () async {
      const saleId = 'sale-3';

      await service.markPrinted(saleId, printNumber: 3);
      await service.markPrinted(saleId, printNumber: 2);

      expect(await service.getPrintCount(saleId), 3);
    });

    test('builds human-readable print labels', () {
      expect(service.buildPrintLabel(1), 'Original Print');
      expect(service.buildPrintLabel(2), 'Reprint #2');
      expect(service.buildPrintLabel(4), 'Reprint #4');
    });
  });
}
