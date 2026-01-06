import 'dart:convert';
import '../models/employee.dart';
import '../services/database_helper.dart';

class EmployeeRepository {
  final StorageHelper _storage = StorageHelper();
  static const String _employeesKey = 'employees';

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

  // Delete employee
  Future<bool> deleteEmployee(String id) async {
    try {
      final employees = await getAllEmployees();
      employees.removeWhere((e) => e.id == id);
      return await _saveEmployees(employees);
    } catch (e) {
      print('Error deleting employee: $e');
      return false;
    }
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
