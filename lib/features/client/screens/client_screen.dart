import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../shared/models/client.dart';
import '../../cashier/models/receipt.dart';
import '../../cashier/models/receipt_item.dart';
import '../../../services/client_window_service.dart';
import '../../../utils/formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/settings_notifier.dart';
import '../widgets/ad_banner.dart';

class ClientScreen extends ConsumerStatefulWidget {
  final Client? initialClient;
  final Receipt? initialReceipt;
  final int? targetUserId;

  const ClientScreen({
    super.key,
    this.initialClient,
    this.initialReceipt,
    this.targetUserId,
  });

  @override
  ConsumerState<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends ConsumerState<ClientScreen> {
  final ClientWindowService _service = ClientWindowService();
  Receipt? _receipt;
  Client? _client;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    if (kDebugMode) {
      print('🔴 ClientScreen: Инициализация сервиса');
    }
    
    // ВАЖНО: Сначала подписываемся на обновления, ПОТОМ инициализируем сервис
    // Это гарантирует, что callback установлен до того, как polling начнет работать
    _service.subscribe((receipt, client) {
      if (kDebugMode) {
        print('🔴 ClientScreen: 🔔🔔🔔 ПОЛУЧЕНО ОБНОВЛЕНИЕ! Receipt: ${receipt?.items.length ?? 0} товаров, Client: ${client?.name ?? "нет"}');
      }
      if (mounted) {
        if (kDebugMode) {
          print('🔴 ClientScreen: Widget mounted, обновляем State');
        }
        setState(() {
          _receipt = receipt;
          _client = client;
          if (kDebugMode) {
            print('🔴 ClientScreen: ✅✅✅ State обновлен! Receipt: ${_receipt?.items.length ?? 0} товаров');
          }
        });
      } else {
        if (kDebugMode) {
          print('🔴 ClientScreen: ⚠️ Widget не mounted, обновление пропущено');
        }
      }
    });
    
    // Теперь инициализируем сервис (запускает polling и загружает данные)
    // Callback уже установлен, поэтому polling сможет вызывать его при обнаружении изменений
    await _service.init();
    
    // Инициализируем из переданных данных или из сервиса
    _receipt = widget.initialReceipt ?? _service.currentReceipt;
    _client = widget.initialClient ?? _service.currentClient;

    if (kDebugMode) {
      print('🔴 ClientScreen: Данные загружены. Receipt: ${_receipt?.items.length ?? 0} товаров, Client: ${_client?.name ?? "нет"}');
    }
    
    // Обновляем UI с начальными данными
    if (mounted) {
      setState(() {
        // State уже установлен выше
      });
    }
  }

