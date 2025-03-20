// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
      id: json['id'] as String,
      profile: DeviceProfile.fromJson(json['profile'] as Map<String, dynamic>),
      status: $enumDecode(_$DeviceStatusEnumMap, json['status']),
      mode: $enumDecode(_$DeviceModeEnumMap, json['mode']),
      action: $enumDecode(_$DeviceActionEnumMap, json['action']),
      info: json['info'] as Map<String, dynamic>,
      createdTime: DateTime.parse(json['createdTime'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      online: json['online'] as bool,
      battery: (json['battery'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
      'id': instance.id,
      'profile': instance.profile,
      'status': _$DeviceStatusEnumMap[instance.status]!,
      'mode': _$DeviceModeEnumMap[instance.mode]!,
      'action': _$DeviceActionEnumMap[instance.action]!,
      'info': instance.info,
      'createdTime': instance.createdTime.toIso8601String(),
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'online': instance.online,
      'battery': instance.battery,
    };

const _$DeviceStatusEnumMap = {
  DeviceStatus.idle: 'idle',
  DeviceStatus.ready: 'ready',
  DeviceStatus.stopped: 'stopped',
  DeviceStatus.reset: 'reset',
  DeviceStatus.offline: 'offline',
};

const _$DeviceModeEnumMap = {
  DeviceMode.static: 'static',
  DeviceMode.continuous: 'continuous',
};

const _$DeviceActionEnumMap = {
  DeviceAction.start: 'start',
  DeviceAction.stop: 'stop',
  DeviceAction.reset: 'reset',
  DeviceAction.none: 'none',
};

DeviceProfile _$DeviceProfileFromJson(Map<String, dynamic> json) =>
    DeviceProfile(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
    );

Map<String, dynamic> _$DeviceProfileToJson(DeviceProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organizationId': instance.organizationId,
    };
