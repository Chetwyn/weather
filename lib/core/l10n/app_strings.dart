import 'package:flutter/material.dart';

import '../error/failure.dart';

/// 应用支持的语言。
///
/// 中文按 script 区分简繁：`zh_TW` / `zh_HK` 这类只有地区的 locale
/// 由 [resolveAppLocale] 归一化成 `zh_Hant`，避免落到简体。
const List<Locale> supportedAppLocales = <Locale>[
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('en'),
];

const Locale zhHansLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hans',
);
const Locale zhHantLocale = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
);
const Locale enLocale = Locale('en');

/// 把系统语言列表解析成应用支持的语言。
///
/// 不用 Flutter 默认的 `basicLocaleListResolution`：它先按 language 匹配，
/// `zh_TW` 会命中列表里第一个中文（简体），繁体用户会看到简体字。
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (locale.languageCode == 'zh') {
      return isTraditionalChinese(locale) ? zhHantLocale : zhHansLocale;
    }
    if (locale.languageCode == 'en') return enLocale;
  }
  // 系统语言不在支持范围内时回退简体中文。
  return zhHansLocale;
}

/// 判断某个中文 locale 是否为繁体。
bool isTraditionalChinese(Locale locale) {
  if (locale.scriptCode == 'Hant') return true;
  if (locale.scriptCode == 'Hans') return false;
  return const <String>{'TW', 'HK', 'MO'}.contains(locale.countryCode);
}

/// 界面文案。
///
/// 三种语言各一个实现，通过 [AppStringsDelegate] 注入到 [Localizations]，
/// 组件里用 `AppStrings.of(context)` 取。
abstract class AppStrings {
  const AppStrings();

  /// 取当前语言的文案。
  ///
  /// 兜底返回简体中文：组件在 `MaterialApp` 之外（例如单独测试）也能渲染，
  /// 不会因为拿不到 Localizations 就崩。
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStringsZhHans();

  static AppStrings forLocale(Locale locale) {
    if (locale.languageCode == 'en') return const AppStringsEn();
    return isTraditionalChinese(locale)
        ? const AppStringsZhHant()
        : const AppStringsZhHans();
  }

  Locale get locale;

  // 通用
  String get appTitle;
  String get retry;
  String get cancel;

  // 语言
  String get language;
  String get followSystem;
  String get simplifiedChinese;
  String get traditionalChinese;
  String get english;

  // 空态
  String get emptyTitle;
  String get emptyHint;
  String get emptyAction;
  String get useCurrentLocation;
  String get locating;
  String get openSystemSettings;

  // 搜索
  String get searchHint;
  String get searchTooShort;
  String get searchNoResultPrefix;
  String get searchNoResultSuffix;
  String get recentSearches;
  String get clearInput;

  // 天气
  String get currentWeather;
  String get feelsLike;
  String get humidity;
  String get wind;
  String get pressure;
  String get precipitation;
  String get uvIndex;
  String get hourlyForecast;
  String get temperatureTrend;
  String get trendLow;
  String get trendHigh;
  String get dailyForecast;
  String get sunrise;
  String get sunset;
  String get maxWind;
  String get maxUv;
  String get precipitationProbability;
  String get dayDetail;
  String get tapForDetail;
  String get currentLocation;
  String get today;
  String get tomorrow;
  String get loading;
  String get refreshFailed;
  String get updatedAt;
  String get noMoreData;

  /// 「未来 N 天」这类带数量的标题。
  String dailyForecastForDays(int days);

  /// 7 个星期短名，顺序为周一…周日。
  List<String> get weekdayLabels;

  String weekdayLabel(DateTime date) => weekdayLabels[date.weekday - 1];

  /// 例：中文 `10月25日`；英文 `Oct 25`。
  String monthDayLabel(DateTime date);

