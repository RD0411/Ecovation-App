import 'package:citizen_impetus/citizen/profile/services/citizen_profile_service.dart';
import 'package:citizen_impetus/citizen/profile/screens/citizen_community_events_screen.dart';
import 'package:citizen_impetus/citizen/profile/screens/citizen_distribution_screen.dart';
import 'package:citizen_impetus/citizen/profile/screens/citizen_training_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class CitizenProfileScreen extends StatefulWidget {
  const CitizenProfileScreen({super.key});

  @override
  State<CitizenProfileScreen> createState() => _CitizenProfileScreenState();
}

class _CitizenProfileScreenState extends State<CitizenProfileScreen> {
  final CitizenProfileService _service = CitizenProfileService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();

  CitizenProfileData? _data;
  List<CitizenProfileTask> _tasks = <CitizenProfileTask>[];
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _isEditMode = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenProfileData data =
          await _service.getProfileData(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      _phoneController.text = data.phone;
      _addressController.text = data.address;
      _ageController.text = data.age;
      _genderController.text = data.gender;

      setState(() {
        _data = data;
        _tasks = List<CitizenProfileTask>.from(data.tasks);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
    });

    try {
      await _service.saveProfile(
        CitizenProfileUpdatePayload(
          phone: _phoneController.text,
          address: _addressController.text,
          latitude: _latitude,
          longitude: _longitude,
          age: _ageController.text,
          gender: _genderController.text,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile info saved.')),
      );

      setState(() {
        _isEditMode = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  void _cancelEdit() {
    final CitizenProfileData? data = _data;
    if (data == null) {
      return;
    }

    setState(() {
      _phoneController.text = data.phone;
      _addressController.text = data.address;
      _ageController.text = data.age;
      _genderController.text = data.gender;
      _isEditMode = false;
    });
  }

  Future<void> _syncCurrentLocation() async {
    setState(() {
      _locating = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location service is disabled. Please turn it on.'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: Geolocator.openLocationSettings,
              ),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is required for real-time address.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to get location. Try again outdoors or enable GPS.')),
          );
        }
        return;
      }

      final Position resolvedPosition = position;

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = resolvedPosition.latitude;
        _longitude = resolvedPosition.longitude;
        _addressController.text =
            'Lat: ${resolvedPosition.latitude.toStringAsFixed(6)}, Lng: ${resolvedPosition.longitude.toStringAsFixed(6)}';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to fetch current location. Please retry.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final CitizenProfileData data = _data!;

    return RefreshIndicator(
      onRefresh: () => _loadProfile(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          _buildProfileHeaderCard(data),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2F3D4A),
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _toggleEditMode,
                icon: Icon(_isEditMode ? Icons.lock_open : Icons.edit_outlined),
                label: Text(_isEditMode ? 'Editing' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProfileFormCard(),
          const SizedBox(height: 12),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2F3D4A),
                ),
          ),
          const SizedBox(height: 8),
          ..._tasks.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildTaskCard(entry.value, entry.key),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(CitizenProfileData data) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF28323B),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              data.email,
              style: const TextStyle(
                color: Color(0xFF8E989F),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Points: ${data.points}',
              style: const TextStyle(
                color: Color(0xFF2FA658),
                fontWeight: FontWeight.w800,
                fontSize: 34 / 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileFormCard() {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _addressController,
              label: 'Real-time Address',
              icon: Icons.location_on_outlined,
              readOnly: true,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: (_locating || !_isEditMode) ? null : _syncCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: const Text('Use Current Location'),
              ),
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _ageController,
              label: 'Age',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _genderController,
              label: 'Gender',
              icon: Icons.person_outline,
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 12),
            if (_isEditMode)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saving ? null : _cancelEdit,
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF32973E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Info'),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF32973E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleEditMode,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Personal Info'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTaskCard(CitizenProfileTask task, int index) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF32973E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (task.title == 'Training') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CitizenTrainingScreen(),
                  ),
                );
                return;
              }

              if (task.title == 'Distribution') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CitizenDistributionScreen(),
                  ),
                );
                return;
              }

              if (task.title == 'Community Events') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CitizenCommunityEventsScreen(),
                  ),
                );
                return;
              }

              setState(() {
                final CitizenProfileTask updated = CitizenProfileTask(
                  title: task.title,
                  done: !task.done,
                );
                _tasks[index] = updated;
              });
            },
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            label: Text(task.title),
          ),
        ),
      ),
    );
  }
}
