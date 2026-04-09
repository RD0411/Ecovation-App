import 'dart:convert';
import 'dart:io';

import 'package:citizen_impetus/citizen/marketplace/services/citizen_marketplace_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class CreateMarketplaceListingScreen extends StatefulWidget {
  const CreateMarketplaceListingScreen({
    required this.categories,
    super.key,
  });

  final List<String> categories;

  @override
  State<CreateMarketplaceListingScreen> createState() => _CreateMarketplaceListingScreenState();
}

class _CreateMarketplaceListingScreenState extends State<CreateMarketplaceListingScreen> {
  final CitizenMarketplaceService _service = CitizenMarketplaceService();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  String _selectedCategory = 'General';
  XFile? _pickedImage;
  LatLng _location = const LatLng(18.5204, 73.8567);
  bool _submitting = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final List<String> formCategories = widget.categories
        .where((category) => category.trim().isNotEmpty && category.toLowerCase() != 'all')
        .toList();
    _selectedCategory = formCategories.isEmpty ? 'General' : formCategories.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _pickedImage = file;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
    });

    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on location service to auto-fill location.')),
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
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _location = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch current location.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final double? price = double.tryParse(_priceController.text.trim());
    final int? quantity = int.tryParse(_quantityController.text.trim());

    if (title.isEmpty || description.isEmpty || price == null || quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all required fields correctly.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final String? imageBase64 = _pickedImage == null
          ? null
          : base64Encode(await _pickedImage!.readAsBytes());

      await _service.createMarketplaceItem(
        CreateMarketplaceItemPayload(
          title: title,
          category: _selectedCategory,
          price: price,
          quantity: quantity,
          description: description,
          imageBase64: imageBase64,
          location: _location,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final List<String> categories = widget.categories
        .where((category) => category.trim().isNotEmpty && category.toLowerCase() != 'all')
        .toList();
    final bool compact = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Listing'),
        backgroundColor: const Color(0xFF2E9B45),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3F7F3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Item Details',
              icon: Icons.inventory_2_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Item Title',
                      hintText: 'Ex: Segregated Plastic Bottles',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (compact) ...[
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 132,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              prefixIcon: Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe quality, condition and selling notes',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 56),
                        child: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Pickup Location',
              icon: Icons.place_outlined,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCFE1D2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Coordinates',
                      style: TextStyle(
                        color: Color(0xFF5E7077),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_location.latitude.toStringAsFixed(4)}, ${_location.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Color(0xFF2A3A46),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_outlined),
                      label: Text(_locating ? 'Locating...' : 'Use Current Location'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: 'Item Photos',
              icon: Icons.image_outlined,
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 148,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      SizedBox(
                        width: 148,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 170,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6ECE7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD1DCD4)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _pickedImage == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.photo_camera_back_outlined,
                                    size: 34, color: Color(0xFF73828C)),
                                SizedBox(height: 8),
                                Text(
                                  'Add at least one clear item image',
                                  style: TextStyle(
                                    color: Color(0xFF687882),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.file(
                            File(_pickedImage!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E9B45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_business_outlined),
            label: Text(_submitting ? 'Creating Listing...' : 'Create Listing'),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E9B45), Color(0xFF1F7D35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sell Recycled Goods',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Create a detailed listing to reach nearby citizens quickly.',
            style: TextStyle(
              color: Color(0xFFE4F2E6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F2A12),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2E9B45)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF273540),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
