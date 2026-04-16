# IntelIWave App Features Implementation Guide

## 1. PROFILE IMAGE UPLOADING

### Files to Modify:
- `lib/screens/main/profile_screen.dart`
- `lib/services/user_profile_service.dart`

### Features:
- Pick image from gallery or camera
- Upload to Supabase Storage
- Display profile picture
- Update user profile with image URL

### Status: ✅ READY TO IMPLEMENT

---

## 2. APP SETTINGS & PREFERENCES

### Files to Modify:
- `lib/screens/main/settings_screen.dart`
- `lib/providers/settings_provider.dart`

### Features:
- ✅ Theme switcher (Light/Dark/System)
- ✅ Notification toggles
- ✅ Heart rate alerts
- 🔲 Data persistence to Supabase
- 🔲 Units preference (Metric/Imperial)
- 🔲 Language selection

### Status: PARTIALLY IMPLEMENTED

---

## 3. ECG GRAPH VIEWING

### Files to Modify:
- `lib/screens/main/history_screen.dart`
- `lib/widgets/common_widgets.dart` (new ECG chart widget)

### Features:
- 📊 Interactive ECG graph viewer
- 📈 Real-time ECG data visualization
- 📍 Time-series data display
- 🔍 Zoom and pan on graphs

### Status: 🔲 NOT IMPLEMENTED

### Dependencies Needed:
```yaml
dependencies:
  fl_chart: ^0.65.0  # For ECG graphs
  image_picker: ^1.0.0  # For profile picture
  permission_handler: ^11.0.0  # For camera/gallery access
```

---

## 4. ECG GRAPH SHARING

### Features:
- 📤 Share ECG data as image
- 📧 Share via email with data
- 🔗 Generate shareable links
- 📋 Export as CSV/PDF

### Status: 🔲 NOT IMPLEMENTED

### Dependencies Needed:
```yaml
dependencies:
  share_plus: ^7.0.0  # For sharing
  pdf: ^3.10.0  # For PDF export
```

---

## Implementation Priorities:

1. **Profile Image Upload** - Most requested
2. **ECG Graph Viewing** - Core feature
3. **ECG Graph Sharing** - Enhancement
4. **Settings Persistence** - Quality of life

---

## Next Steps:
1. Run SQL to delete demo account ✅
2. Add image_picker dependency
3. Implement profile image upload
4. Add ECG graph widget
5. Implement sharing functionality

