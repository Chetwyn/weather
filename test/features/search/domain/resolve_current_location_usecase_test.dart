import 'package:flutter_test/flutter_test.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/search/domain/location_service.dart';
import 'package:weather/features/search/domain/repository/reverse_geocoder.dart';
import 'package:weather/features/search/domain/usecase/resolve_current_location_usecase.dart';

import '../../../helpers/fixtures.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.failure});

  final Failure? failure;
  int callCount = 0;

  @override
  Future<DevicePosition> currentPosition() async {
    callCount++;
    final error = failure;
    if (error != null) throw error;
    return const DevicePosition(latitude: 25.03, longitude: 121.56);
  }

  @override
  Future<bool> openSettings() async => true;
}

class _FakeReverseGeocoder implements ReverseGeocoder {
  _FakeReverseGeocoder({this.location, this.failure});

  final Location? location;
  final Failure? failure;
  int callCount = 0;

  @override
  Future<Location?> reverse({
    required double latitude,
    required double longitude,
    RequestToken? cancelToken,
  }) async {
    callCount++;
    final error = failure;
    if (error != null) throw error;
    return location;
  }
}

void main() {
  test('定位成功且反查成功时使用地名', () async {
    final useCase = ResolveCurrentLocationUseCase(
      _FakeLocationService(),
      _FakeReverseGeocoder(location: taipei),
    );

    final location = await useCase();

    expect(location.name, '台北');
  });

  test('反查返回 null 时用「当前位置」兜底，坐标取自设备', () async {
    final useCase = ResolveCurrentLocationUseCase(
      _FakeLocationService(),
      _FakeReverseGeocoder(),
    );

    final location = await useCase();

    expect(location.name, zh.currentLocation);
    expect(location.id, ResolveCurrentLocationUseCase.currentLocationId);
    expect(location.latitude, 25.03);
    expect(location.longitude, 121.56);
  });

  test('反查失败不视为整体失败，仍然返回兜底地点', () async {
    final useCase = ResolveCurrentLocationUseCase(
      _FakeLocationService(),
      _FakeReverseGeocoder(failure: const TimeoutFailure()),
    );

    final location = await useCase();

    expect(location.name, zh.currentLocation);
  });

  test('无定位权限时向上抛出，且不发起反查请求', () async {
    final reverse = _FakeReverseGeocoder(location: taipei);
    final useCase = ResolveCurrentLocationUseCase(
      _FakeLocationService(
        failure: const LocationPermissionFailure(permanentlyDenied: true),
      ),
      reverse,
    );

    await expectLater(useCase(), throwsA(isA<LocationPermissionFailure>()));
    expect(reverse.callCount, 0);
  });

  test('定位服务不可用时的文案可读且可重试', () async {
    const failure = LocationUnavailableFailure();
    expect(failure.displayMessage, contains('当前位置'));
    expect(failure.canRetry, isTrue);

    const permission = LocationPermissionFailure();
    expect(permission.canRetry, isFalse);
    expect(permission.displayMessage, contains('搜索城市'));
  });
}

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
