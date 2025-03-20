enum DeviceStatus {
  idle('Idle'),
  ready('Ready'),
  stopped('Stopped'),
  reset('Reset'),
  offline('Offline');

  final String value;
  const DeviceStatus(this.value);

  factory DeviceStatus.fromString(String value) {
    return DeviceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceStatus.offline,
    );
  }
}

enum DeviceMode {
  static('Static'),
  continuous('Continuous');

  final String value;
  const DeviceMode(this.value);

  factory DeviceMode.fromString(String value) {
    return DeviceMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceMode.static,
    );
  }
}

enum DeviceAction {
  start('Start'),
  stop('Stop'),
  reset('Reset'),
  none('Null');

  final String value;
  const DeviceAction(this.value);

  factory DeviceAction.fromString(String value) {
    return DeviceAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceAction.none,
    );
  }
} 