  /// 温度走势的读屏摘要。中英文标点不同，默认按中文格式拼。
  String trendSummary({
    required String lowValue,
    required String lowTime,
    required String highValue,
    required String highTime,
  }) =>
      '$temperatureTrend：$trendLow $lowValue（$lowTime），'
      '$trendHigh $highValue（$highTime）';

  // 错误
  String get networkError;
  String get timeoutError;
  String get serverError;
  String get rateLimitError;
  String get clientError;
  String get notFoundError;
  String get parseError;
  String get unknownError;
  String get locationPermissionDenied;
  String get locationPermissionPermanentlyDenied;

  /// WMO 天气代码 → 当前语言的描述。
  String weatherLabel(int code);

  /// 8 个方位名，顺序固定为 N、NE、E、SE、S、SW、W、NW。
  List<String> get windDirectionLabels;

  /// 风向角度 → 当前语言的方位名。
  String windDirectionName(double degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return windDirectionLabels[index];
  }

  /// 错误类型的本地化文案。
  ///
  /// [Failure.displayMessage] 是中文兜底（也用于日志），UI 一律走这里，
  /// 否则英文界面会突然冒出一句中文。
  String failureMessage(Failure failure) {
    return switch (failure.code) {
      'network' => networkError,
      'timeout' => timeoutError,
      'server' => serverError,
      'rate_limit' => rateLimitError,
      'client' => clientError,
      'not_found' => notFoundError,
      'parse' => parseError,
      'location_permission' =>
        failure is LocationPermissionFailure && failure.permanentlyDenied
            ? locationPermissionPermanentlyDenied
            : locationPermissionDenied,
      'location_unavailable' => locationPermissionDenied,
      _ => unknownError,
    };
  }
}

/// 简体中文。
class AppStringsZhHans extends AppStrings {
  const AppStringsZhHans();

  @override
  Locale get locale => zhHansLocale;

  @override
  String get appTitle => '云舒';
  @override
  String get retry => '重试';
  @override
  String get cancel => '取消';

  @override
  String get language => '语言';
  @override
  String get followSystem => '跟随系统';
  @override
  String get simplifiedChinese => '简体中文';
  @override
  String get traditionalChinese => '繁體中文';
  @override
  String get english => 'English';

  @override
  String get emptyTitle => '搜索城市查看天气';
  @override
  String get emptyHint => '支持中文或英文地名，例如「台北」「上海」「Taipei」';
  @override
  String get emptyAction => '搜索地点';
  @override
  String get useCurrentLocation => '使用当前位置';
  @override
  String get locating => '定位中…';
  @override
  String get openSystemSettings => '去设置';

  @override
  String get searchHint => '搜索城市';
  @override
  String get searchTooShort => '请输入至少 2 个字符';
  @override
  String get searchNoResultPrefix => '未找到';
  @override
  String get searchNoResultSuffix => '相关地点，换个关键词试试';
  @override
  String get recentSearches => '最近搜索';
  @override
  String get clearInput => '清空输入';

  @override
  String get currentWeather => '当前天气';
  @override
  String get feelsLike => '体感';
  @override
  String get humidity => '湿度';
  @override
  String get wind => '风速';
  @override
  String get pressure => '气压';
  @override
  String get precipitation => '降水';
  @override
  String get uvIndex => '紫外线';
  @override
  String get hourlyForecast => '逐小时预报';
  @override
  String get temperatureTrend => '24 小时温度趋势';
  @override
  String get trendLow => '最低';
  @override
  String get trendHigh => '最高';
  @override
  String get dailyForecast => '未来 7 天';
  @override
  String get sunrise => '日出';
  @override
  String get sunset => '日落';
  @override
  String get maxWind => '最大风速';
  @override
  String get maxUv => '紫外线峰值';
  @override
  String get precipitationProbability => '降水概率';
  @override
  String get dayDetail => '当日详情';
  @override
  String get tapForDetail => '点击查看当日详情';
  @override
  String get currentLocation => '当前位置';
  @override
  String get today => '今天';
  @override
  String get tomorrow => '明天';
  @override
  String get loading => '加载中';
  @override
  String get refreshFailed => '刷新失败';
  @override
  String get updatedAt => '更新于';
  @override
  String get noMoreData => '暂无更多数据';

