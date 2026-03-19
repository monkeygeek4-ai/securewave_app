// lib/screens/permissions_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permissions_service.dart';
import '../utils/app_colors.dart';

class PermissionsSettingsScreen extends StatefulWidget {
  const PermissionsSettingsScreen({super.key});

  @override
  State<PermissionsSettingsScreen> createState() =>
      _PermissionsSettingsScreenState();
}

class _PermissionsSettingsScreenState
    extends State<PermissionsSettingsScreen> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final statuses = await PermissionsService.checkAllPermissions();
    setState(() {
      _permissionStatuses = statuses;
      _isLoading = false;
    });
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statuses = await PermissionsService.requestAllPermissions();
      setState(() {
        _permissionStatuses = statuses;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешения запрошены'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка запроса разрешений: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    try {
      final status = await PermissionsService.requestPermission(permission);
      setState(() {
        _permissionStatuses[permission] = status;
      });

      if (mounted) {
        if (status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${PermissionsService.getPermissionName(permission)} разрешено'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${PermissionsService.getPermissionName(permission)} отклонено. Откройте настройки для изменения.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Настройки',
                onPressed: () => PermissionsService.openSystemSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getStatusIcon(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Icons.check_circle;
      case PermissionStatus.denied:
        return Icons.cancel;
      case PermissionStatus.permanentlyDenied:
        return Icons.block;
      case PermissionStatus.restricted:
        return Icons.lock;
      case PermissionStatus.limited:
        return Icons.info;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.grey;
      case PermissionStatus.limited:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Разрешено';
      case PermissionStatus.denied:
        return 'Отклонено';
      case PermissionStatus.permanentlyDenied:
        return 'Отклонено навсегда';
      case PermissionStatus.restricted:
        return 'Ограничено';
      case PermissionStatus.limited:
        return 'Ограничено';
      default:
        return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Разрешения'),
        backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.transparent,
        flexibleSpace: isDarkMode
            ? null
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Кнопка запросить все разрешения
                ElevatedButton.icon(
                  onPressed: _requestAllPermissions,
                  icon: const Icon(Icons.security),
                  label: const Text('Запросить все разрешения'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Статус разрешений:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Список разрешений
                ...PermissionsService.getRequiredPermissions().map((permission) {
                  final status = _permissionStatuses[permission] ??
                      PermissionStatus.denied;
                  final name = PermissionsService.getPermissionName(permission);
                  final description =
                      PermissionsService.getPermissionDescription(permission);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                      ),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(description),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusText(status),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: status.isPermanentlyDenied
                          ? TextButton(
                              onPressed: () => PermissionsService.openSystemSettings(),
                              child: const Text('Настройки'),
                            )
                          : status.isDenied
                              ? TextButton(
                                  onPressed: () => _requestPermission(permission),
                                  child: const Text('Запросить'),
                                )
                              : null,
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}

