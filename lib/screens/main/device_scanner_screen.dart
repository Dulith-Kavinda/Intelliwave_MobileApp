import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/bluetooth_provider.dart';
import '../../models/bluetooth_device_model.dart';

class DeviceScannerScreen extends StatefulWidget {
  const DeviceScannerScreen({Key? key}) : super(key: key);

  @override
  State<DeviceScannerScreen> createState() => _DeviceScannerScreenState();
}

class _DeviceScannerScreenState extends State<DeviceScannerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        context.read<BluetoothProvider>().startScan();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        elevation: 0,
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, btProvider, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Devices',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (btProvider.isScanning)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => btProvider.startScan(),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: btProvider.availableDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 64,
                              color: AppColors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              btProvider.isScanning
                                  ? 'Scanning for devices...'
                                  : 'No devices found',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure your device is switched on and in range',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.grey,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => btProvider.startScan(),
                              child: const Text('Scan Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: btProvider.availableDevices.length,
                        itemBuilder: (context, index) {
                          final device = btProvider.availableDevices[index];
                          return _DeviceCard(device: device);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final BluetoothDeviceModel device;

  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          device.isConnected ? Icons.bluetooth_connected : Icons.devices,
          color: device.isConnected ? AppColors.success : AppColors.primary,
        ),
        title: Text(device.name),
        subtitle: Text(
          'Signal: ${device.signalStrength} dBm',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Consumer<BluetoothProvider>(
          builder: (context, btProvider, _) {
            return device.isConnected
                ? ElevatedButton(
                    onPressed: () => btProvider.disconnectDevice(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                    ),
                    child: const Text('Disconnect'),
                  )
                : ElevatedButton(
                    onPressed: btProvider.isConnecting
                        ? null
                        : () => btProvider.connectToDevice(device),
                    child: btProvider.isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect'),
                  );
          },
        ),
      ),
    );
  }
}
