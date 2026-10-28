import '../../../../core/error/failure.dart';
import '../../domain/entity/weather.dart';

/// 天气页面的显式状态机。
///
/// 用 sealed class 而不是 `isLoading / hasError / data` 三个独立字段：
/// 后者允许出现「同时 loading 和 error」这类非法组合，前者在编译期
/// 即可排除。
sealed class WeatherState {
  const WeatherState();
}

/// 尚未选择地点——展示空态引导。
final class WeatherInitial extends WeatherState {
  const WeatherInitial();
}

/// 数据加载中——展示骨架屏。
final class WeatherLoading extends WeatherState {
  const WeatherLoading();
}

final class WeatherSuccess extends WeatherState {
  const WeatherSuccess(this.weather);

  final Weather weather;
}

/// 加载失败——展示错误占位与重试。
final class WeatherError extends WeatherState {
  const WeatherError(this.failure);

  final Failure failure;
}
