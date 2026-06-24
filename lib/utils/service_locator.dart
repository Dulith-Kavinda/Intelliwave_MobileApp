import 'package:get_it/get_it.dart';
import '../services/index.dart';
import '../services/image_upload_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register services
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<AuthService>(AuthService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<NotificationService>(NotificationService());
  getIt.registerSingleton<UserProfileService>(UserProfileService());
  getIt.registerSingleton<ImageUploadService>(ImageUploadService());
}

StorageService get storageService => getIt<StorageService>();
AuthService get authService => getIt<AuthService>();
BluetoothService get bluetoothService => getIt<BluetoothService>();
NotificationService get notificationService => getIt<NotificationService>();
UserProfileService get userProfileService => getIt<UserProfileService>();
ImageUploadService get imageUploadService => getIt<ImageUploadService>();
