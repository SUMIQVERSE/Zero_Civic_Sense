import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

class CivicLocationException implements Exception {
  const CivicLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<LocationDraft> resolveCurrentLocation({
  required String permissionDeniedMessage,
  required String locationUnavailableMessage,
  required String serviceDisabledMessage,
  String userAgent = 'CIVICSETU Flutter App',
}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw CivicLocationException(serviceDisabledMessage);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw CivicLocationException(permissionDeniedMessage);
  }

  try {
    final position = await Geolocator.getCurrentPosition();
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': userAgent},
    );

    String state = '';
    String city = '';
    String address = '';

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final addressMap = data['address'] as Map<String, dynamic>? ?? {};
      state = (addressMap['state'] ?? '').toString();
      city = (addressMap['city'] ??
              addressMap['town'] ??
              addressMap['village'] ??
              addressMap['county'] ??
              '')
          .toString();
      address = (data['display_name'] ?? '').toString();
    }

    return LocationDraft(
      latitude: position.latitude,
      longitude: position.longitude,
      state: state,
      city: city,
      address: address,
      accuracyMeters: position.accuracy,
    );
  } catch (_) {
    throw CivicLocationException(locationUnavailableMessage);
  }
}
