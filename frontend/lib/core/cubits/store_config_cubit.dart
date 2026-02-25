import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baseshop/core/services/store_config_service.dart';

class StoreConfigCubit extends Cubit<StoreConfigState> {
  final StoreConfigService _service;

  StoreConfigCubit(this._service) : super(StoreConfigLoading());

  Future<void> loadConfig() async {
    // Don't emit loading if already loaded — prevents flash of fallback values
    if (state is! StoreConfigLoaded) {
      emit(StoreConfigLoading());
    }
    try {
      final config = await _service.getConfig();
      emit(StoreConfigLoaded(config));
      // Cache config values for instant startup next time (no color flash)
      _cacheConfig(config);
    } catch (e) {
      if (state is! StoreConfigLoaded) {
        emit(StoreConfigError(e.toString()));
      }
    }
  }

  /// Persists essential config values to SharedPreferences so the next
  /// app launch can use them immediately instead of showing default orange.
  Future<void> _cacheConfig(StoreConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_primary_color_hex', config.primaryColorHex);
      await prefs.setString('cached_store_name', config.storeName);
      await prefs.setString('cached_store_logo', config.storeLogo);
    } catch (_) {}
  }

  Future<void> updateConfig({
    bool? showHeader,
    bool? showFooter,
    String? storeName,
    String? storeLogo,
    String? featuredTitle,
    String? featuredDesc,
    String? primaryColorHex,
    List<BannerConfig>? banners,
  }) async {
    final currentState = state;
    if (currentState is! StoreConfigLoaded) return;

    try {
      final config = await _service.updateConfig(
        showHeader: showHeader,
        showFooter: showFooter,
        storeName: storeName,
        storeLogo: storeLogo,
        featuredTitle: featuredTitle,
        featuredDesc: featuredDesc,
        primaryColorHex: primaryColorHex,
        banners: banners,
      );
      emit(StoreConfigLoaded(config));
      _cacheConfig(config);
    } catch (e) {
      emit(StoreConfigError(e.toString()));
    }
  }

  Future<void> addBanner(BannerConfig banner) async {
    final currentState = state;
    if (currentState is! StoreConfigLoaded) return;

    try {
      final banners = [...currentState.config.banners, banner];
      final config = await _service.updateConfig(banners: banners);
      emit(StoreConfigLoaded(config));
    } catch (e) {
      emit(StoreConfigError(e.toString()));
    }
  }

  Future<void> removeBanner(int index) async {
    final currentState = state;
    if (currentState is! StoreConfigLoaded) return;

    try {
      final banners = [...currentState.config.banners];
      banners.removeAt(index);
      final config = await _service.updateConfig(banners: banners);
      emit(StoreConfigLoaded(config));
    } catch (e) {
      emit(StoreConfigError(e.toString()));
    }
  }
}

abstract class StoreConfigState {
  const StoreConfigState();
}

class StoreConfigLoading extends StoreConfigState {}

class StoreConfigLoaded extends StoreConfigState {
  final StoreConfig config;
  // Version counter ensures every instance is unique, forcing BlocBuilder rebuilds
  final int _version;
  static int _nextVersion = 0;
  StoreConfigLoaded(this.config) : _version = _nextVersion++;
}

class StoreConfigError extends StoreConfigState {
  final String message;
  const StoreConfigError(this.message);
}
