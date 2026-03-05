import 'package:get_it/get_it.dart';
import '../repositories/i_product_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/i_manufacturer_repository.dart';
import '../repositories/manufacturer_repository.dart';
import '../repositories/i_client_repository.dart';
import '../repositories/client_repository.dart';
import '../repositories/i_receipt_repository.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/i_user_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/i_advertisement_repository.dart';
import '../repositories/advertisement_repository.dart';
import '../repositories/i_purchase_request_repository.dart';
import '../repositories/purchase_request_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/shift_repository.dart';

/// Dependency Injection контейнер
/// 
/// Использует get_it для управления зависимостями приложения
final getIt = GetIt.instance;

/// Инициализация Dependency Injection
/// 
/// Регистрирует все репозитории и сервисы как singleton
/// 
/// БД должна быть инициализирована до вызова этой функции
Future<void> setupDependencyInjection() async {
  // БД уже инициализирована в main.dart, регистрируем как factory
  // Репозитории сами получат БД через DatabaseProvider
  
  // Регистрируем репозитории
  getIt.registerLazySingleton<IProductRepository>(
    () => ProductRepository(),
  );

  getIt.registerLazySingleton<IManufacturerRepository>(
    () => ManufacturerRepository(),
  );

  getIt.registerLazySingleton<IClientRepository>(
    () => ClientRepository(),
  );

  getIt.registerLazySingleton<IReceiptRepository>(
    () => ReceiptRepository(),
  );

  getIt.registerLazySingleton<IUserRepository>(
    () => UserRepository(),
  );

  getIt.registerLazySingleton<IAdvertisementRepository>(
    () => AdvertisementRepository(),
  );

  getIt.registerLazySingleton<IPurchaseRequestRepository>(
    () => PurchaseRequestRepository(),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(),
  );

  getIt.registerLazySingleton<ShiftRepository>(
    () => ShiftRepository(),
  );
}

/// Получить репозиторий товаров
IProductRepository getProductRepository() => getIt<IProductRepository>();

/// Получить репозиторий производителей
IManufacturerRepository getManufacturerRepository() => getIt<IManufacturerRepository>();

/// Получить репозиторий клиентов
IClientRepository getClientRepository() => getIt<IClientRepository>();

/// Получить репозиторий чеков
IReceiptRepository getReceiptRepository() => getIt<IReceiptRepository>();

/// Получить репозиторий пользователей
IUserRepository getUserRepository() => getIt<IUserRepository>();

/// Получить репозиторий рекламы
IAdvertisementRepository getAdvertisementRepository() => getIt<IAdvertisementRepository>();

IPurchaseRequestRepository getPurchaseRequestRepository() =>
    getIt<IPurchaseRequestRepository>();

/// Получить репозиторий настроек
SettingsRepository getSettingsRepository() => getIt<SettingsRepository>();

ShiftRepository getShiftRepository() => getIt<ShiftRepository>();

