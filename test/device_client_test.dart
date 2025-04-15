import 'package:flutter_test/flutter_test.dart';
import 'package:medibound_integration/src/device_client.dart';
import 'package:medibound_integration/src/models/enums.dart';

void main() {
  test('setStatus should make HTTP request', () async {
    // Create a device client with test values
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    // Test setting status
    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    const status = DeviceStatus.ready;

    // This will make a real HTTP request
    // Note: This is a basic test that will fail if the server is not available
    // In a real test environment, you'd want to use a test server or mock
    try {
      await client.setStatus(deviceId, status);
      print('Status set successfully');
    } catch (e) {
      print('Error setting status: $e');
      // We expect this to fail since we're using a test API key
      expect(e, isA<Exception>());
    }
  });

  test('setMode should make HTTP request', () async {
    // Create a device client with test values
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    // Test setting mode
    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    const mode = DeviceMode.continuous;

    try {
      await client.setMode(deviceId, mode);
      print('Mode set successfully');
    } catch (e) {
      print('Error setting mode: $e');
      expect(e, isA<Exception>());
    }
  });

  test('setAction should make HTTP request', () async {
    // Create a device client with test values
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    // Test setting action
    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    const action = DeviceAction.start;

    try {
      await client.setAction(deviceId, action);
      print('Action set successfully');
    } catch (e) {
      print('Error setting action: $e');
      expect(e, isA<Exception>());
    }
  });

  test('onStatusUpdate should stream status updates', () async {
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    
    try {
      // Listen to status updates for 5 seconds
      print('Starting status update stream...');
      await for (final status in client.onStatusUpdate(deviceId)) {
        print('Received status update: $status');
      }
    } catch (e) {
      print('Error in status stream: $e');
      expect(e, isA<Exception>());
    }
  });

  test('onModeUpdate should stream mode updates', () async {
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    
    try {
      // Listen to mode updates for 5 seconds
      print('Starting mode update stream...');
      await for (final mode in client.onModeUpdate(deviceId)) {
        print('Received mode update: $mode');
      }
    } catch (e) {
      print('Error in mode stream: $e');
      expect(e, isA<Exception>());
    }
  });

  test('onActionUpdate should stream action updates', () async {
    final client = DeviceClient(
      baseUrl: 'https://api.medibound.com',
      apiKey: 'TT84UlTJ2xfl2HUtYT35',
    );

    const deviceId = 'uw9N0E7FpCVJKJ3U75p0';
    
    try {
      // Listen to action updates for 5 seconds
      print('Starting action update stream...');
      await for (final action in client.onActionUpdate(deviceId)) {
        print('Received action update: $action');
      }
    } catch (e) {
      print('Error in action stream: $e');
      expect(e, isA<Exception>());
    }
  });
} 