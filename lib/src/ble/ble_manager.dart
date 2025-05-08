import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:medibound_integration/src/device_client.dart';
import '../models/enums.dart';

// Service and Characteristic UUIDs from the ESP32 library
const String MEDIBOUND_SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String ACTION_CHARACTERISTIC_UUID =
    "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String STATUS_CHARACTERISTIC_UUID =
    "beb5483e-36e1-4688-b7f5-ea07361b26a9";
const String DATA_CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26aa";
const String MODE_CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26ab";

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _devicesSubscription;
  StreamSubscription? _connectionStateSubscription;
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, String> _deviceIdentifiers =
      {}; // Maps BLE address to manufacturer ID
  final List<String> _authorizedDeviceIds = [];

  // Stream controllers for local state management
  final _deviceStatusController =
      StreamController<Map<String, String>>.broadcast();
  final _deviceDataController =
      StreamController<Map<String, String>>.broadcast();
  final _deviceBatteryController =
      StreamController<Map<String, int>>.broadcast();

  // Public streams
  Stream<Map<String, String>> get deviceStatus =>
      _deviceStatusController.stream;
  Stream<Map<String, String>> get deviceData => _deviceDataController.stream;
  Stream<Map<String, int>> get deviceBattery => _deviceBatteryController.stream;

  BleManager._internal();

  Future<void> _authenticateDevice(
      BluetoothDevice device, String deviceId) async {
    try {
      print('Authenticating device: $deviceId');

      // Get device profile from Firestore first, before attempting connection
      final deviceDocs = await _db
          .collectionGroup('device')
          .where('info.code', isEqualTo: deviceId.substring(2))
          .limit(1)
          .get();
      if (deviceDocs.docs.isEmpty) {
        print('Device profile not found for ID: $deviceId');
        return;
      }
      final deviceDoc = deviceDocs.docs.first;

      final secretKey = deviceDoc.data()['secret_key']['secret'] as String?;
      if (secretKey == null) {
        print('Secret key not found for device: $deviceId');
        return;
      }

      // Connection and service discovery with improved retry logic
      List<BluetoothService> services = [];
      services = await device.discoverServices();


      final mediboundService = services.firstWhere(
        (s) => s.uuid.toString() == MEDIBOUND_SERVICE_UUID,
        orElse: () => throw Exception('Medibound service not found'),
      );

      // Get data characteristic
      final dataCharacteristic = mediboundService.characteristics.firstWhere(
        (c) => c.uuid.toString() == DATA_CHARACTERISTIC_UUID,
        orElse: () => throw Exception('Data characteristic not found'),
      );

      // Get command characteristic
      final actionCharacteristic = mediboundService.characteristics.firstWhere(
        (c) => c.uuid.toString() == ACTION_CHARACTERISTIC_UUID,
        orElse: () => throw Exception('Action characteristic not found'),
      );

      // Read initial data (contains encrypted API key and device/profile info)
      final data = await dataCharacteristic.read();
      
      final key = String.fromCharCodes(data);
      
      final encryptedApiKey = key as String;
            
      // Parse the secret key to get the three components
      final secretKeyParts = secretKey.split('-');
      if (secretKeyParts.length != 3) {
        print('Invalid secret key format: $secretKey');
        device.disconnect();
        return;
      }

      final secretDeviceId = secretKeyParts[1];
      final actualApiKey = secretKeyParts[2];

      // Decode the API key
      final decodedApiKey = _decodeApiKey(encryptedApiKey, secretKey);
      print('Decoded Key: $decodedApiKey');

      // Make API call to verify the key matches
      final response = await http.get(
        Uri.parse('https://api.medibound.com/device/confirmKey?deviceId=$secretDeviceId&key=$decodedApiKey'),
      );

      final responseData = jsonDecode(response.body);
      if (!responseData['success']) {
        print('API verification failed');
        device.disconnect();
        return;
      }

      if (!responseData['isMatch']) {
        print('API key mismatch');
        device.disconnect();
        return;
      }

      // Send authentication command with the actual API key
      final authAction = 'auth $actualApiKey';
      await actionCharacteristic.write(utf8.encode(authAction));
      print('Device authenticated successfully: $deviceId');

      // Set device status to ready after successful authentication
      final mediboundClient = DeviceClient(baseUrl: 'https://api.medibound.com', apiKey: actualApiKey);
      await mediboundClient.setStatus(deviceId.substring(2), DeviceStatus.ready);

      // Set up characteristic notifications
      await _setupCharacteristicNotifications(mediboundService, mediboundClient, deviceId.substring(2));
    } catch (e) {
      print('Error during device authentication: $e');
      try {
        if (device.isConnected) {
          await device.disconnect();
        }
      } catch (disconnectError) {
        print('Error disconnecting device: $disconnectError');
      }
      // Remove device from connected devices map on authentication failure
      final bleId = device.remoteId.str;
      final storedDeviceId = _deviceIdentifiers[bleId];
      if (storedDeviceId != null) {
        _connectedDevices.remove(storedDeviceId);
        _deviceIdentifiers.remove(bleId);
      }
    }
  }

  // Helper function to decode the encrypted API key
  String _decodeApiKey(String encryptedKey, String secretKey) {
    try {
      // For decryption, we need to use the full secret key
      final secretBytes = latin1.encode(secretKey);
      final encryptedBytes = <int>[];

      // Read 2 hex digits at a time
      for (int i = 0; i < encryptedKey.length; i += 2) {
        if (i + 1 < encryptedKey.length) {
          encryptedBytes
              .add(int.parse(encryptedKey.substring(i, i + 2), radix: 16));
        }
      }

      final decryptedBytes = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ secretBytes[i % secretBytes.length],
      );

      return latin1.decode(decryptedBytes);
    } catch (e) {
      print('Error during decryption: $e');
      return '';
    }
  }

  Future<void> _setupCharacteristicNotifications(
      BluetoothService service, DeviceClient client, String deviceId) async {
    try {
      print('Setting up characteristic notifications for device: $deviceId');
      
      // Set up status notifications
      print('Setting up status characteristic notifications...');
      final statusCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString() == STATUS_CHARACTERISTIC_UUID,
      );
      await statusCharacteristic.setNotifyValue(true);
      print('Status notifications enabled');
      
      final statusSubscription = statusCharacteristic.onValueReceived.listen((value) {
        final status = String.fromCharCodes(value);
        print('Received status update: $status');
        _deviceStatusController.add({deviceId: status});
        DeviceStatus statusEnum = DeviceStatus.fromString(status);
        client.setStatus(deviceId, statusEnum);
      });
      statusCharacteristic.device.cancelWhenDisconnected(statusSubscription);

      // Set up mode notifications
      print('Setting up mode characteristic notifications...');
      final modeCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString() == MODE_CHARACTERISTIC_UUID,
      );
      final mode = await modeCharacteristic.read();
      final modeString = String.fromCharCodes(mode);
      print('Initial mode: $modeString');
      
      DeviceMode modeEnum = DeviceMode.fromString(modeString);
      client.setMode(deviceId, modeEnum);
      
      await modeCharacteristic.setNotifyValue(true);
      print('Mode notifications enabled');
      
      final modeSubscription = modeCharacteristic.onValueReceived.listen((value) {
        final mode = String.fromCharCodes(value);
        print('Received mode update: $mode');
        DeviceMode modeEnum = DeviceMode.fromString(mode);
        client.setMode(deviceId, modeEnum);
      });
      modeCharacteristic.device.cancelWhenDisconnected(modeSubscription);

      // Set up data notifications
      print('Setting up data characteristic notifications...');
      final dataCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString() == DATA_CHARACTERISTIC_UUID,
      );
      await dataCharacteristic.setNotifyValue(true);
      print('Data notifications enabled');
      
      final dataSubscription = dataCharacteristic.onValueReceived.listen((value) {
        final data = String.fromCharCodes(value);
        print('Received data update: $data');
        _deviceDataController.add({deviceId: data});
        
        try {
          // Parse the JSON data
          final decodedData = jsonDecode(data);
          print('Sending to API - deviceId: $deviceId');
          print('Sending to API - data: $decodedData');
          
          // Ensure the data is properly formatted
          client.sendRecord(deviceId, decodedData);
        } catch (e) {
          print('Error processing data: $e');
        }
      });
      dataCharacteristic.device.cancelWhenDisconnected(dataSubscription);

      // Set up action characteristic for sending commands
      print('Setting up action characteristic...');
      final actionCharacteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString() == ACTION_CHARACTERISTIC_UUID,
      );

      // Listen for action updates from the API and send them to the device
      final actionSubscription = client.onActionUpdate(deviceId).listen((action) async {
        if (action == DeviceAction.none) {
          return;
        }
        print('Received action update from API: $action');
        try {
          // Convert the action to a command string
          String command = action.value;
          await actionCharacteristic.write(utf8.encode(command));
          client.setAction(deviceId, DeviceAction.none);
          print('Sent action command to device: $command');
        } catch (e) {
          print('Error sending action to device: $e');
        }
      });
      actionCharacteristic.device.cancelWhenDisconnected(actionSubscription);

      print('All characteristic notifications set up successfully');
    } catch (e) {
      print('Error setting up characteristic notifications: $e');
    }
  }

  Future<void> initialize(bool debug) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user');
      return;
    }

    if (debug) {
      FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
    }

    print('Initializing BLE manager for user: ${user.uid}');

    final userDoc = await _db.collection('users').doc(user.uid).get();

    // Listen to devices owned by the current user
    _devicesSubscription = _db
        .collectionGroup('device')
        .where('owner', isEqualTo: userDoc.reference)
        .snapshots()
        .listen((snapshot) async {
          // Store old authorized devices for comparison
          final oldAuthorizedDevices = Set<String>.from(_authorizedDeviceIds);
          _authorizedDeviceIds.clear();
          
          // Update authorized devices list
          for (var doc in snapshot.docs) {
            final deviceId = doc.id;
            final fullDeviceId = 'mb$deviceId';
            _authorizedDeviceIds.add(fullDeviceId);
            print('Authorized device ID: $fullDeviceId');
            
            // If device is not connected, try to find and connect to it
            if (!_connectedDevices.containsKey(fullDeviceId)) {
              final found = await scanForDevice(fullDeviceId);
              if (found != null) {
                print('Found authorized device during rescan: $fullDeviceId');
                connect(found);
              }
            }
          }
          
          // Check for devices that are no longer authorized
          for (final oldDeviceId in oldAuthorizedDevices) {
            if (!_authorizedDeviceIds.contains(oldDeviceId)) {
              print('Device no longer authorized: $oldDeviceId');
              final device = _connectedDevices[oldDeviceId];
              if (device != null) {
                print('Disconnecting unauthorized device: $oldDeviceId');
                await disconnect(device);
                _connectedDevices.remove(oldDeviceId);
                _deviceIdentifiers.remove(device.remoteId.str);
              }
            }
          }
        });

    // Setup Bluetooth connection state listener
    _connectionStateSubscription =
        FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      final bleId = event.device.remoteId.str;
      final deviceId = _deviceIdentifiers[bleId];

      if (event.connectionState == BluetoothConnectionState.connected) {
        if (deviceId != null) {
          print('Device connected with ID: $deviceId');
          if (!_connectedDevices.containsKey(deviceId)) {
            _connectedDevices[deviceId] = event.device;
            // Start authentication process
            await _authenticateDevice(event.device, deviceId);
          }
        } else {
          print('Connected device has no associated manufacturer ID');
          event.device.disconnect();
        }
      } else if (event.connectionState == BluetoothConnectionState.disconnected) {
        if (deviceId != null) {
          print('Device disconnected: $deviceId');
          _connectedDevices.remove(deviceId);
          _deviceIdentifiers.remove(bleId);
          
          // Update device status to offline
          final deviceCode = deviceId.substring(2); // Remove 'mb' prefix
          final deviceDocs = await _db
              .collectionGroup('device')
              .where('info.code', isEqualTo: deviceCode)
              .limit(1)
              .get();
              
          if (deviceDocs.docs.isNotEmpty) {
            final deviceDoc = deviceDocs.docs.first;
            final apiKey = deviceDoc.data()['api_key'] as String?;
            if (apiKey != null) {
              final client = DeviceClient(baseUrl: 'https://api.medibound.com', apiKey: apiKey);
              await client.setStatus(deviceCode, DeviceStatus.offline);
              await client.setAction(deviceCode, DeviceAction.none);
            }
          }
        }
      }
    });

    // Setup Bluetooth adapter state listener
    FlutterBluePlus.adapterState.listen((state) async {
      print('Bluetooth adapter state: $state');
      if (state == BluetoothAdapterState.on) {
        print('Bluetooth adapter is on. Scan starting...');
        await startScan();
      } else {
        print('Bluetooth adapter is off');
      }
    });
    
    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
        if (results.isEmpty) {
          print('No scan results available');
          return;
        }
        
        final result = results.last;
        // Print all manufacturer data for debugging
        /*result.advertisementData.manufacturerData.forEach((key, value) {
          print('Manufacturer Data - Key: 0x${key.toRadixString(16)}, Value: ${String.fromCharCodes(value)}');
        });*/

        // Check if the device's manufacturer data matches any authorized device
        // Only process entries where key is 0x6d62 ('mb' in hex) or 'mb'
        final manufacturerId = result.advertisementData.manufacturerData.entries
            .where((entry) =>
                entry.key == 0x6d62 || entry.key.toRadixString(16) == '6d62')
            .map((entry) {
          final id = 'mb${String.fromCharCodes(entry.value)}';
          //print('Found Medibound device ID: $id');
          return id;
        }).firstWhere((id) => _authorizedDeviceIds.contains(id),
                orElse: () => '');

        if (manufacturerId.isNotEmpty) {
          // Store the manufacturer ID for this device
          _deviceIdentifiers[result.device.remoteId.str] = manufacturerId;

          if (!_connectedDevices.containsKey(manufacturerId)) {
            print('Found authorized device: $manufacturerId');
            connect(result.device);
          }
        
      }
    });
  }

  Future<void> startScan() async {
    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth not supported');
    }

    // Start scanning with manufacturer data filter
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
      withMsd: [
        MsdFilter(
          0x6d62,
        )]
    );

    
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connectToDeviceId(String deviceId) async {
    try {
      // Start scanning to find the device
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5), withMsd: [
        MsdFilter(
          0x6d62,
        )
      ]);

      bool deviceFound = false;
      await for (final results in FlutterBluePlus.scanResults) {
        for (ScanResult result in results) {
          final manufacturerId = result.advertisementData.manufacturerData.keys
              .map((id) => 'mb$id')
              .firstWhere((id) => id == deviceId, orElse: () => '');

          if (manufacturerId.isNotEmpty) {
            deviceFound = true;
            await connect(result.device);
            break;
          }
        }
        if (deviceFound) break;
      }

      if (!deviceFound) {
        print('Device with ID $deviceId not found');
      }

      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Error connecting to device $deviceId: $e');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      if (device.isConnected) {
        print('Device already connected, disconnecting first...');
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await device.connect(timeout: const Duration(seconds: 15));
      print('Connected to device: ${device.remoteId.str}');
      
      // Wait for connection to stabilize
      await Future.delayed(const Duration(seconds: 1));
      
      if (!device.isConnected) {
        throw Exception('Connection lost immediately after connecting');
      }
    } catch (e) {
      print('Error connecting to device: $e');
      // Clean up connection state
      final bleId = device.remoteId.str;
      final deviceId = _deviceIdentifiers[bleId];
      if (deviceId != null) {
        _connectedDevices.remove(deviceId);
        _deviceIdentifiers.remove(bleId);
      }
    }
  }

  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print('Disconnected from device: ${device.remoteId.str}');
    } catch (e) {
      print('Error disconnecting from device: $e');
    }
  }

  void dispose() {
    _devicesSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    for (var device in _connectedDevices.values) {
      device.disconnect();
    }
    _connectedDevices.clear();
    _deviceStatusController.close();
    _deviceDataController.close();
    _deviceBatteryController.close();
  }

  /// Scans for a specific device by ID
  /// Returns the BluetoothDevice if found, null otherwise
  Future<BluetoothDevice?> scanForDevice(String deviceId) async {
    try {
      print('Scanning for device: $deviceId');
      
      // Start scanning with manufacturer data filter
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
        withMsd: [MsdFilter(0x6d62)]
      );

      BluetoothDevice? foundDevice;
      
      // Wait for scan results
      await for (final results in FlutterBluePlus.scanResults) {
        for (ScanResult result in results) {
          // Check manufacturer data for our device ID
          final manufacturerId = result.advertisementData.manufacturerData.entries
              .where((entry) => entry.key == 0x6d62 || entry.key.toRadixString(16) == '6d62')
              .map((entry) => 'mb${String.fromCharCodes(entry.value)}')
              .firstWhere((id) => id == deviceId, orElse: () => '');

          if (manufacturerId.isNotEmpty) {
            foundDevice = result.device;
            break;
          }
        }
        if (foundDevice != null) break;
      }

      // Stop scanning
      await FlutterBluePlus.stopScan();
      
      if (foundDevice != null) {
        print('Device found: $deviceId');
      } else {
        print('Device not found: $deviceId');
      }
      
      return foundDevice;

    } catch (e) {
      print('Error scanning for device $deviceId: $e');
      return null;
    }
  }

  /// Scans for a device, connects to it, and claims ownership if successful
  /// Returns true if the device was found, connected and claimed successfully
  Future<bool> claimDevice(String deviceId) async {
    final fullDeviceId = 'mb$deviceId';
    try {
      print('Attempting to claim device: $fullDeviceId');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('No authenticated user to claim device');
        return false;
      }

      

      // Temporarily add device to authorized list so scan will pick it up
      _authorizedDeviceIds.add(fullDeviceId);
      print('Temporarily authorized device for claiming: $fullDeviceId');

      // First scan for the device
      final device = await scanForDevice(fullDeviceId);
      if (device == null) {
        print('Device not found during scan: $fullDeviceId');
        _authorizedDeviceIds.remove(fullDeviceId);
        return false;
      }

      // Try to connect to the device
      try {
        await connect(device);
        
        // Wait a bit to ensure connection is stable
        await Future.delayed(const Duration(seconds: 2));
        
        if (!device.isConnected) {
          print('Connection failed to stabilize');
          _authorizedDeviceIds.remove(fullDeviceId);
          return false;
        }

        // Find the device document
        final deviceDocs = await _db
            .collectionGroup('device')
            .where('info.code', isEqualTo: fullDeviceId.substring(2))  // Remove 'mb' prefix
            .limit(1)
            .get();

        if (deviceDocs.docs.isEmpty) {
          print('Device document not found in Firestore');
          _authorizedDeviceIds.remove(fullDeviceId);
          if (device.isConnected) {
            await disconnect(device);
          }
          return false;
        }

        final deviceDoc = deviceDocs.docs.first;
        final userDoc = await _db.collection('users').doc(user.uid).get();
        
        // Update the owner field
        await deviceDoc.reference.update({
          'owner': userDoc.reference
        });

        print('Successfully claimed device: $deviceId');
        // Note: Don't remove from _authorizedDeviceIds here as it's now properly owned
        return true;

      } catch (e) {
        print('Error during device claim process: $e');
        _authorizedDeviceIds.remove(fullDeviceId);
        if (device.isConnected) {
          await disconnect(device);
        }
        return false;
      }

    } catch (e) {
      print('Error claiming device: $e');
      _authorizedDeviceIds.remove(fullDeviceId);
      return false;
    }
  }
}
