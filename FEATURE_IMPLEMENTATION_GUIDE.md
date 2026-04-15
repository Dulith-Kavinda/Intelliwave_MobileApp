# Feature Implementation Guide

This guide explains how to extend the IntelIWave app with new features following the existing architecture.

## Architecture Overview

```
Models (Data Layer)
    ↓
Services (Business Logic)
    ↓
Providers (State Management)
    ↓
Screens & Widgets (UI)
```

---

## Adding a New Feature: Complete Example

### Example: "Medication Reminders" Feature

#### Step 1: Create Data Model

**File:** `lib/models/medication_model.dart`

```dart
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'medication_model.g.dart';

@HiveType(typeId: 6) // Next available typeId
class Medication extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String dosage;

  @HiveField(4)
  final List<String> times; // ["08:00", "14:00", "20:00"]

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  final DateTime? endDate;

  @HiveField(7)
  final bool isActive;

  @HiveField(8)
  final String notes;

  Medication({
    String? id,
    required this.userId,
    required this.name,
    required this.dosage,
    required this.times,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'dosage': dosage,
      'times': times,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'notes': notes,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as String,
      userId: map['userId'] as String,
      name: map['name'] as String,
      dosage: map['dosage'] as String,
      times: List<String>.from(map['times'] as List),
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null 
        ? DateTime.parse(map['endDate'] as String) 
        : null,
      isActive: map['isActive'] as bool? ?? true,
      notes: map['notes'] as String? ?? '',
    );
  }

  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? notes,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }
}
```

#### Step 2: Create Storage Service Methods

**File:** `lib/services/storage_service.dart` - Add to the class:

```dart
// Add this to StorageService class

Future<void> initMedicationBox() async {
  await Hive.openBox<Medication>('medications');
}

Box<Medication> get medicationBox => Hive.box<Medication>('medications');

Future<void> addMedication(Medication medication) async {
  await medicationBox.put(medication.id, medication);
}

Future<void> deleteMedication(String id) async {
  await medicationBox.delete(id);
}

List<Medication> getMedicationsByUserId(String userId) {
  return medicationBox.values
    .where((med) => med.userId == userId && med.isActive)
    .toList();
}

List<Medication> getAllMedications(String userId) {
  return medicationBox.values
    .where((med) => med.userId == userId)
    .toList();
}

Medication? getMedicationById(String id) {
  return medicationBox.get(id);
}

Future<void> updateMedication(Medication medication) async {
  await medicationBox.put(medication.id, medication);
}
```

#### Step 3: Create Provider (State Management)

**File:** `lib/providers/medication_provider.dart`

```dart
import 'package:flutter/foundation.dart';
import '../models/medication_model.dart';
import '../services/storage_service.dart';
import '../utils/service_locator.dart';

class MedicationProvider extends ChangeNotifier {
  final _storageService = storageService;

  List<Medication> _medications = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Medication> get medications => _medications;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  Future<void> loadMedications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _medications = _storageService.getMedicationsByUserId(userId);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMedication(Medication medication) async {
    try {
      await _storageService.addMedication(medication);
      _medications.add(medication);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateMedication(Medication medication) async {
    try {
      await _storageService.updateMedication(medication);
      final index = _medications.indexWhere((m) => m.id == medication.id);
      if (index != -1) {
        _medications[index] = medication;
      }
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteMedication(String id) async {
    try {
      await _storageService.deleteMedication(id);
      _medications.removeWhere((m) => m.id == id);
      _errorMessage = '';
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  int get activeMedicationCount => 
    _medications.where((m) => m.isActive).length;

  bool isMedicationDueNow(Medication medication) {
    final now = TimeOfDay.now();
    final nowString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    return medication.times.contains(nowString);
  }
}
```

#### Step 4: Create UI Screen

