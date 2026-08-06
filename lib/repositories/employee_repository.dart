import '../models/employee.dart';
import '../services/database_helper.dart';

class EmployeeRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _employeesKey = 'employees';
  static const String _deletedIdsKey = 'deleted_employee_ids';

  // In-memory caches (static: repositories are instantiated in many places).
  static List<Employee>? _cache;
  static List<String>? _deletedIdsCache;

  // Get all employees
  Future<List<Employee>> getAllEmployees() async {
    final cached = _cache;
    if (cached != null) return List<Employee>.of(cached);
    try {
      final jsonData = await _storage.getData(_employeesKey);
      if (jsonData == null) {
        _cache = <Employee>[];
        return [];
      }

      final List<dynamic> decoded = await decodeJson(jsonData);
      final employees = decoded.map((json) => Employee.fromMap(json)).toList();

      // Sort by name
      employees.sort((a, b) => a.name.compareTo(b.name));
      _cache = employees;
      return List<Employee>.of(employees);
    } catch (e) {
      print('Error getting all employees: $e');
      return [];
    }
  }

  // Save all employees (updates the in-memory cache first so reads are
  // instantly consistent, then persists).
  Future<bool> _saveEmployees(List<Employee> employees) async {
    final snapshot = List<Employee>.of(employees)
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache = snapshot;
    try {
      final jsonList = snapshot.map((e) => e.toMap()).toList();
      final jsonData = await encodeJson(jsonList);
      final success = await _storage.saveData(_employeesKey, jsonData);
      if (!success) {
        // Persist failed: refresh from storage on next read.
        _cache = null;
      }
      return success;
    } catch (e) {
      print('Error saving employees: $e');
      _cache = null;
      return false;
    }
  }

  // Get employee by ID
  Future<Employee?> getEmployeeById(String id) async {
    final employees = await getAllEmployees();
    try {
      return employees.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  // Insert employee
  Future<bool> insertEmployee(Employee employee) async {
    try {
      final employees = await getAllEmployees();
      employees.add(employee);
      return await _saveEmployees(employees);
    } catch (e) {
      print('Error inserting employee: $e');
      return false;
    }
  }

  // Update employee
  Future<bool> updateEmployee(Employee updatedEmployee) async {
    try {
      final employees = await getAllEmployees();
      final index = employees.indexWhere((e) => e.id == updatedEmployee.id);
      if (index != -1) {
        employees[index] = updatedEmployee;
        return await _saveEmployees(employees);
      }
      return false;
    } catch (e) {
      print('Error updating employee: $e');
      return false;
    }
  }

  // Delete employee (records tombstone for cross-device sync propagation)
  Future<bool> deleteEmployee(String id) async {
    try {
      final employees = await getAllEmployees();
      final initialLength = employees.length;
      employees.removeWhere((e) => e.id == id);
      final success = await _saveEmployees(employees);
      if (success && employees.length < initialLength) {
        await addDeletedEmployeeIds([id]);
      }
      return success;
    } catch (e) {
      print('Error deleting employee: $e');
      return false;
    }
  }

  Future<List<String>> getDeletedEmployeeIds() async {
    final cached = _deletedIdsCache;
    if (cached != null) return List<String>.of(cached);
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) {
      _deletedIdsCache = <String>[];
      return [];
    }
    try {
      final List<dynamic> decoded = await decodeJson(jsonData);
      final ids = List<String>.of(decoded.cast<String>());
      _deletedIdsCache = ids;
      return List<String>.of(ids);
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedEmployeeIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedEmployeeIds()).toSet();
    final before = existing.length;
    existing.addAll(ids);
    if (existing.length == before) return;
    final updated = existing.toList();
    _deletedIdsCache = updated;
    final saved =
        await _storage.saveData(_deletedIdsKey, await encodeJson(updated));
    if (!saved) _deletedIdsCache = null;
  }

  /// Returns whether any local employee was actually removed.
  Future<bool> applyDeletedEmployeeIds(List<String> ids) async {
    if (ids.isEmpty) return false;
    final deletedSet = ids.toSet();
    final employees = await getAllEmployees();
    final filtered =
        employees.where((e) => !deletedSet.contains(e.id)).toList();
    final removed = filtered.length < employees.length;
    if (removed) {
      await _saveEmployees(filtered);
    }
    await addDeletedEmployeeIds(ids);
    return removed;
  }

  // Replace all employees (for sync)
  Future<bool> replaceAllEmployees(List<Employee> employees) async {
    return await _saveEmployees(employees);
  }

  // Get active employees
  Future<List<Employee>> getActiveEmployees() async {
    final employees = await getAllEmployees();
    return employees.where((e) => e.isActive).toList();
  }
}
