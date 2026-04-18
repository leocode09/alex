import 'dart:convert';
import '../models/employee.dart';
import '../services/database_helper.dart';

class EmployeeRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _employeesKey = 'employees';
  static const String _deletedIdsKey = 'deleted_employee_ids';

  // Get all employees
  Future<List<Employee>> getAllEmployees() async {
    try {
      final jsonData = await _storage.getData(_employeesKey);
      if (jsonData == null) return [];

      final List<dynamic> decoded = jsonDecode(jsonData);
      final employees = decoded.map((json) => Employee.fromMap(json)).toList();

      // Sort by name
      employees.sort((a, b) => a.name.compareTo(b.name));
      return employees;
    } catch (e) {
      print('Error getting all employees: $e');
      return [];
    }
  }

  // Save all employees
  Future<bool> _saveEmployees(List<Employee> employees) async {
    try {
      final jsonList = employees.map((e) => e.toMap()).toList();
      final jsonData = jsonEncode(jsonList);
      return await _storage.saveData(_employeesKey, jsonData);
    } catch (e) {
      print('Error saving employees: $e');
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
    final jsonData = await _storage.getData(_deletedIdsKey);
    if (jsonData == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addDeletedEmployeeIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final existing = (await getDeletedEmployeeIds()).toSet();
    existing.addAll(ids);
    await _storage.saveData(_deletedIdsKey, jsonEncode(existing.toList()));
  }

  Future<void> applyDeletedEmployeeIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deletedSet = ids.toSet();
    final employees = await getAllEmployees();
    final filtered =
        employees.where((e) => !deletedSet.contains(e.id)).toList();
    if (filtered.length < employees.length) {
      await _saveEmployees(filtered);
    }
    await addDeletedEmployeeIds(ids);
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
