import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failure.dart';
import '../domain/location_service.dart';

/// geolocator 插件实现。
///
/// 所有平台异常在这里被翻译成领域层的 [Failure]，上层不需要 import
/// geolocator，也不会因为换定位库而改动。
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<DevicePosition> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationUnavailableFailure(cause: '系统定位服务未开启');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationPermissionFailure(permanentlyDenied: true);
      }
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionFailure();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // 天气只需要城市级精度，低精度更快也更省电。
          accuracy: LocationAccuracy.low,
          timeLimit: AppConfig.locationTimeout,
        ),
      );
      return DevicePosition(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationServiceDisabledException catch (error) {
      throw LocationUnavailableFailure(cause: error);
    } on PermissionDeniedException catch (error) {
      throw LocationPermissionFailure(cause: error);
    } on TimeoutException catch (error) {
      throw LocationUnavailableFailure(cause: error);
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
