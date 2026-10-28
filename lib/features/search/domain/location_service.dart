/// 设备定位结果（只保留业务需要的字段，不把平台对象泄漏到上层）。
class DevicePosition {
  const DevicePosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// 设备定位能力的抽象。
///
/// 抽成接口是为了让「使用当前位置」的整条链路（定位 → 反查地名 → 选中）
/// 可以在没有真机、没有权限弹窗的情况下被单测覆盖。
abstract interface class LocationService {
  /// 失败时抛 `Failure`：
  /// - `LocationPermissionFailure`：用户拒绝 / 永久拒绝
  /// - `LocationUnavailableFailure`：定位服务关闭 / 超时 / 硬件不可用
  Future<DevicePosition> currentPosition();

  /// 打开本应用的系统设置页（权限被永久拒绝时唯一能自救的入口）。
  ///
  /// 返回是否成功打开：部分系统可能没有可跳转的设置页。
  Future<bool> openSettings();
}
