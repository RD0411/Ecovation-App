import 'package:citizen_impetus/Authentication/models/app_role.dart';
import 'package:citizen_impetus/Authentication/screens/login_screen.dart';
import 'package:citizen_impetus/Authentication/screens/role_home_screen.dart';
import 'package:citizen_impetus/Authentication/services/auth_service.dart';
import 'package:flutter/material.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  AppRole? _restoredRole;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final AppAuthUser? restoredUser = await AuthService.restoreSession();
    if (restoredUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isChecking = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _restoredRole = restoredUser.role;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_restoredRole != null) {
      return RoleHomeScreen(role: _restoredRole!);
    }

    return const LoginScreen();
  }
}
