enum DeviceStatus {
  idle('idle'),
  ready('ready'),
  running('running'),
  stopped('stopped'),
  reset('reset'),
  offline('offline');

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
  static('static'),
  continuous('continuous');

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
  start('start'),
  stop('stop'),
  reset('reset'),
  none('null');

  final String value;
  const DeviceAction(this.value);

  factory DeviceAction.fromString(String value) {
    return DeviceAction.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DeviceAction.none,
    );
  }
} 