**File:** `lib/screens/main/medications_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/medication_model.dart';
import '../../providers/medication_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({Key? key}) : super(key: key);

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  void _loadMedications() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUserModel != null) {
      context.read<MedicationProvider>().loadMedications(
        authProvider.currentUserModel!.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMedicationDialog(),
          ),
        ],
      ),
      body: Consumer<MedicationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.medications.isEmpty) {
            return const EmptyState(
              icon: Icons.medication,
              title: 'No Medications',
              message: 'Add medications to track your health',
            );
          }

          return ListView.builder(
            itemCount: provider.medications.length,
            itemBuilder: (context, index) {
              final medication = provider.medications[index];
              return MedicationCard(
                medication: medication,
                onEdit: () => _showEditMedicationDialog(medication),
                onDelete: () => _deleteMedication(medication.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddMedicationDialog() {
    // Show dialog to add medication
    showDialog(
      context: context,
      builder: (_) => AddMedicationDialog(
        onSave: (medication) {
          context.read<MedicationProvider>().addMedication(medication);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditMedicationDialog(Medication medication) {
    // Show dialog to edit medication
    showDialog(
      context: context,
      builder: (_) => EditMedicationDialog(
        medication: medication,
        onSave: (updated) {
          context.read<MedicationProvider>().updateMedication(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteMedication(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<MedicationProvider>().deleteMedication(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MedicationCard({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(medication.name),
        subtitle: Text('${medication.dosage} • ${medication.times.join(", ")}'),
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            PopupMenuItem(
              child: const Text('Edit'),
              onTap: onEdit,
            ),
            PopupMenuItem(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// Add similar dialogs: AddMedicationDialog and EditMedicationDialog
```

#### Step 5: Update Main App

**File:** `lib/main.dart` - Modify:

```dart
// Add to providers list in main()
MultiProvider(
  providers: [
    // ... existing providers
    ChangeNotifierProvider(create: (_) => MedicationProvider()),
  ],
  child: const MyApp(),
)
```

**File:** `lib/utils/service_locator.dart` - Add initialization:

```dart
void setupServiceLocator() {
  getIt.registerSingleton<StorageService>(StorageService())
    ..initialize()
    ..initMedicationBox(); // Add this line
}
```

**File:** `lib/utils/routes.dart` - Add route:

```dart
static const medications = '/medications';

static Map<String, WidgetBuilder> getRoutes() {
  return {
    // ... existing routes
    medications: (context) => const MedicationsScreen(),
  };
}
```

#### Step 6: Add to Navigation

**File:** `lib/screens/main/home_screen.dart` - Update BottomNavigationBar:

```dart
BottomNavigationBar(
  items: [
    const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    const BottomNavigationBarItem(icon: Icon(Icons.bluetooth), label: 'Device'),
    const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
    const BottomNavigationBarItem(icon: Icon(Icons.medication), label: 'Meds'),
    const BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
    const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ],
  currentIndex: _selectedIndex,
  onTap: (index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  },
)

// Add to PageView children
PageView(
  controller: _pageController,
  children: [
    const DashboardScreen(),
    const DeviceScannerScreen(),
    const HistoryScreen(),
    const MedicationsScreen(), // ADD THIS
    const NotificationsScreen(),
    const ProfileScreen(),
  ],
)
```

#### Step 7: Build

```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

---

## Architecture Template for New Features

### Minimal Structure

```
1. Model (data_model.dart)
   ├── @HiveType decorator
   ├── toMap() / fromMap()
   └── copyWith()

2. Service Layer (Add to storage_service.dart)
   ├── CRUD operations
   ├── Query methods
   └── Error handling

3. Provider (feature_provider.dart)
   ├── ChangeNotifier
   ├── State variables
   ├── Business logic methods
   └── notifyListeners()

4. UI Layer (feature_screen.dart)
   ├── Consumer<FeatureProvider>
   ├── Widgets
   └── User interactions

5. Integration
   ├── Add to main.dart providers
   ├── Add route in routes.dart
   └── Add navigation entry
```

---

## Key Patterns Used

### 1. CRUD Pattern
```dart
// Create
await storageService.addItem(item);

// Read
final items = storageService.getItemsByUserId(userId);

// Update
await storageService.updateItem(item);