  @override
  void dispose() {
    _service.unsubscribe();
    // Не вызываем dispose() здесь, так как сервис singleton и может использоваться в других местах
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsStateProvider);
    final loc = ref.watch(appLocalizationsProvider);
    final pharmacyName = settingsAsync.maybeWhen(
      data: (settings) => settings.pharmacyName,
      orElse: () => loc.defaultPharmacyName,
    );
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _receipt == null || _receipt!.items.isEmpty
          ? _buildWelcomeScreen(pharmacyName)
          : Column(
              children: [
                // Заголовок
                _buildHeader(pharmacyName),
                // Основной контент
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Левая колонка - товары (70%)
                      Expanded(
                        flex: 70,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildReceiptTable(),
                        ),
                      ),
                      // Правая колонка - итоги и информация (30%)
                      Expanded(
                        flex: 30,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildSummaryPanel(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildWelcomeScreen(String pharmacyName) {
    return AdBanner(
      pharmacyName: pharmacyName,
      targetUserId: widget.targetUserId,
    );
  }
  
  Widget _buildHeader(String pharmacyName) {
    return Consumer(
      builder: (context, ref, child) {
        final loc = ref.watch(appLocalizationsProvider);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/img/logo.PNG',
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.local_pharmacy,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'libiss pos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      pharmacyName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                    ),
                    if (_client != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            loc.clientLabelWithName(_client!.name),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                      if (_client!.bonuses > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars, size: 14, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                Formatters.formatMoney(_client!.bonuses),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }
  
  Widget _buildReceiptTable() {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок таблицы
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    ref.watch(appLocalizationsProvider).number,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Text(
                    ref.watch(appLocalizationsProvider).productName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    ref.watch(appLocalizationsProvider).quantityShort,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    ref.watch(appLocalizationsProvider).price,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: Text(
                    ref.watch(appLocalizationsProvider).sum,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Список товаров
          Expanded(
            child: _receipt!.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          ref.watch(appLocalizationsProvider).receiptEmpty,
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _receipt!.items.length,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, thickness: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final item = _receipt!.items[index];
                      return _buildReceiptItemRow(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReceiptItemRow(ReceiptItem item, int index) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Номер
            SizedBox(
              width: 50,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.index}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Название
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.product.barcode.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ref.watch(appLocalizationsProvider).barcodeLabel(item.product.barcode),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Количество
            SizedBox(
              width: 140,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.blue[200]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  _formatQuantity(item),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Цена за упаковку
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Formatters.formatMoney(item.price),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    ref.watch(appLocalizationsProvider).perUnit(item.product.unit),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Сумма
            SizedBox(
              width: 130,
              child: Text(
                Formatters.formatMoney(item.total),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryPanel() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Итого к оплате
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).totalToPayLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.formatMoney(_receipt!.total),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Подытог
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).subtotalLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      Formatters.formatMoney(_receipt!.subtotal),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              
              // Скидка
              if (_receipt!.totalDiscount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _receipt!.discountIsPercent && _receipt!.discountPercent > 0
                            ? ref.watch(appLocalizationsProvider).discountWithPercent(_receipt!.discountPercent)
                            : ref.watch(appLocalizationsProvider).discountLabel,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        Formatters.formatMoney(_receipt!.totalDiscount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              
              // Бонусы
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ref.watch(appLocalizationsProvider).bonusesLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final settings = ref.watch(appSettingsStateProvider);
                        final bonusPercent = settings.maybeWhen(
                          data: (s) => s.bonusAccrualPercent,
                          orElse: () => 5.0,
                        );
                        final bonusPercentText = bonusPercent.toStringAsFixed(bonusPercent % 1 == 0 ? 0 : 2);
                        final accumulatedBonuses = _receipt!.clientId != null
                            ? _receipt!.total * (bonusPercent / 100)
                            : 0.0;
                        
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_receipt!.clientId != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '$bonusPercentText%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            Text(
                              _receipt!.bonuses > 0
                                  ? Formatters.formatBonuses(_receipt!.bonuses)
                                  : (_receipt!.clientId != null
                                      ? Formatters.formatBonuses(accumulatedBonuses)
                                      : ref.watch(appLocalizationsProvider).notAccrued),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _receipt!.bonuses > 0
                                    ? Colors.green
                                    : (_receipt!.clientId != null
                                          ? Colors.blue
                                          : Colors.grey[600]),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Благодарность
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite,
                      color: Colors.green[700],
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref.watch(appLocalizationsProvider).thankYouForPurchase,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ref.watch(appLocalizationsProvider).weValueYourChoice,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Логотип банка и QR код для оплаты
              Builder(
                builder: (context) {
                  final settings = ref.watch(appSettingsStateProvider);
                  return settings.maybeWhen(
                    data: (appSettings) {
                      // Показываем только если есть название банка, QR код или телефон
                      if ((appSettings.bankName == null ||
                              appSettings.bankName!.isEmpty) &&
                          (appSettings.bankQrCodePath == null ||
                              appSettings.bankQrCodePath!.isEmpty) &&
                          (appSettings.bankPhoneNumber == null ||
                              appSettings.bankPhoneNumber!.isEmpty)) {
                        return const SizedBox.shrink();
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Логотип банка
                            if (appSettings.bankName != null && appSettings.bankName!.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Логотип из файла, если есть
                                  if (appSettings.bankLogoPath != null && appSettings.bankLogoPath!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.file(
                                        File(appSettings.bankLogoPath!),
                                        height: 32,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.account_balance,
                                            color: Colors.blue[700],
                                            size: 24,
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.account_balance,
                                      color: Colors.blue[700],
                                      size: 24,
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      appSettings.bankName!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              'Для оплаты',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (appSettings.bankPhoneNumber != null &&
                                appSettings.bankPhoneNumber!.isNotEmpty) ...[
                              Text(
                                'Перевод по номеру телефона',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                appSettings.bankPhoneNumber!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // QR код (изображение)
                            if (appSettings.bankQrCodePath != null && appSettings.bankQrCodePath!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(appSettings.bankQrCodePath!),
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 150,
                                        height: 150,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.error, color: Colors.red),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: QrImageView(
                                  data: 'PAYMENT_${DateTime.now().millisecondsSinceEpoch}_${_receipt!.total.toStringAsFixed(2)}',
                                  version: QrVersions.auto,
                                  size: 150,
                                  backgroundColor: Colors.white,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Отсканируйте QR код\nдля оплаты',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              
              // Бонусы клиента (если есть)
              if (_client != null && _client!.bonuses > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.stars,
                        color: Colors.orange[700],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref.watch(appLocalizationsProvider).yourBonuses,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              Formatters.formatMoney(_client!.bonuses),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  

  String _formatQuantity(ReceiptItem item) {
    final packages = item.packages;
    final units = item.units;
    final unitName = item.product.unitName;

    if (packages >= 1 && units > 0) {
      final packagesInt = packages.toInt();
      return '$packagesInt ${item.product.unit} + $units $unitName';
    } else if (packages >= 1) {
      final packagesInt = packages.toInt();
      return '$packagesInt ${item.product.unit}';
    } else {
      return '${units} $unitName';
    }
  }
}
