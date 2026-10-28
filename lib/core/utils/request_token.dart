/// 与具体 HTTP 库解耦的取消令牌。
///
/// 未直接使用 Dio 的 `CancelToken`：domain 层必须保持纯 Dart，
/// 不能依赖 dio。这里提供一个极小的可取消原语，
/// 数据层再把取消信号桥接到 `Dio CancelToken`。
class RequestToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  /// 注册取消回调。若已取消，回调立即执行。
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
    _listeners.clear();
  }
}