  @override
  String dailyForecastForDays(int days) => '未来 $days 天';

  @override
  List<String> get weekdayLabels => const <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  String monthDayLabel(DateTime date) => '${date.month}月${date.day}日';

  @override
  String get networkError => '网络连接不可用，请检查网络后重试';
  @override
  String get timeoutError => '请求超时，请稍后重试';
  @override
  String get serverError => '天气服务暂时不可用，请稍后再试';
  @override
  String get rateLimitError => '查询过于频繁，请稍后再试';
  @override
  String get clientError => '请求参数有误，请稍后重试';
  @override
  String get notFoundError => '该地点暂无天气数据';
  @override
  String get parseError => '数据解析异常，请稍后重试';
  @override
  String get unknownError => '加载失败，请重试';
  @override
  String get locationPermissionDenied => '未获得定位权限，可手动搜索城市';
  @override
  String get locationPermissionPermanentlyDenied =>
      '定位权限已被拒绝，请在系统设置中开启，或直接搜索城市';

  @override
  String weatherLabel(int code) => switch (code) {
    0 => '晴',
    1 => '大部晴朗',
    2 => '多云',
    3 => '阴',
    45 => '有雾',
    48 => '雾凇',
    51 => '小毛毛雨',
    53 => '毛毛雨',
    55 => '大毛毛雨',
    56 || 57 => '冻毛毛雨',
    61 => '小雨',
    63 => '中雨',
    65 => '大雨',
    66 || 67 => '冻雨',
    71 => '小雪',
    73 => '中雪',
    75 => '大雪',
    77 => '雪粒',
    80 => '小阵雨',
    81 => '阵雨',
    82 => '强阵雨',
    85 || 86 => '阵雪',
    95 => '雷暴',
    96 || 99 => '雷暴伴冰雹',
    _ => '未知',
  };

  @override
  List<String> get windDirectionLabels => const <String>[
    '北',
    '东北',
    '东',
    '东南',
    '南',
    '西南',
    '西',
    '西北',
  ];
}

/// 繁體中文。
class AppStringsZhHant extends AppStrings {
  const AppStringsZhHant();

  @override
  Locale get locale => zhHantLocale;

  @override
  String get appTitle => '雲舒';
  @override
  String get retry => '重試';
  @override
  String get cancel => '取消';

  @override
  String get language => '語言';
  @override
  String get followSystem => '跟隨系統';
  @override
  String get simplifiedChinese => '简体中文';
  @override
  String get traditionalChinese => '繁體中文';
  @override
  String get english => 'English';

  @override
  String get emptyTitle => '搜尋城市查看天氣';
  @override
  String get emptyHint => '支援中文或英文地名，例如「台北」「上海」「Taipei」';
  @override
  String get emptyAction => '搜尋地點';
  @override
  String get useCurrentLocation => '使用目前位置';
  @override
  String get locating => '定位中…';
  @override
  String get openSystemSettings => '前往設定';

  @override
  String get searchHint => '搜尋城市';
  @override
  String get searchTooShort => '請輸入至少 2 個字元';
  @override
  String get searchNoResultPrefix => '找不到';
  @override
  String get searchNoResultSuffix => '相關地點，換個關鍵字試試';
  @override
  String get recentSearches => '最近搜尋';
  @override
  String get clearInput => '清除輸入';

