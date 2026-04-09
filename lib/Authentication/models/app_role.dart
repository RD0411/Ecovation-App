import 'package:flutter/material.dart';

enum AppRole {
  citizen,
  wasteWorker,
  greenChampion,
}

class RoleTabItem {
  const RoleTabItem({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

extension AppRoleX on AppRole {
  static AppRole? fromValue(String? value) {
    if (value == null) {
      return null;
    }

    for (final AppRole role in AppRole.values) {
      if (role.value == value) {
        return role;
      }
    }

    return null;
  }

  String get value {
    switch (this) {
      case AppRole.citizen:
        return 'citizen';
      case AppRole.wasteWorker:
        return 'waste_worker';
      case AppRole.greenChampion:
        return 'green_champion';
    }
  }

  String get title {
    switch (this) {
      case AppRole.citizen:
        return 'Citizen';
      case AppRole.wasteWorker:
        return 'Waste Worker';
      case AppRole.greenChampion:
        return 'Green Champion';
    }
  }

  String get subtitle {
    switch (this) {
      case AppRole.citizen:
        return 'Report waste and track your green impact';
      case AppRole.wasteWorker:
        return 'Manage assigned pickups and complete routes';
      case AppRole.greenChampion:
        return 'Review reports and monitor community waste zones';
    }
  }

  List<RoleTabItem> get tabs {
    switch (this) {
      case AppRole.citizen:
        return const [
          RoleTabItem(
            key: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
          ),
          RoleTabItem(
            key: 'report',
            label: 'Report',
            icon: Icons.report_problem_outlined,
          ),
          RoleTabItem(
            key: 'marketplace',
            label: 'Marketplace',
            icon: Icons.storefront_outlined,
          ),
          RoleTabItem(
            key: 'profile',
            label: 'Profile',
            icon: Icons.person_outline,
          ),
        ];
      case AppRole.wasteWorker:
        return const [
          RoleTabItem(
            key: 'dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
          ),
          RoleTabItem(
            key: 'assigned',
            label: 'Assigned',
            icon: Icons.assignment_turned_in_outlined,
          ),
          RoleTabItem(
            key: 'profile',
            label: 'Profile',
            icon: Icons.person_outline,
          ),
        ];
      case AppRole.greenChampion:
        return const [
          RoleTabItem(
            key: 'home',
            label: 'Home',
            icon: Icons.home_outlined,
          ),
          RoleTabItem(
            key: 'report',
            label: 'Report',
            icon: Icons.verified_outlined,
          ),
          RoleTabItem(
            key: 'map',
            label: 'Map',
            icon: Icons.map_outlined,
          ),
          RoleTabItem(
            key: 'profile',
            label: 'Profile',
            icon: Icons.person_outline,
          ),
        ];
    }
  }
}

