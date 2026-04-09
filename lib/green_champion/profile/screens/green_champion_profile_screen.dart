import '../../services/green_champion_data_source.dart';
import '../../services/green_champion_module_models.dart';
import '../../services/green_champion_module_provider.dart';
import '../../widgets/green_champion_ui.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class GreenChampionProfileScreen extends StatefulWidget {
  const GreenChampionProfileScreen({super.key});

  @override
  State<GreenChampionProfileScreen> createState() => _GreenChampionProfileScreenState();
}

class _GreenChampionProfileScreenState extends State<GreenChampionProfileScreen> {
  final GreenChampionDataSource _repository = GreenChampionModuleProvider.instance;
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  late Future<GreenChampionProfileData> _profileFuture;
  bool _isSavingLocation = false;
  bool _isResolvingReadableLocation = false;
  double? _resolvedLatitude;
  double? _resolvedLongitude;
  String? _readableLocation;

  @override
  void initState() {
    super.initState();
    _profileFuture = _repository.getProfile();
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final Future<GreenChampionProfileData> next =
        _repository.getProfile(forceRefresh: true);
    setState(() {
      _profileFuture = next;
    });
    await next;
  }

  Future<void> _savePermanentLocation() async {
    final double? latitude = double.tryParse(_latitudeController.text.trim());
    final double? longitude = double.tryParse(_longitudeController.text.trim());

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude')),
      );
      return;
    }

    setState(() {
      _isSavingLocation = true;
    });

    try {
      await _repository.setPermanentLocation(
        latitude: latitude,
        longitude: longitude,
      );
      final Future<GreenChampionProfileData> next =
          _repository.getProfile(forceRefresh: true);
      setState(() {
        _profileFuture = next;
      });
      await next;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permanent ambassador location saved successfully'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingLocation = false;
        });
      }
    }
  }

  void _resolveReadableLocationIfNeeded(
    double? latitude,
    double? longitude,
  ) {
    if (latitude == null || longitude == null) {
      _resolvedLatitude = null;
      _resolvedLongitude = null;
      _readableLocation = null;
      return;
    }

    final bool sameAsLast =
        _resolvedLatitude == latitude && _resolvedLongitude == longitude;
    if (sameAsLast || _isResolvingReadableLocation) {
      return;
    }

    _isResolvingReadableLocation = true;
    _resolvedLatitude = latitude;
    _resolvedLongitude = longitude;

    placemarkFromCoordinates(latitude, longitude)
        .then((List<Placemark> places) {
      if (!mounted) {
        return;
      }

      final Placemark? place = places.isEmpty ? null : places.first;
      final List<String> parts = _buildPreciseAddress(place);

      setState(() {
        _readableLocation = parts.isNotEmpty ? parts.join(', ') : null;
      });
    }).catchError((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _readableLocation = null;
      });
    }).whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isResolvingReadableLocation = false;
      });
    });
  }

  List<String> _buildPreciseAddress(Placemark? place) {
    if (place == null) {
      return <String>[];
    }

    final List<String?> candidates = <String?>[
      place.name,
      place.street,
      place.subThoroughfare,
      place.thoroughfare,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ];

    final List<String> parts = <String>[];
    for (final String? item in candidates) {
      final String value = (item ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      if (parts.any((String existing) => existing.toLowerCase() == value.toLowerCase())) {
        continue;
      }
      parts.add(value);
    }

    return parts;
  }

  String _profileLocationText(GreenChampionProfileData profile) {
    if (profile.latitude == null || profile.longitude == null) {
      return 'Not set';
    }

    if (_readableLocation != null && _readableLocation!.trim().isNotEmpty) {
      return _readableLocation!;
    }

    if (_isResolvingReadableLocation) {
      return 'Resolving location...';
    }

    return '${profile.latitude!.toStringAsFixed(6)}, ${profile.longitude!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<GreenChampionProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Text(
                  'Failed to load profile: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            );
          }

          final GreenChampionProfileData profile = snapshot.data ??
              const GreenChampionProfileData(
                name: 'Green Champion',
                email: 'No email',
                points: 0,
                ward: '-',
                badge: '-',
                missionsCompleted: 0,
                verificationAccuracy: 0,
                latitude: null,
                longitude: null,
              );

          if (_latitudeController.text.isEmpty && profile.latitude != null) {
            _latitudeController.text = profile.latitude!.toStringAsFixed(6);
          }
          if (_longitudeController.text.isEmpty && profile.longitude != null) {
            _longitudeController.text = profile.longitude!.toStringAsFixed(6);
          }

          _resolveReadableLocationIfNeeded(profile.latitude, profile.longitude);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                decoration: GreenChampionUi.heroDecoration,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // const Text(
                    //   'My Profile',
                    //   style: TextStyle(
                    //     color: Colors.white,
                    //     fontSize: 24,
                    //     fontWeight: FontWeight.w800,
                    //   ),
                    // ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: 0.24),
                          child: const Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile.email,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GreenChampionUi.sectionTitle(
                'Champion Details',
                subtitle: 'Identity and operational assignment',
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _detailRow('Role', 'Green Champion'),
                      _detailRow('Badge', profile.badge),
                      _detailRow(
                        'Location',
                        _profileLocationText(profile),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GreenChampionUi.sectionTitle(
                'Ambassador Area (2 km Radius)',
                subtitle: 'Set permanent location for stable local coverage',
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _isSavingLocation ? null : _savePermanentLocation,
                        child: _isSavingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Permanent Location'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GreenChampionUi.sectionTitle(
                'Performance',
                subtitle: 'Progress and moderation quality',
              ),
              const SizedBox(height: 10),
              GreenChampionUi.statTile(
                label: 'Champion Points',
                value: '${profile.points}',
                icon: Icons.workspace_premium_rounded,
                tone: const Color(0xFF246BFD),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.flag_circle_rounded,
                              color: GreenChampionUi.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${profile.missionsCompleted}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text('Missions'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.track_changes_rounded,
                              color: GreenChampionUi.primary,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${profile.verificationAccuracy}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text('Accuracy'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF617166),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(':  '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A3A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
