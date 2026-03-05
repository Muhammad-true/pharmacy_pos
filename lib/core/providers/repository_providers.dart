import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../di/dependency_injection.dart'
    show
        getProductRepository,
        getManufacturerRepository,
        getClientRepository,
        getReceiptRepository,
        getUserRepository,
        getAdvertisementRepository,
        getPurchaseRequestRepository,
        getSettingsRepository,
        getShiftRepository;
import '../repositories/i_product_repository.dart';
import '../repositories/i_manufacturer_repository.dart';
import '../repositories/i_client_repository.dart';
import '../repositories/i_receipt_repository.dart';
import '../repositories/i_user_repository.dart';
import '../repositories/i_advertisement_repository.dart';
import '../repositories/i_purchase_request_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/shift_repository.dart';

part 'repository_providers.g.dart';

/// Провайдер для репозитория товаров
@Riverpod(keepAlive: true)
IProductRepository productRepository(ProductRepositoryRef ref) {
  return getProductRepository();
}

/// Провайдер для репозитория производителей
@Riverpod(keepAlive: true)
IManufacturerRepository manufacturerRepository(ManufacturerRepositoryRef ref) {
  return getManufacturerRepository();
}

/// Провайдер для репозитория клиентов
@Riverpod(keepAlive: true)
IClientRepository clientRepository(ClientRepositoryRef ref) {
  return getClientRepository();
}

/// Провайдер для репозитория чеков
@Riverpod(keepAlive: true)
IReceiptRepository receiptRepository(ReceiptRepositoryRef ref) {
  return getReceiptRepository();
}

/// Провайдер для репозитория пользователей
@Riverpod(keepAlive: true)
IUserRepository userRepository(UserRepositoryRef ref) {
  return getUserRepository();
}

/// Провайдер для репозитория рекламы
@Riverpod(keepAlive: true)
IAdvertisementRepository advertisementRepository(AdvertisementRepositoryRef ref) {
  return getAdvertisementRepository();
}

/// Провайдер для репозитория заявок на закупку
@Riverpod(keepAlive: true)
IPurchaseRequestRepository purchaseRequestRepository(
  PurchaseRequestRepositoryRef ref,
) {
  return getPurchaseRequestRepository();
}

/// Провайдер для репозитория настроек
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(SettingsRepositoryRef ref) {
  return getSettingsRepository();
}

/// Провайдер для репозитория смен
@Riverpod(keepAlive: true)
ShiftRepository shiftRepository(ShiftRepositoryRef ref) {
  return getShiftRepository();
}

