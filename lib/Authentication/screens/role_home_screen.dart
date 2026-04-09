import '../models/app_role.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../../citizen/dashboard/screens/citizen_dashboard_screen.dart';
import '../../citizen/marketplace/screens/citizen_marketplace_screen.dart';
import '../../citizen/profile/screens/citizen_profile_screen.dart';
import '../../citizen/report/screens/citizen_report_screen.dart';
import '../../green_champion/home/screens/green_champion_home_screen.dart';
import '../../green_champion/map/screens/green_champion_map_screen.dart';
import '../../green_champion/profile/screens/green_champion_profile_screen.dart';
import '../../green_champion/report/screens/green_champion_report_screen.dart';
import 'package:flutter/material.dart';
import '../../waste_worker/assigned/screens/waste_worker_assigned_screen.dart';
import '../../waste_worker/dashboard/screens/waste_worker_dashboard_screen.dart';
import '../../waste_worker/profile/screens/waste_worker_profile_screen.dart';

class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({
    super.key,
    required this.role,
  });

  final AppRole role;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  int _currentIndex = 0;
  bool _openWasteWorkerRouteView = false;
  List<Widget>? _citizenTabScreens;
  List<Widget>? _greenChampionTabScreens;

  @override
  void initState() {
    super.initState();
    if (widget.role == AppRole.citizen) {
      _citizenTabScreens = widget.role.tabs
          .map((RoleTabItem tab) => _buildCitizenScreen(tab.key))
          .toList(growable: false);
    }
    if (widget.role == AppRole.greenChampion) {
      _greenChampionTabScreens = widget.role.tabs
          .map((RoleTabItem tab) => _buildGreenChampionScreen(tab.key))
          .toList(growable: false);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
    } catch (_) {
      // Navigation proceeds even if sign out returns an error on stale session.
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<RoleTabItem> tabs = widget.role.tabs;
    final RoleTabItem activeTab = tabs[_currentIndex];
    final bool isCitizenMainTab =
        widget.role == AppRole.citizen &&
        <String>['dashboard', 'report', 'marketplace', 'profile']
            .contains(activeTab.key);
    final bool isGreenChampionTab = widget.role == AppRole.greenChampion;
    final bool isWasteWorkerTab = widget.role == AppRole.wasteWorker;
    final bool useGreenAppBar =
      isCitizenMainTab || isGreenChampionTab || isWasteWorkerTab;

    return Scaffold(
      appBar: AppBar(
      backgroundColor: useGreenAppBar ? const Color(0xFF2E9B45) : null,
      foregroundColor: useGreenAppBar ? Colors.white : null,
        title: Text('${widget.role.title} - ${activeTab.label}'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(tabs, activeTab),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildBody(List<RoleTabItem> tabs, RoleTabItem activeTab) {
    if (widget.role == AppRole.citizen &&
        _citizenTabScreens != null &&
        _citizenTabScreens!.length == tabs.length) {
      return IndexedStack(
        index: _currentIndex,
        children: _citizenTabScreens!,
      );
    }

    if (widget.role == AppRole.greenChampion &&
        _greenChampionTabScreens != null &&
        _greenChampionTabScreens!.length == tabs.length) {
      return IndexedStack(
        index: _currentIndex,
        children: _greenChampionTabScreens!,
      );
    }

    if (widget.role == AppRole.wasteWorker) {
      return IndexedStack(
        index: _currentIndex,
        children: tabs
            .map((RoleTabItem tab) => _buildWasteWorkerScreen(tab.key))
            .toList(growable: false),
      );
    }

    return _buildRoleScreen(widget.role, activeTab.key);
  }

  Widget _buildCitizenScreen(String tabKey) {
    switch (tabKey) {
      case 'dashboard':
        return const CitizenDashboardScreen();
      case 'report':
        return const CitizenReportScreen();
      case 'marketplace':
        return const CitizenMarketplaceScreen();
      case 'profile':
        return const CitizenProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGreenChampionScreen(String tabKey) {
    switch (tabKey) {
      case 'home':
        return const GreenChampionHomeScreen();
      case 'report':
        return const GreenChampionReportScreen();
      case 'map':
        return const GreenChampionMapScreen();
      case 'profile':
        return const GreenChampionProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWasteWorkerScreen(String tabKey) {
    switch (tabKey) {
      case 'dashboard':
        return WasteWorkerDashboardScreen(
          openRouteView: _openWasteWorkerRouteView,
          onRouteViewHandled: () {
            if (_openWasteWorkerRouteView) {
              setState(() {
                _openWasteWorkerRouteView = false;
              });
            }
          },
        );
      case 'assigned':
        return WasteWorkerAssignedScreen(
          onViewAssignedRoute: () {
            setState(() {
              _openWasteWorkerRouteView = true;
              _currentIndex = 0;
            });
          },
        );
      case 'profile':
        return const WasteWorkerProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRoleScreen(AppRole role, String tabKey) {
    switch (role) {
      case AppRole.citizen:
        switch (tabKey) {
          case 'dashboard':
            return const CitizenDashboardScreen();
          case 'report':
            return const CitizenReportScreen();
          case 'marketplace':
            return const CitizenMarketplaceScreen();
          case 'profile':
            return const CitizenProfileScreen();
        }
      case AppRole.wasteWorker:
        switch (tabKey) {
          case 'dashboard':
            return WasteWorkerDashboardScreen(
              openRouteView: _openWasteWorkerRouteView,
              onRouteViewHandled: () {
                if (_openWasteWorkerRouteView) {
                  setState(() {
                    _openWasteWorkerRouteView = false;
                  });
                }
              },
            );
          case 'assigned':
            return WasteWorkerAssignedScreen(
              onViewAssignedRoute: () {
                setState(() {
                  _openWasteWorkerRouteView = true;
                  _currentIndex = 0;
                });
              },
            );
          case 'profile':
            return const WasteWorkerProfileScreen();
        }
      case AppRole.greenChampion:
        switch (tabKey) {
          case 'home':
            return const GreenChampionHomeScreen();
          case 'report':
            return const GreenChampionReportScreen();
          case 'map':
            return const GreenChampionMapScreen();
          case 'profile':
            return const GreenChampionProfileScreen();
        }
    }

    return const SizedBox.shrink();
  }
}
