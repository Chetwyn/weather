import 'package:flutter_test/flutter_test.dart';
import 'package:weather/features/search/data/dto/photon_feature_dto.dart';

Map<String, dynamic> _feature({
  required Map<String, dynamic> properties,
  double lon = 121.5,
  double lat = 25.0,
}) => <String, dynamic>{
  'type': 'Feature',
  'properties': properties,
  'geometry': <String, dynamic>{
    'type': 'Point',
    'coordinates': <double>[lon, lat],
  },
};

void main() {
  group('解析与归一化', () {
    test('解析行政区并归一化为 LocationDto', () {
      final dto = PhotonFeatureDto.tryFromJson(
        _feature(
          properties: <String, dynamic>{
            'osm_id': 100,
            'name': '臺北市',
            'type': 'city',
            'country': '臺灣',
            'countrycode': 'tw',
          },
        ),
      );

      expect(dto, isNotNull);
      final location = dto!.toLocationDto();
      expect(location.name, '臺北市');
      expect(location.latitude, 25.0);
      expect(location.longitude, 121.5);
      expect(location.country, '臺灣');
      expect(location.timezone, 'auto');
      // 国家码统一成大写，别名桥接靠它排除同名异国城市。
      expect(location.countryCode, 'TW');
    });

    test('搜索列表的副标题与主名重复时省略', () {
      final dto = PhotonFeatureDto.tryFromJson(
        _feature(
          properties: <String, dynamic>{
            'osm_id': 1,
            'name': '上海市',
            'type': 'state',
            'state': '上海市',
          },
        ),
      );

      expect(dto!.disambiguationSubtitle, isNull);
    });

    test('缺少 name 时用 city 兜底', () {
      final dto = PhotonFeatureDto.tryFromJson(
        _feature(
          properties: <String, dynamic>{
            'osm_id': 2,
            'type': 'house',
            'city': '臺北市',
          },
        ),
      );

      expect(dto!.name, '臺北市');
    });

    test('无法解析的 feature 返回 null 而不是抛异常', () {
      expect(PhotonFeatureDto.tryFromJson(null), isNull);
      expect(PhotonFeatureDto.tryFromJson('not a map'), isNull);
      expect(
        PhotonFeatureDto.tryFromJson(<String, dynamic>{'properties': null}),
        isNull,
      );
      expect(
        PhotonFeatureDto.tryFromJson(
          _feature(properties: <String, dynamic>{'type': 'city'}),
        ),
        isNull,
        reason: '完全没有名称的结果无法展示',
      );
    });

    test('地点类型权重：行政区 > 街区 > POI', () {
      final city = PhotonFeatureDto.tryFromJson(
        _feature(properties: <String, dynamic>{'name': 'A', 'type': 'city'}),
      )!;
      final district = PhotonFeatureDto.tryFromJson(
        _feature(
          properties: <String, dynamic>{'name': 'B', 'type': 'district'},
        ),
      )!;
      final house = PhotonFeatureDto.tryFromJson(
        _feature(properties: <String, dynamic>{'name': 'C', 'type': 'house'}),
      )!;

      expect(city.typePriority, greaterThan(district.typePriority));
      expect(district.typePriority, greaterThan(house.typePriority));
    });
  });

  group('逆地理编码的层级选择（真实响应样本）', () {
    /// 以下样本取自 Photon /reverse 的真实返回，
    /// 覆盖了「省 vs 市」命名不规整的几种典型情况。
    PhotonFeatureDto reverseOf(Map<String, dynamic> properties) =>
        PhotonFeatureDto.tryFromJson(_feature(properties: properties))!;

    test('深圳：不能被省名覆盖，主名应是深圳市', () {
      final dto = reverseOf(<String, dynamic>{
        'name': '3',
        'street': '金田路',
        'locality': '岗厦社区',
        'district': '福田街道',
        'city': '深圳市',
        'state': '广东省',
        'country': '中国',
        'type': 'house',
      });

      final location = dto.toReverseLocation(
        latitude: 22.54,
        longitude: 114.05,
      );

      expect(location.name, '深圳市');
      expect(location.admin1, '福田街道');
      expect(location.subtitle, '福田街道 · 中国');
    });

    test('杭州：主名取市，副名取街道', () {
      final dto = reverseOf(<String, dynamic>{
        'name': '大草坪',
        'locality': '岳王路社区',
        'district': '湖滨街道',
        'city': '杭州市',
        'state': '浙江省',
        'country': '中国',
        'type': 'other',
      });

      final location = dto.toReverseLocation(
        latitude: 30.25,
        longitude: 120.15,
      );

      expect(location.name, '杭州市');
      expect(location.admin1, '湖滨街道');
    });

    test('台北：主名取市，副名取区', () {
      final dto = reverseOf(<String, dynamic>{
        'street': '松江路46巷',
        'locality': '7',
        'district': '中山區',
        'city': '臺北市',
        'country': '臺灣',
        'type': 'house',
      });

      final location = dto.toReverseLocation(
        latitude: 25.05,
        longitude: 121.53,
      );

      expect(location.name, '臺北市');
      expect(location.admin1, '中山區');
      expect(location.subtitle, '中山區 · 臺灣');
    });

    test('东京：新宿区的区名进入副标题', () {
      final dto = reverseOf(<String, dynamic>{
        'name': '東京都庁舎 第一本庁舎',
        'district': '新宿区',
        'city': '東京都',
        'country': '日本',
        'type': 'house',
      });

      final location = dto.toReverseLocation(
        latitude: 35.69,
        longitude: 139.69,
      );

      expect(location.name, '東京都');
      expect(location.admin1, '新宿区');
    });

    test('缺少 city 时回退到 state，且副标题不重复', () {
      final dto = reverseOf(<String, dynamic>{
        'name': 'New York',
        'state': 'New York',
        'country': 'United States',
        'type': 'city',
      });

      final location = dto.toReverseLocation(
        latitude: 40.71,
        longitude: -74.01,
      );

      expect(location.name, 'New York');
      expect(location.admin1, isNull);
      expect(location.subtitle, 'United States');
    });

    test('只有 POI 名称时退化为 POI 名，而不是空白', () {
      final dto = reverseOf(<String, dynamic>{
        'name': '某个观测点',
        'country': '中国',
        'type': 'house',
      });

      final location = dto.toReverseLocation(latitude: 30, longitude: 120);

      expect(location.name, '某个观测点');
      expect(location.admin1, isNull);
    });

    test('直辖市：OSM 把下辖区标为 city，主名会落到区级（已知限制）', () {
      // 上海南京东路一带的实际返回：city=黄浦区、state=上海市。
      final dto = reverseOf(<String, dynamic>{
        'name': '西藏南路',
        'locality': '均乐社区',
        'district': '南京东路街道',
        'city': '黄浦区',
        'state': '上海市',
        'country': '中国',
        'type': 'street',
      });

      final location = dto.toReverseLocation(
        latitude: 31.23,
        longitude: 121.47,
      );

      // 仍然是"具体地点"，只是粒度落到了区而不是市。
      expect(location.name, '黄浦区');
      expect(location.admin1, '南京东路街道');
    });
  });
}