  @override
  String get currentWeather => '目前天氣';
  @override
  String get feelsLike => '體感';
  @override
  String get humidity => '濕度';
  @override
  String get wind => '風速';
  @override
  String get pressure => '氣壓';
  @override
  String get precipitation => '降水';
  @override
  String get uvIndex => '紫外線';
  @override
  String get hourlyForecast => '逐小時預報';
  @override
  String get temperatureTrend => '24 小時溫度趨勢';
  @override
  String get trendLow => '最低';
  @override
  String get trendHigh => '最高';
  @override
  String get dailyForecast => '未來 7 天';
  @override
  String get sunrise => '日出';
  @override
  String get sunset => '日落';
  @override
  String get maxWind => '最大風速';
  @override
  String get maxUv => '紫外線峰值';
  @override
  String get precipitationProbability => '降水機率';
  @override
  String get dayDetail => '當日詳情';
  @override
  String get tapForDetail => '點擊查看當日詳情';
  @override
  String get currentLocation => '目前位置';
  @override
  String get today => '今天';
  @override
  String get tomorrow => '明天';
  @override
  String get loading => '載入中';
  @override
  String get refreshFailed => '重新整理失敗';
  @override
  String get updatedAt => '更新於';
  @override
  String get noMoreData => '暫無更多資料';

  @override
  String dailyForecastForDays(int days) => '未來 $days 天';

  @override
  List<String> get weekdayLabels => const <String>[
    '週一',
    '週二',
    '週三',
    '週四',
    '週五',
    '週六',
    '週日',
  ];

  @override
  String monthDayLabel(DateTime date) => '${date.month}月${date.day}日';

  @override
  String get networkError => '網路連線不可用，請檢查網路後重試';
  @override
  String get timeoutError => '請求逾時，請稍後重試';
  @override
  String get serverError => '天氣服務暫時無法使用，請稍後再試';
  @override
  String get rateLimitError => '查詢過於頻繁，請稍後再試';
  @override
  String get clientError => '請求參數有誤，請稍後重試';
  @override
  String get notFoundError => '該地點暫無天氣資料';
  @override
  String get parseError => '資料解析異常，請稍後重試';
  @override
  String get unknownError => '載入失敗，請重試';
  @override
  String get locationPermissionDenied => '未取得定位權限，可手動搜尋城市';
  @override
  String get locationPermissionPermanentlyDenied =>
      '定位權限已被拒絕，請在系統設定中開啟，或直接搜尋城市';

  @override
  String weatherLabel(int code) => switch (code) {
    0 => '晴',
    1 => '大部晴朗',
    2 => '多雲',
    3 => '陰',
    45 => '有霧',
    48 => '霧凇',
    51 => '小毛毛雨',
    53 => '毛毛雨',
    55 => '大毛毛雨',
    56 || 57 => '凍毛毛雨',
    61 => '小雨',
    63 => '中雨',
    65 => '大雨',
    66 || 67 => '凍雨',
    71 => '小雪',
    73 => '中雪',
    75 => '大雪',
    77 => '雪粒',
    80 => '小陣雨',
    81 => '陣雨',
    82 => '強陣雨',
    85 || 86 => '陣雪',
    95 => '雷暴',
    96 || 99 => '雷暴伴冰雹',
    _ => '未知',
  };

  @override
  List<String> get windDirectionLabels => const <String>[
    '北',
    '東北',
    '東',
    '東南',
    '南',
    '西南',
    '西',
    '西北',
  ];
}

/// English.
class AppStringsEn extends AppStrings {
  const AppStringsEn();

  @override
  Locale get locale => enLocale;

  @override
  String get appTitle => 'Cirrus';
  @override
  String get retry => 'Retry';
  @override
  String get cancel => 'Cancel';

  @override
  String get language => 'Language';
  @override
  String get followSystem => 'Follow system';
  @override
  String get simplifiedChinese => '简体中文';
  @override
  String get traditionalChinese => '繁體中文';
  @override
  String get english => 'English';

  @override
  String get emptyTitle => 'Search a city to see the weather';
  @override
  String get emptyHint =>
      'Chinese or English place names, e.g. "Taipei" or "Shanghai"';
  @override
  String get emptyAction => 'Search a city';
  @override
  String get useCurrentLocation => 'Use current location';
  @override
  String get locating => 'Locating…';
  @override
  String get openSystemSettings => 'Open settings';

