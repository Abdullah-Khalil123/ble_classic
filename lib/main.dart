import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterBlueClassicPlugin = FlutterBlueClassic();
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? _adapterStateSubscription;

  final Map<String, BluetoothDevice> _scanResults = {};
  StreamSubscription? _scanSubscription;

  bool _isScanning = false;
  StreamSubscription? _scanningStateSubscription;

  Timer? _scanTimer;

  final double _referenceRssi = -70; // Initial value, adjust as needed
  final double _pathLossExponent = 3.0; // Initial value, adjust as needed

  bool contScan = false;

  void startContScan() {
    _scanTimer =
        Timer.periodic(const Duration(seconds: 2), (Timer timer) async {
      _flutterBlueClassicPlugin.startScan();
      await Future.delayed(const Duration(seconds: 1));
      _flutterBlueClassicPlugin.stopScan();
    });
  }

  void stopContScan() {
    _scanTimer?.cancel();
    _flutterBlueClassicPlugin.stopScan();
  }

  void requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationAlways,
    ].request();

    final bluetoothStatus = statuses[Permission.bluetooth];
    final locationStatus = statuses[Permission.location];
    final locationAlwaysStatus = statuses[Permission.locationAlways];

    if (bluetoothStatus == PermissionStatus.granted &&
        locationStatus == PermissionStatus.granted &&
        locationAlwaysStatus == PermissionStatus.granted) {
      Fluttertoast.showToast(
        msg: "Bluetooth and Location permissions granted.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
    } else if (bluetoothStatus == PermissionStatus.denied ||
        locationStatus == PermissionStatus.denied ||
        locationAlwaysStatus == PermissionStatus.denied) {
      Fluttertoast.showToast(
        msg: "Bluetooth or Location permission denied.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    } else if (bluetoothStatus == PermissionStatus.permanentlyDenied ||
        locationStatus == PermissionStatus.permanentlyDenied ||
        locationAlwaysStatus == PermissionStatus.permanentlyDenied) {
      Fluttertoast.showToast(
        msg:
            "Bluetooth or Location permission permanently denied. Please enable them in settings.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      openAppSettings();
    }
  }

  Future<void> initPlatformState() async {
    BluetoothAdapterState adapterState = _adapterState;

    try {
      adapterState = await _flutterBlueClassicPlugin.adapterStateNow;
      _adapterStateSubscription =
          _flutterBlueClassicPlugin.adapterState.listen((current) {
        if (mounted) setState(() => _adapterState = current);
      });
      _scanSubscription =
          _flutterBlueClassicPlugin.scanResults.listen((device) {
        if (mounted) {
          setState(() {
            _scanResults[device.address] = device;
          });
        }
      });
      _scanningStateSubscription =
          _flutterBlueClassicPlugin.isScanning.listen((isScanning) {
        if (mounted) setState(() => _isScanning = isScanning);
      });
    } catch (e) {
      if (kDebugMode) print(e);
    }

    if (!mounted) return;

    setState(() {
      _adapterState = adapterState;
    });
  }

  num calculateDistance(int? rssi) {
    final int rssiValue = rssi ?? -100; // Default value if null
    return pow(10, ((_referenceRssi - rssiValue) / (10 * _pathLossExponent)));
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    initPlatformState();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            "BLUETOOTH CLASSIC PROTOCOL",
            style: TextStyle(fontSize: 18),
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _scanResults.clear(); // Clear scan results
                });
              },
              icon: const Icon(Icons.delete),
            ),
            IconButton(
              onPressed: () {
                // _showUpdateDialog(); // Show dialog to update RSSI and path loss exponent
              },
              icon: const Icon(Icons.settings),
            )
          ],
        ),
        body: _scanResults.isEmpty
            ? const Center(child: Text("NO DEVICES FOUND "))
            : ListView.builder(
                itemCount: _scanResults.length,
                itemBuilder: (context, index) {
                  final device = _scanResults.values.elementAt(index);

                  return ListTile(
                    title: Text(device.name ?? device.address),
                    subtitle: Text(device.address),
                    trailing: Text(device.rssi.toString()),
                    leading: Text(
                        "${calculateDistance(device.rssi).toStringAsFixed(2)}\nMeters"),
                  );
                }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (contScan == false) {
              setState(() {
                contScan = true;
              });
              startContScan();
            } else {
              setState(() {
                contScan = false;
              });
              stopContScan();
            }
          },
          icon: const Icon(Icons.refresh),
          label: Text(contScan ? "SCANNING" : "SCAN"),
        ),
      ),
    );
  }
}
