import '../../models/user_access.dart';
import '../frappe_service.dart';

class AuthService {
  final FrappeService _frappe;

  AuthService(this._frappe);

  Future<CurrentUserAccess> fetchCurrentUserAccess(String currentUser) async {
    var roleProfile = '';
    var roles = <String>[];
    Object? directLookupError;

    try {
      final user = await _frappe.fetchDocument('User', currentUser);
      roleProfile = user['role_profile_name']?.toString().trim() ?? '';
    } catch (error) {
      directLookupError = error;
    }

    if (roleProfile.isEmpty) {
      try {
        final value = await _frappe.callMethod(
          'frappe.client.get_value',
          args: {
            'doctype': 'User',
            'filters': {'name': currentUser},
            'fieldname': 'role_profile_name',
          },
        );
        if (value is Map) {
          roleProfile = value['role_profile_name']?.toString().trim() ?? '';
        }
      } catch (error) {
        directLookupError ??= error;
      }
    }

    if (roleProfile.isEmpty) {
      try {
        final access = await _frappe.callMethod('tmsx_current_user_access');
        if (access is Map) {
          final returnedUser = access['user']?.toString().trim() ?? '';
          if (returnedUser.isNotEmpty && returnedUser != currentUser) {
            throw Exception('Identitas session Frappe tidak sesuai.');
          }
          roleProfile = access['role_profile_name']?.toString().trim() ?? '';
          final rawRoles = access['roles'];
          if (rawRoles is List) {
            roles = rawRoles
                .map((role) => role.toString().trim())
                .where((role) => role.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {}
    }

    if (roleProfile.isEmpty &&
        roles.any((role) => role.toLowerCase() == 'sales')) {
      roleProfile = 'Sales';
    }
    if (roleProfile.isEmpty) {
      throw Exception(
        'Role Profile akun tidak dapat dibaca. Admin Frappe perlu membuat '
        'Server Script API "tmsx_current_user_access".'
        '${directLookupError == null ? '' : ' Detail: $directLookupError'}',
      );
    }

    return CurrentUserAccess(
      user: currentUser,
      roleProfile: roleProfile,
      roles: roles,
    );
  }

  Future<SalesIdentity> resolveSalesIdentity(String currentUser) async {
    List<Map<String, dynamic>> employees;
    try {
      try {
        employees = await _frappe.fetchResource(
          'Employee',
          fields: const [
            'name',
            'employee_name',
            'user_id',
            'status',
            'company',
            'designation',
            'department',
            'branch',
            'date_of_joining',
          ],
          filters: [
            ['user_id', '=', currentUser],
          ],
          limit: 1,
        );
      } catch (_) {
        employees = await _frappe.fetchResource(
          'Employee',
          fields: const ['name'],
          filters: [
            ['user_id', '=', currentUser],
          ],
          limit: 1,
        );
      }
    } catch (error) {
      throw Exception(
        'Role Sales tidak memiliki izin membaca mapping Employee.user_id. '
        'Detail: $error',
      );
    }

    if (employees.isEmpty) {
      throw Exception(
        'User $currentUser belum terhubung ke Employee melalui field User ID.',
      );
    }
    final employeeProfile = Map<String, dynamic>.from(employees.first);
    final employee = employeeProfile['name']?.toString() ?? '';

    List<Map<String, dynamic>> salesPersons;
    try {
      salesPersons = await _frappe.fetchResource(
        'Sales Person',
        fields: const ['name'],
        filters: [
          ['employee', '=', employee],
          ['is_group', '=', 0],
        ],
        limit: 1,
      );
    } catch (error) {
      throw Exception(
        'Role Sales tidak memiliki izin membaca mapping Sales Person.employee. '
        'Detail: $error',
      );
    }
    if (salesPersons.isEmpty) {
      throw Exception(
        'Employee $employee belum terhubung ke Sales Person non-group.',
      );
    }

    return SalesIdentity(
      employee: employee,
      employeeProfile: employeeProfile,
      salesPerson: salesPersons.first['name']?.toString() ?? '',
    );
  }
}