  @override
  String get searchHint => 'Search city';
  @override
  String get searchTooShort => 'Type at least 2 characters';
  @override
  String get searchNoResultPrefix => 'No results for';
  @override
  String get searchNoResultSuffix => 'try another keyword';
  @override
  String get recentSearches => 'Recent searches';
  @override
  String get clearInput => 'Clear input';

  @override
  String get currentWeather => 'Current weather';
  @override
  String get feelsLike => 'Feels like';
  @override
  String get humidity => 'Humidity';
  @override
  String get wind => 'Wind';
  @override
  String get pressure => 'Pressure';
  @override
  String get precipitation => 'Precipitation';
  @override
  String get uvIndex => 'UV index';
  @override
  String get hourlyForecast => 'Hourly forecast';
  @override
  String get temperatureTrend => '24-hour temperature trend';
  @override
  String get trendLow => 'Low';
  @override
  String get trendHigh => 'High';
  @override
  String get dailyForecast => 'Next 7 days';
  @override
  String get sunrise => 'Sunrise';
  @override
  String get sunset => 'Sunset';
  @override
  String get maxWind => 'Max wind';
  @override
  String get maxUv => 'Peak UV';
  @override
  String get precipitationProbability => 'Chance of precipitation';
  @override
  String get dayDetail => 'Day details';
  @override
  String get tapForDetail => 'Tap for day details';
  @override
  String get currentLocation => 'Current location';
  @override
  String get today => 'Today';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String get loading => 'Loading';
  @override
  String get refreshFailed => 'Refresh failed';
  @override
  String get updatedAt => 'Updated';
  @override
  String get noMoreData => 'No more details';

  @override
  String dailyForecastForDays(int days) => 'Next $days days';

  @override
  List<String> get weekdayLabels => const <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  String monthDayLabel(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}';

  @override
  String trendSummary({
    required String lowValue,
    required String lowTime,
    required String highValue,
    required String highTime,
  }) =>
      '$temperatureTrend: $trendLow $lowValue ($lowTime), '
      '$trendHigh $highValue ($highTime)';

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  String get networkError =>
      'No network connection. Check your network and try again.';
  @override
  String get timeoutError => 'Request timed out. Please try again.';
  @override
  String get serverError =>
      'Weather service is temporarily unavailable. Please try again later.';
  @override
  String get rateLimitError => 'Too many requests. Please try again later.';
  @override
  String get clientError => 'Invalid request. Please try again later.';
  @override
  String get notFoundError => 'No weather data for this location.';
  @override
  String get parseError => 'Failed to parse data. Please try again.';
  @override
  String get unknownError => 'Something went wrong. Please try again.';
  @override
  String get locationPermissionDenied =>
      'Location permission denied. You can search a city instead.';
  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission is permanently denied. Enable it in Settings, '
      'or search a city instead.';

  @override
  String weatherLabel(int code) => switch (code) {
    0 => 'Clear',
    1 => 'Mostly clear',
    2 => 'Partly cloudy',
    3 => 'Overcast',
    45 => 'Fog',
    48 => 'Rime fog',
    51 => 'Light drizzle',
    53 => 'Drizzle',
    55 => 'Heavy drizzle',
    56 || 57 => 'Freezing drizzle',
    61 => 'Light rain',
    63 => 'Rain',
    65 => 'Heavy rain',
    66 || 67 => 'Freezing rain',
    71 => 'Light snow',
    73 => 'Snow',
    75 => 'Heavy snow',
    77 => 'Snow grains',
    80 => 'Light showers',
    81 => 'Showers',
    82 => 'Violent showers',
    85 || 86 => 'Snow showers',
    95 => 'Thunderstorm',
    96 || 99 => 'Thunderstorm with hail',
    _ => 'Unknown',
  };

  @override
  List<String> get windDirectionLabels => const <String>[
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SW',
    'W',
    'NW',
  ];
}

/// 把 [AppStrings] 挂到 [Localizations] 上。
class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings.forLocale(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
