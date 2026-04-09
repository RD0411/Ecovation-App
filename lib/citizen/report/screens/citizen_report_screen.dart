import 'dart:convert';
import 'dart:io';

import 'package:citizen_impetus/citizen/report/services/citizen_report_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlng;

class CitizenReportScreen extends StatefulWidget {
  const CitizenReportScreen({super.key});

  @override
  State<CitizenReportScreen> createState() => _CitizenReportScreenState();
}

class _CitizenReportScreenState extends State<CitizenReportScreen> {
  final CitizenReportService _service = CitizenReportService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _coordinatesController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<String> _categories = <String>[];

  String? _selectedCategory;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  latlng.LatLng _selectedLocation = const latlng.LatLng(18.5204, 73.8567);

  bool _loading = true;
  bool _submitting = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _loadBootstrap();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _coordinatesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBootstrap({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
    });

    try {
      final CitizenReportBootstrap bootstrap =
          await _service.getReportBootstrap(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = bootstrap.categories;
        _selectedCategory =
            _selectedCategory != null && bootstrap.categories.contains(_selectedCategory)
                ? _selectedCategory
                : (bootstrap.categories.isNotEmpty ? bootstrap.categories.first : null);
        _selectedLocation = bootstrap.defaultLocation;
        _coordinatesController.text = _formatCoordinates(bootstrap.defaultLocation);
        _addressController.text = bootstrap.defaultAddress.trim().isEmpty
            ? 'Resolving address...'
            : bootstrap.defaultAddress;
      });

      _syncAddressFromCoordinates(
        bootstrap.defaultLocation,
        fallbackAddress: bootstrap.defaultAddress,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (file == null || !mounted) {
        return;
      }

      setState(() {
        _pickedImage = file;
        _pickedImageBytes = null;
      });

      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _pickedImageBytes = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick image. Please retry.')),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
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
              content: const Text('Location permission is required for report location.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = latlng.LatLng(position.latitude, position.longitude);
        _coordinatesController.text = _formatCoordinates(_selectedLocation);
      });

      await _syncAddressFromCoordinates(_selectedLocation);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch current location. Please retry.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or choose a photo.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final Uint8List imageBytes = _pickedImageBytes ?? await _pickedImage!.readAsBytes();
      final String imageBase64 = base64Encode(imageBytes);

      await _service.submitReport(
        CitizenReportPayload(
          category: _selectedCategory!,
          note: _noteController.text,
          location: _selectedLocation,
          address: _addressController.text,
          imageBase64: imageBase64,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );

      setState(() {
        _pickedImage = null;
        _pickedImageBytes = null;
        _noteController.clear();
      });

      await _loadBootstrap(forceRefresh: true);
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
          _submitting = false;
        });
      }
    }
  }

  Future<void> _syncAddressFromCoordinates(
    latlng.LatLng location, {
    String? fallbackAddress,
  }) async {
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (!mounted) {
        return;
      }

      final Placemark? place = placemarks.isNotEmpty ? placemarks.first : null;
      final String resolvedAddress = _composeAddress(place);

      setState(() {
        _addressController.text = resolvedAddress.isNotEmpty
            ? resolvedAddress
            : (fallbackAddress?.trim().isNotEmpty == true
                ? fallbackAddress!.trim()
                : 'Address unavailable for selected location');
        _coordinatesController.text = _formatCoordinates(location);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _addressController.text = fallbackAddress?.trim().isNotEmpty == true
            ? fallbackAddress!.trim()
            : 'Address unavailable for selected location';
        _coordinatesController.text = _formatCoordinates(location);
      });
    }
  }

  String _composeAddress(Placemark? place) {
    if (place == null) {
      return '';
    }

    final List<String> parts = <String>[
      if ((place.name ?? '').trim().isNotEmpty) place.name!.trim(),
      if ((place.subLocality ?? '').trim().isNotEmpty) place.subLocality!.trim(),
      if ((place.locality ?? '').trim().isNotEmpty) place.locality!.trim(),
      if ((place.administrativeArea ?? '').trim().isNotEmpty)
        place.administrativeArea!.trim(),
      if ((place.postalCode ?? '').trim().isNotEmpty) place.postalCode!.trim(),
      if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
    ];

    return parts.join(', ');
  }

  String _formatCoordinates(latlng.LatLng point) {
    return 'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadBootstrap(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildPhotoCard(),
          const SizedBox(height: 12),
          _buildLocationCard(),
          const SizedBox(height: 12),
          _buildFormCard(),
          const SizedBox(height: 12),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0.9,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Waste Report',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF243341),
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Capture evidence, pin exact location, and submit for worker assignment.',
              style: TextStyle(
                color: Color(0xFF6C7781),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Card(
      elevation: 0.9,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evidence Photo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2F3D4A),
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 190,
                width: double.infinity,
                color: const Color(0xFFE9EDF0),
                child: _buildImagePreview(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E9B45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImage == null) {
      return const Center(
        child: Icon(Icons.camera_alt_outlined, size: 44, color: Color(0xFF7E8A93)),
      );
    }

    if (_pickedImageBytes != null) {
      return Image.memory(
        _pickedImageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    if (kIsWeb) {
      return const Center(
        child: Text('Loading image preview...'),
      );
    }

    return Image.file(
      File(_pickedImage!.path),
      fit: BoxFit.cover,
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 0.9,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Report Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2F3D4A),
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                  label: const Text('Current'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: gmaps.GoogleMap(
                  initialCameraPosition: gmaps.CameraPosition(
                    target: gmaps.LatLng(
                      _selectedLocation.latitude,
                      _selectedLocation.longitude,
                    ),
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (point) {
                    setState(() {
                      _selectedLocation = latlng.LatLng(point.latitude, point.longitude);
                      _coordinatesController.text = _formatCoordinates(_selectedLocation);
                      _addressController.text = 'Resolving address...';
                    });
                    _syncAddressFromCoordinates(_selectedLocation);
                  },
                  markers: {
                    gmaps.Marker(
                      markerId: const gmaps.MarkerId('report_location'),
                      position: gmaps.LatLng(
                        _selectedLocation.latitude,
                        _selectedLocation.longitude,
                      ),
                    ),
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Human Readable Address',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _coordinatesController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Latitude / Longitude (Live)',
                prefixIcon: const Icon(Icons.my_location_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0.9,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Waste Category',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Add report details (optional)',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.edit_note_outlined),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2E9B45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _submitting ? null : _submitReport,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.send_outlined),
        label: Text(_submitting ? 'Submitting...' : 'Submit Report'),
      ),
    );
  }
}