// Delete
await storageService.deleteItem(id);
```

### 2. Provider State Management
```dart
// In Provider
Future<void> loadData() async {
  _isLoading = true;
  notifyListeners();
  try {
    _data = await _service.fetch();
  } catch (e) {
    _errorMessage = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

// In UI
Consumer<MyProvider>(
  builder: (context, provider, _) {
    if (provider.isLoading) return LoadingWidget();
    if (provider.errorMessage.isNotEmpty) return ErrorWidget();
    return ContentWidget(provider.data);
  },
)
```

### 3. Async Operations
```dart
// Always await and handle errors
try {
  await operation();
} catch (e) {
  // Handle error
  _errorMessage = e.toString();
} finally {
  notifyListeners(); // Update UI
}
```

### 4. ID Generation
```dart
// Use UUID for unique IDs
import 'package:uuid/uuid.dart';

final id = const Uuid().v4();
```

---

## Common Additions

### Add a Service Method
```dart
// In StorageService
Future<void> addFeatureToUser(String userId, FeatureModel feature) async {
  feature.userId = userId;
  await featureBox.put(feature.id, feature);
}

// In Provider
Future<void> addFeature(FeatureModel feature) async {
  await _storageService.addFeatureToUser(userId, feature);
  _features.add(feature);
  notifyListeners();
}
```

### Add a Filter Method
```dart
// In Provider
List<FeatureModel> filterByDate(DateTime date) {
  return _features.where((f) => 
    f.date.year == date.year &&
    f.date.month == date.month &&
    f.date.day == date.day
  ).toList();
}
```

### Add Statistics
```dart
// In Provider
int get totalCount => _features.length;
double get averageValue => 
  _features.isEmpty ? 0 : 
  _features.map((f) => f.value).reduce((a, b) => a + b) / _features.length;
```

### Add Notifications
```dart
// When important action occurs
await notificationService.showNotification(
  id: DateTime.now().millisecondsSinceEpoch.toInt(),
  title: 'Feature Alert',
  body: 'Important update',
);

// In NotificationProvider
await _storageService.addNotification(AppNotification(
  title: 'Alert',
  message: 'Something happened',
  type: 'alert',
  isImportant: true,
));
```

---

## Testing Your Feature

### Unit Test Example
```dart
test('MedicationProvider adds medication', () async {
  final provider = MedicationProvider();
  final medication = Medication(
    userId: 'user1',
    name: 'Aspirin',
    dosage: '100mg',
    times: ['08:00'],
    startDate: DateTime.now(),
  );

  await provider.addMedication(medication);
  
  expect(provider.medications.length, 1);
  expect(provider.medications.first.name, 'Aspirin');
});
```

### Widget Test Example
```dart
testWidgets('MedicationsScreen displays medications', (WidgetTester tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(home: MedicationsScreen()),
    ),
  );

  expect(find.byType(ListView), findsOneWidget);
  expect(find.byType(MedicationCard), findsWidgets);
});
```

---

## Checklist for Adding a Feature

- [ ] Create model with @HiveType
- [ ] Add typeId to Hive type registry
- [ ] Add storage methods in StorageService
- [ ] Create provider extending ChangeNotifier
- [ ] Create UI screen with Consumer
- [ ] Add route in routes.dart
- [ ] Add provider to MultiProvider in main.dart
- [ ] Add navigation entry (BottomNavigationBar, menu, etc.)
- [ ] Run code generation: `flutter pub run build_runner build`
- [ ] Test on device
- [ ] Handle error cases
- [ ] Add documentation comments
- [ ] Write unit tests
- [ ] Write widget tests

---

## File Location Reference

```
lib/
├── models/
│   └── medication_model.dart      # Step 1
├── services/
│   └── storage_service.dart       # Step 2 (add methods)
├── providers/
│   └── medication_provider.dart   # Step 3
├── screens/main/
│   ├── medications_screen.dart    # Step 4
│   └── home_screen.dart           # Step 6 (update)
├── utils/
│   ├── routes.dart                # Step 5 (add route)
│   └── service_locator.dart       # Step 5 (update)
└── main.dart                       # Step 5 (add provider)
```

---

## Next Steps After Implementation

1. Run tests: `flutter test`
2. Test on device: `flutter run`
3. Check for warnings: Look at console for linter warnings
4. Profile performance: Check memory and CPU usage
5. Document your feature: Add comments and docstrings
6. Create demo/tutorial if needed
