import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_theme.dart';
import '../../providers/bluetooth_provider.dart';
import '../../models/bluetooth_device_model.dart';

class DeviceScannerScreen extends StatefulWidget {
  const DeviceScannerScreen({super.key});

  @override
  State<DeviceScannerScreen> createState() => _DeviceScannerScreenState();
}

class _DeviceScannerScreenState extends State<DeviceScannerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doStartScan();
    });
  }

  // ─── Start scan — checks BT state first ────────────────────────────────────
  Future<void> _doStartScan() async {
    final provider = context.read<BluetoothProvider>();
    await provider.startScan();

    // If BT turned off, show the dialog after scan attempt returns
    if (mounted && provider.isBluetoothOff) {
      _showBluetoothOffDialog();
    }
  }

  // ─── Bluetooth-off dialog ───────────────────────────────────────────────────
  void _showBluetoothOffDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bluetooth_disabled_rounded,
              size: 30, color: Colors.blue),
        ),
        title: const Text(
          'Bluetooth is Off',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please turn on Bluetooth to scan for your HM-10 device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 16),
            // Step-by-step instructions card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.blue.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _StepRow(
                    number: '1',
                    text: 'Pull down from the top of your screen',
                  ),
                  SizedBox(height: 8),
                  _StepRow(
                    number: '2',
                    text: 'Tap the Bluetooth icon to enable it',
                  ),
                  SizedBox(height: 8),
                  _StepRow(
                    number: '3',
                    text: 'Come back here and tap "Scan Again"',
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<BluetoothProvider>().clearBluetoothOffFlag();
            },
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<BluetoothProvider>().clearBluetoothOffFlag();
              _doStartScan(); // retry immediately after dialog closes
            },
            icon: const Icon(Icons.bluetooth_searching, size: 18),
            label: const Text('Scan Again'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Device'),
        elevation: 0,
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, btProvider, _) {
          // Show Bluetooth-off dialog reactively when state changes while on page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && btProvider.isBluetoothOff) {
              _showBluetoothOffDialog();
            }
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HM-10 only info banner ─────────────────────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark
                                ? AppColors.primaryLight
                                : AppColors.primaryDark,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Only HM-10 modules are shown. ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text:
                                  'Earbuds, phones, and other devices are automatically hidden. '
                                  'Power on your HM-10 — it will appear as ',
                            ),
                            TextSpan(
                              text: '"HMSoft"',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' or your custom name below.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Setup guide (collapsible) ──────────────────────────────────
              const _HM10SetupGuide(),

              // ── Header row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HM-10 Devices',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          btProvider.isScanning
                              ? 'Scanning for HM-10 modules...'
                              : '${btProvider.availableDevices.length} device(s) found',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : Colors.grey[500],
                                  ),
                        ),
                      ],
                    ),
                    if (btProvider.isScanning)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () => _doStartScan(),
                        tooltip: 'Scan again',
                      ),
                  ],
                ),
              ),

              // ── Error message (non-BT-off errors) ─────────────────────────
              if (btProvider.errorMessage != null &&
                  btProvider.errorMessage!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          btProvider.errorMessage!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Raw data debug panel (shown when HM-10 is connected) ───────
              if (btProvider.isConnected && btProvider.isHM10Device)
                _HM10DebugPanel(rawDataLog: btProvider.rawDataLog),

              // ── Device list ────────────────────────────────────────────────
              Expanded(
                child: btProvider.availableDevices.isEmpty
                    ? _buildEmptyState(context, btProvider)
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: btProvider.availableDevices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device =
                              btProvider.availableDevices[index];
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

  Widget _buildEmptyState(
      BuildContext context, BluetoothProvider btProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                btProvider.isScanning
                    ? Icons.bluetooth_searching
                    : Icons.developer_board_outlined,
                size: 40,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              btProvider.isScanning
                  ? 'Scanning...'
                  : 'No HM-10 Found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              btProvider.isScanning
                  ? 'Looking for nearby HM-10 / UART BLE modules.'
                  : 'Make sure your HM-10 is powered on, its LED is blinking, and it\'s not already connected to another device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isDark ? AppColors.darkTextMuted : Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!btProvider.isScanning)
              ElevatedButton.icon(
                onPressed: () => _doStartScan(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Scan Again'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Step row helper ─────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─── HM-10 Setup Guide (collapsible) ─────────────────────────────────────────
class _HM10SetupGuide extends StatefulWidget {
  const _HM10SetupGuide();

  @override
  State<_HM10SetupGuide> createState() => _HM10SetupGuideState();
}

class _HM10SetupGuideState extends State<_HM10SetupGuide> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A2A)
            : const Color(0xFFF5F5FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Text(
                    'How to make your HM-10 appear here',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _guideRow(Icons.power_settings_new_rounded,
                      'Power on your HM-10 module (connect to 3.3V and GND)'),
                  _guideRow(Icons.lightbulb_outline_rounded,
                      'The LED should blink rapidly — this means it\'s advertising and waiting to connect'),
                  _guideRow(Icons.phone_android_rounded,
                      'Make sure your phone\'s Bluetooth is ON'),
                  _guideRow(Icons.bluetooth_connected_rounded,
                      'Make sure the HM-10 is not already connected to another phone or device'),
                  _guideRow(Icons.wifi_tethering_error_rounded,
                      'Keep your phone within 5–10 metres of the module'),
                  _guideRow(Icons.text_fields_rounded,
                      'The module appears as "HMSoft", "MLT-BT05", "JDY-08" or your custom AT+NAME'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.tips_and_updates_rounded,
                            size: 14, color: Colors.amber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Only HM-10 compatible UART-BLE modules appear here. '
                            'Earbuds, phones, and other Bluetooth devices are automatically filtered out.',
                            style:
                                TextStyle(fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _guideRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

// ─── HM-10 raw data debug panel ──────────────────────────────────────────────
class _HM10DebugPanel extends StatefulWidget {
  final List<List<int>> rawDataLog;
  const _HM10DebugPanel({required this.rawDataLog});

  @override
  State<_HM10DebugPanel> createState() => _HM10DebugPanelState();
}

class _HM10DebugPanelState extends State<_HM10DebugPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2A1A)
            : const Color(0xFFF0FFF0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cable_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'HM-10 Serial — ${widget.rawDataLog.length} packet(s) received',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.rawDataLog.isNotEmpty)
            Container(
              height: 120,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ListView.builder(
                itemCount: widget.rawDataLog.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final realIndex = widget.rawDataLog.length - 1 - index;
                  final bytes = widget.rawDataLog[realIndex];
                  final hex = bytes
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(' ');
                  final asText = String.fromCharCodes(
                      bytes.where((b) => b >= 32 && b < 127));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '[$realIndex] $hex  →  "$asText"',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: isDark
                            ? Colors.green[300]
                            : Colors.green[800],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Device card ──────────────────────────────────────────────────────────────
class _DeviceCard extends StatelessWidget {
  final BluetoothDeviceModel device;
  const _DeviceCard({required this.device});

  static const Color _hm10Green = Color(0xFF00C853);

  Color _signalColor(int rssi) {
    if (rssi >= -60) return AppColors.success;
    if (rssi >= -75) return AppColors.warning;
    return AppColors.danger;
  }

  String _signalLabel(int rssi) {
    if (rssi >= -60) return 'Strong';
    if (rssi >= -75) return 'Good';
    return 'Weak';
  }

  int _signalBars(int rssi) {
    if (rssi >= -60) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final signalColor = _signalColor(device.signalStrength);

    return Container(
      decoration: BoxDecoration(
        color: device.isConnected
            ? _hm10Green.withValues(alpha: 0.06)
            : isDark
                ? AppColors.darkSurface
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: device.isConnected
              ? _hm10Green.withValues(alpha: 0.35)
              : _hm10Green.withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: _hm10Green.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Device icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hm10Green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.developer_board_outlined,
                size: 22,
                color: _hm10Green,
              ),
            ),
            const SizedBox(width: 12),

            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // HM-10 badge
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _hm10Green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _hm10Green.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'HM-10',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _hm10Green,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      // Connected badge
                      if (device.isConnected) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    device.macAddress,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : Colors.grey[500],
                              fontFamily: 'monospace',
                            ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Signal bars
                      Row(
                        children: List.generate(3, (bar) {
                          final filled =
                              bar < _signalBars(device.signalStrength);
                          return Container(
                            width: 4,
                            height: 6 + bar * 3.0,
                            margin: const EdgeInsets.only(right: 2),
                            decoration: BoxDecoration(
                              color: filled
                                  ? signalColor
                                  : signalColor
                                      .withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_signalLabel(device.signalStrength)} (${device.signalStrength} dBm)',
                        style: TextStyle(
                          fontSize: 10,
                          color: signalColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'UART BLE',
                        style: TextStyle(
                          fontSize: 9,
                          color: _hm10Green.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Action button
            Consumer<BluetoothProvider>(
              builder: (context, btProvider, _) {
                if (device.isConnected) {
                  return OutlinedButton(
                    onPressed: () => btProvider.disconnectDevice(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                          color:
                              AppColors.danger.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Disconnect',
                        style: TextStyle(fontSize: 12)),
                  );
                }
                return ElevatedButton(
                  onPressed: btProvider.isConnecting
                      ? null
                      : () => btProvider.connectToDevice(device),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: btProvider.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Text('Connect',
                          style: TextStyle(fontSize: 12)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
