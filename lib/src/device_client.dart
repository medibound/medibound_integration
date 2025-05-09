import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/device.dart';
import 'models/enums.dart';

class DeviceClient {
  final String baseUrl;
  String apiKey;

  DeviceClient({
    required this.baseUrl,
    required this.apiKey,
  });

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  // Set device status
  Future<void> setStatus(String deviceId, DeviceStatus status) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device/setStatus'),
      headers: _headers,
      body: jsonEncode({
        'status': status.value,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set device status: ${response.body}');
    }
  }

  // Set device mode
  Future<void> setMode(String deviceId, DeviceMode mode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device/setMode'),
      headers: _headers,
      body: jsonEncode({
        'mode': mode.value,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set device mode: ${response.body}');
    }
  }

  // Set device action
  Future<void> setAction(String deviceId, DeviceAction action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device/setAction'),
      headers: _headers,
      body: jsonEncode({
        'action': action.value,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set device action: ${response.body}');
    }
  }

  // Send record
  Future<String> sendRecord(String deviceId, dynamic record) async {
    final response = await http.post(
      Uri.parse('$baseUrl/device/sendRecord'),
      headers: _headers,
      body: jsonEncode({
        'jsonData': record,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send record: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    return responseData['recordId'];
  }

  // Update record
  Future<void> updateRecord(
    String deviceId,
    String recordId,
    Map<String, dynamic> updates
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/device/updateRecord'),
      headers: _headers,
      body: jsonEncode({
        'recordId': recordId,
        'updates': updates,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update record: ${response.body}');
    }
  }

  // Stream status updates
  Stream<DeviceStatus> onStatusUpdate(String deviceId) async* {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/device/onStatusUpdate?deviceId=$deviceId'),
    )..headers.addAll(_headers);

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to connect to status stream');
    }

    await for (final data in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (data.startsWith('data: ')) {
        final jsonData = jsonDecode(data.substring(6));
        if (jsonData['error'] != null) {
          throw Exception(jsonData['error']);
        }
        yield DeviceStatus.fromString(jsonData['status']);
      }
    }
  }

  // Stream mode updates
  Stream<DeviceMode> onModeUpdate(String deviceId) async* {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/device/onModeUpdate?deviceId=$deviceId'),
    )..headers.addAll(_headers);

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to connect to mode stream');
    }

    await for (final data in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (data.startsWith('data: ')) {
        final jsonData = jsonDecode(data.substring(6));
        if (jsonData['error'] != null) {
          throw Exception(jsonData['error']);
        }
        yield DeviceMode.fromString(jsonData['mode']);
      }
    }
  }

  // Stream action updates
  Stream<DeviceAction> onActionUpdate(String deviceId) async* {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/device/onActionUpdate?deviceId=$deviceId'),
    )..headers.addAll(_headers);

    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Failed to connect to action stream');
    }

    await for (final data in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (data.startsWith('data: ')) {
        final jsonData = jsonDecode(data.substring(6));
        if (jsonData['error'] != null) {
          throw Exception(jsonData['error']);
        }
        yield DeviceAction.fromString(jsonData['action']);
      }
    }
  }
} 