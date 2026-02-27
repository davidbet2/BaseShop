import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Repository that synchronizes addresses with the backend API.
/// Uses SharedPreferences as a local cache for offline/fallback.
class AddressRepository {
  final ApiClient _apiClient;
  static const _cacheKey = 'user_addresses';

  AddressRepository(this._apiClient);

  /// Fetch addresses from API, falling back to local cache on error.
  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.addresses);
      final data = response.data;
      final List<dynamic> raw = data['addresses'] ?? [];
      final addresses = raw.map((a) => Map<String, dynamic>.from(a)).toList();

      // Update local cache
      await _saveToCache(addresses);
      return addresses;
    } catch (e) {
      // Fallback to cached data
      return _loadFromCache();
    }
  }

  /// Create a new address via API.
  Future<Map<String, dynamic>> createAddress({
    required String label,
    required String address,
    required String city,
    String? state,
    String? zipCode,
    String? country,
    bool isDefault = false,
    // Extra fields stored locally for richer UI
    String? name,
    String? phone,
  }) async {
    final response = await _apiClient.dio.post(
      ApiConstants.addresses,
      data: {
        'label': label,
        'address': address,
        'city': city,
        'state': state ?? '',
        'zip_code': zipCode ?? '',
        'country': country ?? 'Colombia',
        'is_default': isDefault,
      },
    );
    final created = Map<String, dynamic>.from(response.data['address'] ?? {});

    // Attach extra local-only fields
    if (name != null && name.isNotEmpty) created['name'] = name;
    if (phone != null && phone.isNotEmpty) created['phone'] = phone;

    // Refresh cache
    await getAddresses();
    return created;
  }

  /// Update an existing address via API.
  Future<Map<String, dynamic>> updateAddress(
    String id, {
    String? label,
    String? address,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    bool? isDefault,
  }) async {
    final data = <String, dynamic>{};
    if (label != null) data['label'] = label;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (zipCode != null) data['zip_code'] = zipCode;
    if (country != null) data['country'] = country;
    if (isDefault != null) data['is_default'] = isDefault;

    final response = await _apiClient.dio.put(
      '${ApiConstants.addresses}/$id',
      data: data,
    );
    final updated = Map<String, dynamic>.from(response.data['address'] ?? {});

    // Refresh cache
    await getAddresses();
    return updated;
  }

  /// Delete an address via API.
  Future<void> deleteAddress(String id) async {
    await _apiClient.dio.delete('${ApiConstants.addresses}/$id');
    // Refresh cache
    await getAddresses();
  }

  /// Set an address as default via API.
  Future<void> setDefault(String id) async {
    await updateAddress(id, isDefault: true);
  }

  // ── Local cache helpers ──────────────────────────────────

  Future<void> _saveToCache(List<Map<String, dynamic>> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(addresses));
  }

  Future<List<Map<String, dynamic>>> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey) ?? '[]';
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }
}
