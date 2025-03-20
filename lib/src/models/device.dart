import 'package:json_annotation/json_annotation.dart';
import 'enums.dart';

part 'device.g.dart';

@JsonSerializable()
class Device {
  final String id;
  final DeviceProfile profile;
  final DeviceStatus status;
  final DeviceMode mode;
  final DeviceAction action;
  final Map<String, dynamic> info;
  final DateTime createdTime;
  final DateTime lastUpdated;
  final bool online;
  final int? battery;

  Device({
    required this.id,
    required this.profile,
    required this.status,
    required this.mode,
    required this.action,
    required this.info,
    required this.createdTime,
    required this.lastUpdated,
    required this.online,
    this.battery,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

@JsonSerializable()
class DeviceProfile {
  final String id;
  final String organizationId;

  DeviceProfile({
    required this.id,
    required this.organizationId,
  });

  factory DeviceProfile.fromJson(Map<String, dynamic> json) =>
      _$DeviceProfileFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceProfileToJson(this);
} 