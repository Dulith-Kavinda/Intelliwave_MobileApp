import 'package:get_it/get_it.dart';
import '../services/index.dart';
import '../services/image_upload_service.dart';
import '../services/ecg_inference_service.dart';
import '../providers/notification_provider.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Register services
  getIt.registerSingleton<StorageService>(StorageService());
  getIt.registerSingleton<AuthService>(AuthService());
  getIt.registerSingleton<BluetoothService>(BluetoothService());
  getIt.registerSingleton<NotificationService>(NotificationService());
  getIt.registerSingleton<UserProfileService>(UserProfileService());
  getIt.registerSingleton<ImageUploadService>(ImageUploadService());
  getIt.registerSingleton<EcgInferenceService>(EcgInferenceService());
  getIt.registerSingleton<NotificationProvider>(NotificationProvider(getIt<StorageService>()));
  getIt.registerSingleton<AiSummaryService>(
    AiSummaryService(
      getIt<StorageService>(),
      getIt<NotificationService>(),
    ),
  );
}

StorageService      get storageService      => getIt<StorageService>();
AuthService         get authService         => getIt<AuthService>();
BluetoothService    get bluetoothService    => getIt<BluetoothService>();
NotificationService get notificationService => getIt<NotificationService>();
UserProfileService  get userProfileService  => getIt<UserProfileService>();
ImageUploadService  get imageUploadService  => getIt<ImageUploadService>();
EcgInferenceService get ecgInferenceService => getIt<EcgInferenceService>();
NotificationProvider get notificationProvider => getIt<NotificationProvider>();
AiSummaryService    get aiSummaryService    => getIt<AiSummaryService>();
