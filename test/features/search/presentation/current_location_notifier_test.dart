import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/providers/app_providers.dart';
import 'package:weather/core/state/selected_location_provider.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/search/domain/location_service.dart';
import 'package:weather/features/search/domain/repository/reverse_geocoder.dart';
import 'package:weather/features/search/presentation/providers/current_location_provider.dart';
import 'package:weather/features/search/presentation/providers/search_providers.dart';

import '../../../helpers/fixtures.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.failure});

  final Failure? failure;

  @override
  Future<DevicePosition> currentPosition() async {
    final error = failure;
    if (error != null) throw error;
    return const DevicePosition(latitude: 25.03, longitude: 121.56);
  }

  @override
  Future<bool> openSettings() async => true;
}

class _FakeReverseGeocoder implements ReverseGeocoder {
  _FakeReverseGeocoder({this.location});

  final Location? location;

  @override
  Future<Location?> reverse({
    required double latitude,
    required double longitude,
    RequestToken? cancelToken,
  }) async => location;
}

Future<ProviderContainer> _createContainer({
  Failure? locationFailure,
  Location? reversed,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      locationServiceProvider.overrideWithValue(
        _FakeLocationService(failure: locationFailure),
      ),
      reverseGeocoderProvider.overrideWithValue(
        _FakeReverseGeocoder(location: reversed),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('定位成功后写入选中地点，天气随之自动加载', () async {
    final container = await _createContainer(reversed: taipei);

    final failure = await container
        .read(currentLocationProvider.notifier)
        .locate();

    expect(failure, isNull);
    expect(container.read(selectedLocationProvider)?.name, '台北');
    expect(
      container.read(currentLocationProvider),
      isFalse,
      reason: '定位结束应复位加载态',
    );
  });

  test('拒绝权限时返回 Failure 且不改变选中地点', () async {
    final container = await _createContainer(
      locationFailure: const LocationPermissionFailure(),
    );

    final failure = await container
        .read(currentLocationProvider.notifier)
        .locate();

    expect(failure, isA<LocationPermissionFailure>());
    expect(container.read(selectedLocationProvider), isNull);
    expect(container.read(currentLocationProvider), isFalse);
  });

  test('反查失败仍会选中「当前位置」，不阻塞功能', () async {
    final container = await _createContainer();

    final failure = await container
        .read(currentLocationProvider.notifier)
        .locate();

    expect(failure, isNull);
    expect(container.read(selectedLocationProvider)?.name, '当前位置');
  });
}
