import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Demo',
      home: BluetoothPage(),
    );
  }
}

class BluetoothPage extends StatefulWidget {
  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  FlutterBluePlus flutterBluePlus = FlutterBluePlus.instance;
  List<BluetoothDevice> devicesList = [];
  StreamSubscription<ScanResult>? scanSubscription;
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? characteristic;
  TextEditingController controller = TextEditingController();
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  
  @override
  void initState() {
    super.initState();
    requestPermission();
    startScan();
  }

  Future<void> requestPermission() async {
    final status = await Permission.bluetooth.request();
    setState(() {
      _permissionStatus = status;
    });
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }

  void startScan() {
    scanSubscription = flutterBluePlus.scan().listen((scanResult) {
      if (!devicesList.contains(scanResult.device)) {
        setState(() {
          devicesList.add(scanResult.device);
        });
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    scanSubscription?.cancel();
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
      });
      discoverServices(device);
    } catch (e) {
      print(e.toString());
    }
  }

  void disconnectFromDevice() {
    connectedDevice?.disconnect();
    setState(() {
      connectedDevice = null;
      characteristic = null;
    });
    startScan();
  }

  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) {
      service.characteristics.forEach((c) {
        if (c.uuid.toString() == "00002a37-0000-1000-8000-00805f9b34fb") {
          setState(() {
            characteristic = c;
          });
          readFromDevice();
        }
      });
    });
  }

  void readFromDevice() async {
    List<int> value = await characteristic!.read();
    setState(() {
      controller.text = String.fromCharCodes(value);
    });
  }

  void writeToDevice() async {
    String text = controller.text;
    List<int> value = text.codeUnits;
    await characteristic!.write(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Demo'),
      ),
      body: Column(
        children: <Widget>[
          connectedDevice != null
              ? ListTile(
                  title: Text(connectedDevice!.name ?? ''),
                  subtitle: Text(connectedDevice!.id.toString()),
                  trailing: IconButton(
                    icon: Icon(Icons.bluetooth_disabled),
                    onPressed: disconnectFromDevice,
                  ),
                )
              : SizedBox(),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (BuildContext context, int index) {
                BluetoothDevice device = devicesList[index];
                return ListTile(
                  title: Text(device.name ?? ''),
                  subtitle: Text(device.id.toString()),
                  trailing: ElevatedButton(
                    child: Text('Connect'),
                    onPressed: () => connectToDevice(device),
                  ),
                );
              },
            ),
          ),
          characteristic != null
              ? Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Send data',
                      border: OutlineInputBorder(),
                    ),
                  ),
                )
              : SizedBox(),
          characteristic != null
              ? Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    child: Text('Send'),
                    onPressed: () => writeToDevice(),
                  ),
                )
              : SizedBox(),
              
            _permissionStatus == PermissionStatus.granted
            ? Text('Bluetooth permission granted!')
            : Text('Bluetooth permission not granted.'),
        ],
      ),
    );
  }
}