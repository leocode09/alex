import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/customer.dart';
import '../models/customer_credit_entry.dart';
import '../repositories/customer_credit_repository.dart';
import '../repositories/customer_repository.dart';
import 'sync_events_provider.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

final customerCreditRepositoryProvider =
    Provider<CustomerCreditRepository>((ref) {
  return CustomerCreditRepository();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(customerRepositoryProvider);
  return await repository.getAllCustomers();
});

final customerByIdProvider =
    FutureProvider.family<Customer?, String>((ref, id) async {
  ref.watch(syncEventsProvider);
  final repository = ref.watch(customerRepositoryProvider);
  return await repository.getCustomerById(id);
});

final creditEntriesForCustomerProvider =
    FutureProvider.family<List<CustomerCreditEntry>, String>(
  (ref, id) async {
    ref.watch(syncEventsProvider);
    final repository = ref.watch(customerCreditRepositoryProvider);
    return await repository.entriesForCustomer(id);
  },
);
