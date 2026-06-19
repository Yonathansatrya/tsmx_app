import '../../models/user_access.dart';
import '../frappe_service.dart';

class AuthService {
  final FrappeService _frappe;

  AuthService(this._frappe);

  Future<CurrentUserAccess> fetchCurrentUserAccess(String currentUser) async {
    if (_isAdministrator(currentUser)) {
      return CurrentUserAccess(
        user: currentUser,
        roleProfile: 'Administrator',
        roles: const ['Administrator', 'System Manager'],
      );
    }

    var roleProfile = '';
    var roles = <String>[];
    Object? directLookupError;

    try {
      final user = await _frappe.fetchDocument('User', currentUser);
      roleProfile = _cleanValue(user['role_profile_name']);
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
          roleProfile = _cleanValue(value['role_profile_name']);
        }
      } catch (error) {
        directLookupError ??= error;
      }
    }

    if (roleProfile.isEmpty) {
      try {
        final access = await _frappe.callMethod('tmsx_current_user_access');
        if (access is Map) {
          final returnedUser = _cleanValue(access['user']);
          if (returnedUser.isNotEmpty && returnedUser != currentUser) {
            throw Exception('Identitas session Frappe tidak sesuai.');
          }
          roleProfile = _cleanValue(access['role_profile_name']);
          final rawRoles = access['roles'];
          if (rawRoles is List) {
            roles = rawRoles
                .map(_cleanValue)
                .where((role) => role.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {}
    }

    if (roleProfile.isEmpty) {
      final roleNames = roles.map((role) => role.toLowerCase()).toSet();
      if (roleNames.contains('sales manager')) {
        roleProfile = 'Sales Manager';
      } else if (roleNames.contains('sales')) {
        roleProfile = 'Sales';
      } else if (roleNames.contains('logistics')) {
        roleProfile = 'Logistics';
      }
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

  Future<Map<String, dynamic>> fetchCurrentUserProfile(
    String currentUser,
  ) async {
    return _frappe.fetchDocument('User', currentUser);
  }

  Future<String> uploadCurrentUserImage(
    String currentUser,
    String filePath,
  ) async {
    final uploaded = await _frappe.uploadFile(
      filePath: filePath,
      doctype: 'User',
      documentName: currentUser,
    );
    final fileUrl = uploaded['file_url']?.toString() ?? '';
    if (fileUrl.isEmpty) {
      throw Exception('URL foto profil tidak diterima dari ERPNext.');
    }
    await _frappe.updateDocument('User', currentUser, {'user_image': fileUrl});
    return fileUrl;
  }

  Future<void> changeCurrentUserPassword({
    required String oldPassword,
    required String newPassword,
    bool logoutAllSessions = false,
  }) async {
    await _frappe.callMethod(
      'frappe.core.doctype.user.user.update_password',
      args: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'logout_all_sessions': logoutAllSessions ? 1 : 0,
      },
    );
    _frappe.password = newPassword;
  }

  bool _isAdministrator(String value) =>
      value.trim().toLowerCase() == 'administrator';

  String _cleanValue(Object? value) {
    final cleaned = value?.toString().trim() ?? '';
    if (cleaned.toLowerCase() == 'null' ||
        cleaned.toLowerCase() == 'none' ||
        cleaned.toLowerCase() == 'undefined') {
      return '';
    }
    return cleaned;
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
