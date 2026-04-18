# Live ECG Graph Feature - User Guide

## Overview
The IntelIWave app now displays **live ECG (Electrocardiogram) waveforms** on the dashboard, providing real-time visualization of your heart's electrical activity directly from your Bluetooth-connected ECG device.

## Features

### 1. **Live ECG Display**
- Real-time ECG waveform shown on the dashboard
- Displays the most recent ECG data points
- Green "Live" indicator badge shows active data reception
- Grid and axis labels for easy reading and analysis

### 2. **Device Connection Status**
The ECG graph automatically responds to your device connection status:

#### ✅ **Connected & Data Available**
- Live ECG waveform is displayed
- Graph is fully interactive and responsive
- Real-time updates as new data arrives

#### ❌ **Device Not Connected**
- Graph shows a disabled state with a Bluetooth icon
- Message: "No Device Connected"
- "Connect Device" button redirects to the device scanner
- Quick way to reconnect your ECG device

#### ⚠️ **Connection Error**
- Graph shows an error state with detailed message
- Message: "Error in Getting Data"
- Shows the specific error that occurred
- "Reconnect Device" button to retry the connection

### 3. **Fullscreen Mode**
- Tap the **fullscreen icon** (📱➔) in the top-right corner of the graph tile
- View the ECG graph in full-screen for detailed analysis
- Tap the **close button** (✕) or back button to return to the dashboard
- Fullscreen mode provides maximum space for detailed graph viewing

## How to Use

### Viewing Live ECG Data
1. **Connect a Bluetooth ECG Device** - Navigate to the device scanner and connect your device
2. **Go to Dashboard** - The app will automatically show the Live ECG graph at the top
3. **Monitor the Graph** - Watch the real-time ECG waveform as it updates
4. **Check the Status Indicator** - The "Live" badge indicates active data reception

### Viewing in Fullscreen
1. **While on Dashboard** - Find the Live ECG graph widget
2. **Tap the Fullscreen Icon** - Located in the top-right corner of the graph
3. **View Full Details** - Enjoy the complete ECG waveform in fullscreen
4. **Return to Dashboard** - Tap the close (✕) icon or use the back button

### Reconnecting Device
If you see "No Device Connected":
1. Tap the **"Connect Device"** button in the graph area
2. Follow the device scanner to find and connect your ECG device
3. The graph will automatically update once connected

If you see "Error in Getting Data":
1. Tap the **"Reconnect Device"** button
2. If the error persists, try:
   - Disconnecting and reconnecting the device
   - Restarting the app
   - Checking your device's battery level

## Technical Details

### Supported ECG Data
- Raw ECG waveform samples
- Real-time data from BLE (Bluetooth Low Energy) devices
- Compatible with standard ECG monitors and smartwatches

### Data Visualization
- **Display Range**: Shows last 100 data points for optimal visualization
- **Buffer Size**: Up to 500 points maintained in memory
- **Update Rate**: Updates in real-time as new data arrives
- **Scaling**: Data automatically normalized for consistent display

### Graph Information
- **Live Indicator**: Green badge shows active connection
- **Data Points Counter**: Shows total ECG samples received
- **Grid Display**: Helps with rhythm analysis
- **Multiple Scales**: Responsive to different screen sizes

## Troubleshooting

### Graph Not Showing Any Data
**Solution:**
- Ensure your Bluetooth device is properly connected
- Check that the device is transmitting ECG data
- Try disconnecting and reconnecting the device
- Restart the app

### "Error in Getting Data" Message
**Possible Causes & Solutions:**
- Device connection lost → Reconnect the device
- Device not transmitting data → Check device settings
- Bluetooth permission issues → Check app permissions
- Device compatibility → Ensure device supports ECG transmission

### Graph Appears Blank
**Solution:**
- Wait a few seconds for the first data to arrive
- Check that your device is actively transmitting
- Verify device is properly paired with your phone
- Try reconnecting the device

### Fullscreen Mode Doesn't Work
**Solution:**
- Ensure device is connected and showing data
- Try restarting the app
- Check for any app updates

## Supported Devices

The live ECG graph works with Bluetooth ECG devices that support:
- Standard BLE (Bluetooth Low Energy) ECG characteristics
- Common BLE UUIDs: 2A65, ECG, Wave, or custom ECG services
- Heart rate and ECG data transmission

## Privacy & Data

- ECG data is only displayed locally on your device
- No ECG waveform data is stored without your explicit action
- Connection to Supabase can be configured separately
- Your Bluetooth device data remains private

## Tips for Best Results

1. **Keep Device Close**: Keep your ECG device within 10 meters of your phone
2. **Minimize Interference**: Avoid sources of electromagnetic interference
3. **Full Contact**: Ensure proper electrode contact on your body for accurate readings
4. **Monitor Regularly**: Regular monitoring helps track patterns over time
5. **Export Data**: Save important readings through the app's export feature

## Integration with Other Features

The Live ECG Graph integrates seamlessly with:
- **Current Heart Rate** display (BPM)
- **Heart Rate Trend** chart
- **Device Status** indicator
- **Timed Health Checks**
- **Health History**

## Future Enhancements

Potential upcoming features:
- ECG recording and playback
- Rhythm pattern analysis
- Export ECG data as images or PDFs
- Comparison with historical data
- Arrhythmia detection alerts

---

**Need Help?** For additional support, check the app's Help section or contact our support team.
