import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/ecg_provider.dart';
import '../../widgets/live_ecg_graph_widget.dart';
import '../../widgets/ecg_analysis_widget.dart';
import '../../screens/main/device_scanner_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
      ),
      body: Consumer2<BluetoothProvider, ECGProvider>(
        builder: (context, btProvider, ecgProvider, _) {
          return SingleChildScrollView(
            child: Column(
              children: [
                LiveECGGraphWidget(
                  ecgData: ecgProvider.ecgData,
                  isConnected: ecgProvider.isConnected,
                  hasError: ecgProvider.hasDataError,
                  errorMessage: ecgProvider.errorMessage,
                  onConnectDevice: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceScannerScreen(),
                      ),
                    );
                  },
                  onFullscreen: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullscreenECGGraph(
                          ecgData: ecgProvider.ecgData,
                          isConnected: ecgProvider.isConnected,
                          hasError: ecgProvider.hasDataError,
                          errorMessage: ecgProvider.errorMessage,
                        ),
                      ),
                    );
                  },
                ),
                ECGAnalysisWidget(
                  ecgData: ecgProvider.ecgData,
                  isConnected: ecgProvider.isConnected,
                  hasError: ecgProvider.hasDataError,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
