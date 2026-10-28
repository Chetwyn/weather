import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/core/domain/location.dart';
import 'package:weather/core/error/failure.dart';
import 'package:weather/core/l10n/app_strings.dart';
import 'package:weather/core/providers/app_providers.dart';
import 'package:weather/core/state/selected_location_provider.dart';
import 'package:weather/core/utils/request_token.dart';
import 'package:weather/features/search/domain/location_service.dart';
import 'package:weather/features/search/domain/repository/location_repository.dart';
import 'package:weather/features/search/domain/repository/reverse_geocoder.dart';
import 'package:weather/features/search/presentation/providers/current_location_provider.dart';
import 'package:weather/features/search/presentation/providers/search_providers.dart';
import 'package:weather/features/search/presentation/widgets/search_sheet.dart';
import 'package:weather/features/search/presentation/widgets/use_current_location_button.dart';

import '../../../helpers/fixtures.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.failure});

  final Failure? failure;
  int settingsOpenCount = 0;

  @override
  Future<DevicePosition> currentPosition() async {
    final error = failure;
    if (error != null) throw error;
    return const DevicePosition(latitude: 25.03, longitude: 121.56);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpenCount++;
    return true;
  }
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

class _FakeLocationRepository implements LocationRepository {
  @override
  Future<List<Location>> search(
    String query, {
    RequestToken? cancelToken,
  }) async => <Location>[taipei];
}

Future<ProviderContainer> _pumpTile(
  WidgetTester tester, {
  Failure? locationFailure,
  LocationService? locationService,
  Location? reversed,
  VoidCallback? onLocated,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      locationServiceProvider.overrideWithValue(
        locationService ?? _FakeLocationService(failure: locationFailure),
      ),
      reverseGeocoderProvider.overrideWithValue(
        _FakeReverseGeocoder(location: reversed),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(body: UseCurrentLocationTile(onLocated: onLocated)),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('点按后完成定位并回写选中地点，随后触发 onLocated', (WidgetTester tester) async {
    var located = false;
    final container = await _pumpTile(
      tester,
      reversed: taipei,
      onLocated: () => located = true,
    );

    await tester.tap(find.text(zh.useCurrentLocation));
    await tester.pumpAndSettle();

    expect(container.read(selectedLocationProvider)?.name, '台北');
    expect(located, isTrue);
    expect(
      container.read(currentLocationProvider),
      isFalse,
      reason: '定位结束应复位加载态，入口重新可点',
    );
  });

  testWidgets('定位失败只弹提示，不触发 onLocated', (WidgetTester tester) async {
    var located = false;
    final container = await _pumpTile(
      tester,
      locationFailure: const LocationPermissionFailure(),
      onLocated: () => located = true,
    );

    await tester.tap(find.text(zh.useCurrentLocation));
    await tester.pumpAndSettle();

    expect(located, isFalse);
    expect(container.read(selectedLocationProvider), isNull);
    expect(
      find.text(const LocationPermissionFailure().displayMessage),
      findsOneWidget,
      reason: '失败原因在入口处解释一次',
    );
  });

  testWidgets('权限被永久拒绝时提示带「去设置」并可跳转', (WidgetTester tester) async {
    final service = _FakeLocationService(
      failure: const LocationPermissionFailure(permanentlyDenied: true),
    );
    await _pumpTile(tester, locationService: service);

    await tester.tap(find.text(zh.useCurrentLocation));
    await tester.pumpAndSettle();

    expect(find.text(zh.openSystemSettings), findsOneWidget);

    await tester.tap(find.text(zh.openSystemSettings));
    await tester.pumpAndSettle();

    expect(service.settingsOpenCount, 1);
  });

  testWidgets('普通拒绝不提供「去设置」入口', (WidgetTester tester) async {
    await _pumpTile(tester, locationFailure: const LocationPermissionFailure());

    await tester.tap(find.text(zh.useCurrentLocation));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(zh.openSystemSettings), findsNothing);
  });

  testWidgets('搜索面板内的定位提示挂在面板自身的 Scaffold 上', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final service = _FakeLocationService(
      failure: const LocationPermissionFailure(permanentlyDenied: true),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        locationServiceProvider.overrideWithValue(service),
        reverseGeocoderProvider.overrideWithValue(_FakeReverseGeocoder()),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchSheet())),
      ),
    );

    await tester.tap(find.text(zh.useCurrentLocation));
    await tester.pumpAndSettle();

    // 提示必须画在面板内部：挂到首页 Scaffold 上的话会被 bottom sheet 盖住。
    expect(
      find.descendant(
        of: find.byType(SearchSheet),
        matching: find.byType(SnackBar),
      ),
      findsOneWidget,
    );
    expect(find.text(zh.openSystemSettings), findsOneWidget);
  });

  testWidgets('搜索面板在结果态也保留「使用当前位置」入口', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        locationServiceProvider.overrideWithValue(_FakeLocationService()),
        reverseGeocoderProvider.overrideWithValue(
          _FakeReverseGeocoder(location: taipei),
        ),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchSheet())),
      ),
    );

    container.read(searchQueryProvider.notifier).update('台北');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('台北'), findsWidgets, reason: '先确认已进入结果态');
    expect(
      find.text(zh.useCurrentLocation),
      findsOneWidget,
      reason: '入口不能只活在空态里',
    );
  });
}

/// 简体中文文案：测试断言的就是用户实际看到的那串文字。
const zh = AppStringsZhHans();
