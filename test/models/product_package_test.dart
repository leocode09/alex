import 'package:alex/models/product.dart';
import 'package:alex/models/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductPackage', () {
    test('serializes and deserializes correctly', () {
      final pkg = ProductPackage(
        id: 'pkg-1',
        name: 'Half pack',
        unitsPerPackage: 12,
      );
      final map = pkg.toMap();
      final restored = ProductPackage.fromMap(map);
      expect(restored.id, pkg.id);
      expect(restored.name, pkg.name);
      expect(restored.unitsPerPackage, pkg.unitsPerPackage);
      expect(restored.packagePrice, isNull);
    });

    test('round-trips packagePrice when set', () {
      final pkg = ProductPackage(
        id: 'pkg-2',
        name: 'Case',
        unitsPerPackage: 24,
        packagePrice: 19.99,
      );
      final restored = ProductPackage.fromMap(pkg.toMap());
      expect(restored.packagePrice, 19.99);
    });

    test('fromMap omits packagePrice when key absent', () {
      final restored = ProductPackage.fromMap({
        'id': 'x',
        'name': 'Box',
        'unitsPerPackage': 6,
      });
      expect(restored.packagePrice, isNull);
      expect(restored.packageCount, 0);
    });

    test('round-trips packageCount', () {
      final pkg = ProductPackage(
        id: 'a',
        name: 'Case',
        unitsPerPackage: 12,
        packageCount: 7,
      );
      final restored = ProductPackage.fromMap(pkg.toMap());
      expect(restored.packageCount, 7);
    });
  });

  group('sellingPriceForPackage', () {
    test('single-item sentinel uses unit price only', () {
      final pkg = ProductPackage(
        id: productPackageSingleItemId,
        name: '1 item',
        unitsPerPackage: 1,
        packagePrice: 999,
      );
      expect(
        sellingPriceForPackage(unitPrice: 3.5, pkg: pkg),
        3.5,
      );
    });

    test('uses packagePrice when set', () {
      final pkg = ProductPackage(
        id: 'p1',
        name: 'Half',
        unitsPerPackage: 12,
        packagePrice: 10.0,
      );
      expect(sellingPriceForPackage(unitPrice: 1.0, pkg: pkg), 10.0);
    });

    test('falls back to unit price times units when packagePrice null', () {
      final pkg = ProductPackage(
        id: 'p1',
        name: 'Half',
        unitsPerPackage: 12,
      );
      expect(sellingPriceForPackage(unitPrice: 2.0, pkg: pkg), 24.0);
    });
  });

  group('Product with packages', () {
    test('round-trips with packages', () {
      final pkg = ProductPackage(
        id: 'pkg-1',
        name: '1/4 pack',
        unitsPerPackage: 6,
      );
      final product = Product(
        id: 'prod-1',
        name: 'Pepsi',
        price: 1.0,
        stock: 24,
        packages: [pkg],
      );
      final map = product.toMap();
      final restored = Product.fromMap(map);
      expect(restored.packages.length, 1);
      expect(restored.packages.first.name, '1/4 pack');
      expect(restored.packages.first.unitsPerPackage, 6);
    });

    test('fromMap defaults to empty packages when absent', () {
      final map = {
        'id': 'p1',
        'name': 'Cola',
        'price': 2.0,
        'stock': 10,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final product = Product.fromMap(map);
      expect(product.packages, isEmpty);
      expect(product.looseStock, 10);
    });

    test('fromMap reads looseStock and package inventory', () {
      final map = {
        'id': 'p2',
        'name': 'Mix',
        'price': 1.0,
        'stock': 100,
        'looseStock': 10,
        'packages': [
          {
            'id': 'pk1',
            'name': 'Half',
            'unitsPerPackage': 10,
            'packageCount': 9,
          },
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final product = Product.fromMap(map);
      expect(product.looseStock, 10);
      expect(product.packages.first.packageCount, 9);
      expect(totalBaseUnitsStock(product), 100);
    });
  });

  group('SaleItem baseUnitsSold', () {
    test('returns quantity when no package', () {
      final item = SaleItem(
        productId: 'p1',
        productName: 'Cola',
        quantity: 5,
        price: 2.0,
      );
      expect(item.baseUnitsSold, 5);
    });

    test('returns quantity * unitsPerPackage when package', () {
      final item = SaleItem(
        productId: 'p1',
        productName: 'Pepsi (Half pack)',
        quantity: 2,
        price: 12.0,
        packageId: 'pkg-1',
        packageName: 'Half pack',
        unitsPerPackage: 12,
      );
      expect(item.baseUnitsSold, 24);
    });

    test('round-trips with package metadata', () {
      final item = SaleItem(
        productId: 'p1',
        productName: 'Pepsi (1/4 pack)',
        quantity: 3,
        price: 6.0,
        packageId: 'pkg-1',
        packageName: '1/4 pack',
        unitsPerPackage: 6,
      );
      final map = item.toMap();
      final restored = SaleItem.fromMap(map);
      expect(restored.baseUnitsSold, 18);
      expect(restored.packageId, 'pkg-1');
      expect(restored.packageName, '1/4 pack');
      expect(restored.unitsPerPackage, 6);
    });

    test('fromMap handles legacy items without package fields', () {
      final map = {
        'productId': 'p1',
        'productName': 'Cola',
        'quantity': 4,
        'price': 2.0,
        'subtotal': 8.0,
      };
      final item = SaleItem.fromMap(map);
      expect(item.baseUnitsSold, 4);
      expect(item.packageId, isNull);
      expect(item.packageName, isNull);
      expect(item.unitsPerPackage, isNull);
    });
  });
}
