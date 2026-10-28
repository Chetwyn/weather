import '../../../../core/domain/location.dart';
import '../../../../core/error/failure.dart';

/// 搜索区域的显式状态机。
///
/// [SearchEmpty] 与 [SearchError] 是两个不同的状态：
/// 「没搜到」不是错误，不应给用户「重试」按钮。
sealed class SearchState {
  const SearchState();
}

/// 输入为空——展示最近搜索或提示。
final class SearchIdle extends SearchState {
  const SearchIdle();
}

/// 关键词长度不足。
final class SearchTooShort extends SearchState {
  const SearchTooShort();
}

/// 防抖等待或请求进行中。
final class SearchLoading extends SearchState {
  const SearchLoading();
}

final class SearchResults extends SearchState {
  const SearchResults(this.results);

  final List<Location> results;
}

/// 请求成功但没有任何匹配。
final class SearchEmpty extends SearchState {
  const SearchEmpty(this.query);

  final String query;
}

final class SearchError extends SearchState {
  const SearchError(this.failure);

  final Failure failure;
}
