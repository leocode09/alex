import 'package:flutter_riverpod/flutter_riverpod.dart';

// Categories list provider (simple list of category names)
final categoriesListProvider = FutureProvider<List<String>>((ref) async {
  // Return a default list of categories
  return [
    'Electronics',
    'Clothing',
    'Food & Beverages',
    'Home & Garden',
    'Sports',
    'Books',
    'Toys',
    'Other',
  ];
});
