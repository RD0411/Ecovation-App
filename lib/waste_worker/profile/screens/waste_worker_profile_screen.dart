import 'package:citizen_impetus/waste_worker/profile/screens/waste_worker_training_screen.dart';
import 'package:citizen_impetus/waste_worker/profile/services/waste_worker_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class WasteWorkerProfileScreen extends StatefulWidget {
  const WasteWorkerProfileScreen({super.key});

  @override
  State<WasteWorkerProfileScreen> createState() => _WasteWorkerProfileScreenState();
}

class _WasteWorkerProfileScreenState extends State<WasteWorkerProfileScreen> {
  final WasteWorkerProfileService _service = WasteWorkerProfileService();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  WasteWorkerProfileData? _data;
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _isEditMode = false;
  String _selectedStatus = 'available';
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
    _vehicleNumberController.dispose();
    _vehicleTypeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    try {
      final WasteWorkerProfileData data =
          await _service.getProfileData(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      _phoneController.text = data.phone;
      _vehicleNumberController.text = data.vehicleNumber;
      _vehicleTypeController.text = data.vehicleType;
      _addressController.text = data.address;
      _selectedStatus = data.status;
      _latitude = data.latitude;
      _longitude = data.longitude;

      setState(() {
        _data = data;
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
        WasteWorkerProfileUpdatePayload(
          phone: _phoneController.text,
          vehicleNumber: _vehicleNumberController.text,
          vehicleType: _vehicleTypeController.text,
          status: _selectedStatus,
          address: _addressController.text,
          latitude: _latitude,
          longitude: _longitude,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker profile updated successfully.')),
      );

      setState(() {
        _isEditMode = false;
      });

      await _loadProfile(forceRefresh: true);
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

  void _cancelEdit() {
    final WasteWorkerProfileData? data = _data;
    if (data == null) {
      return;
    }

    setState(() {
      _phoneController.text = data.phone;
      _vehicleNumberController.text = data.vehicleNumber;
      _vehicleTypeController.text = data.vehicleType;
      _addressController.text = data.address;
      _selectedStatus = data.status;
      _latitude = data.latitude;
      _longitude = data.longitude;
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
        throw Exception('Location service is disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final List<Placemark> places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final Placemark? place = places.isNotEmpty ? places.first : null;
      final String address = _addressFromPlacemark(place);

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressController.text = address.isEmpty
            ? 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}'
            : address;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to fetch location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  String _addressFromPlacemark(Placemark? place) {
    if (place == null) {
      return '';
    }
    final List<String> parts = <String>[
      if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty) place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty) place.administrativeArea!.trim(),
      if ((place.postalCode ?? '').trim().isNotEmpty) place.postalCode!.trim(),
    ];
    return parts.join(', ');
  }

  Future<void> _openTrainingScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const WasteWorkerTrainingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final WasteWorkerProfileData data = _data!;

    return RefreshIndicator(
      onRefresh: () => _loadProfile(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          _buildHeader(data),
          const SizedBox(height: 12),
          _buildKpiGrid(data),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Worker Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2F3D4A),
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _isEditMode = !_isEditMode;
                        }),
                icon: Icon(_isEditMode ? Icons.lock_open : Icons.edit_outlined),
                label: Text(_isEditMode ? 'Editing' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildProfileForm(),
          const SizedBox(height: 12),
          Text(
            'Training & Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2F3D4A),
                ),
          ),
          const SizedBox(height: 8),
          _buildActionCard(
            icon: Icons.menu_book_rounded,
            title: 'Training Modules',
            subtitle: 'Complete operational and safety modules',
            buttonText: 'Open Training',
            onPressed: _openTrainingScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(WasteWorkerProfileData data) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(data.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data.status.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(WasteWorkerProfileData data) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _kpiCard('Assigned', data.assignedRoutes.toString(), Icons.assignment_outlined),
        _kpiCard('Active', data.activeRoutes.toString(), Icons.local_shipping_outlined),
        _kpiCard('Completed', data.completedRoutes.toString(), Icons.task_alt_outlined),
        _kpiCard('Safety', '${data.safetyScore}%', Icons.health_and_safety_outlined),
      ],
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    final double width = (MediaQuery.of(context).size.width - 38) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE4DF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E9B45)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF27333D),
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF74808A),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
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
              controller: _vehicleNumberController,
              label: 'Vehicle Number',
              icon: Icons.pin_outlined,
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _vehicleTypeController,
              label: 'Vehicle Type',
              icon: Icons.fire_truck_outlined,
              readOnly: !_isEditMode,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: 'Availability Status',
                prefixIcon: const Icon(Icons.toggle_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'available', child: Text('Available')),
                DropdownMenuItem(value: 'busy', child: Text('Busy')),
                DropdownMenuItem(value: 'offline', child: Text('Offline')),
              ],
              onChanged: _isEditMode
                  ? (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            _buildField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.location_on_outlined,
              readOnly: !_isEditMode,
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
            if (_latitude != null && _longitude != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    color: Color(0xFF76848E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_isEditMode)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
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
                        ),
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Profile'),
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
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF32973E)),
                  onPressed: () {
                    setState(() {
                      _isEditMode = true;
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Worker Profile'),
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2E9B45)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF2D3943),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF697680),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E9B45)),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF2FA658);
      case 'busy':
        return const Color(0xFFE58D2E);
      case 'offline':
        return const Color(0xFF7A858F);
      default:
        return const Color(0xFF7A858F);
    }
  }
}
