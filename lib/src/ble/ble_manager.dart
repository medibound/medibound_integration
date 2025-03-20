import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/enums.dart';

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription? _devicesSubscription;
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final List<String> _authorizedDeviceIds = [];

  // Stream controllers for local state management
  final _deviceStatusController = StreamController<Map<String, String>>.broadcast();
  final _deviceDataController = StreamController<Map<String, String>>.broadcast();
  final _deviceBatteryController = StreamController<Map<String, int>>.broadcast();

  // Public streams
  Stream<Map<String, String>> get deviceStatus => _deviceStatusController.stream;
  Stream<Map<String, String>> get deviceData => _deviceDataController.stream;
  Stream<Map<String, int>> get deviceBattery => _deviceBatteryController.stream;

  BleManager._internal();

  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user');
      return;
    }

    // Listen to devices owned by the current user
    _devicesSubscription = _db
        .collection('device_profiles')
        .where('owner', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      _authorizedDeviceIds.clear();
      for (var doc in snapshot.docs) {
        final deviceId = doc.id;
        _authorizedDeviceIds.add('mb$deviceId');
        print('Authorized device ID: mb$deviceId');
      }
    });

    // Setup Bluetooth listeners
    FlutterBluePlus.adapterState.listen((state) {
      print('Bluetooth adapter state: $state');
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
    );

    // Listen for scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // Check if the device's manufacturer data matches any authorized device
        final manufacturerId = result.advertisementData.manufacturerData.keys
            .map((id) => 'mb$id')
            .firstWhere((id) => _authorizedDeviceIds.contains(id),
                orElse: () => '');

        if (manufacturerId.isNotEmpty && 
            !_connectedDevices.containsKey(manufacturerId)) {
          print('Found authorized device: $manufacturerId');
          connect(result.device);
        }
      }
    });
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevices[device.remoteId.str] = device;
      print('Connected to device: ${device.remoteId.str}');
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _connectedDevices.remove(device.remoteId.str);
      print('Disconnected from device: ${device.remoteId.str}');
    } catch (e) {
      print('Error disconnecting from device: $e');
    }
  }

  void dispose() {
    _devicesSubscription?.cancel();
    for (var device in _connectedDevices.values) {
      device.disconnect();
    }
    _connectedDevices.clear();
  }
} 