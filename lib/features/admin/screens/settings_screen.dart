import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/settings_notifier.dart';
import '../../../services/backup_service.dart';
import '../../../services/telegram_export_service.dart';

class _DiscountRuleField {
  final TextEditingController minTotalController;
  final TextEditingController percentController;

  _DiscountRuleField({
    double? minTotal,
    double? percent,
  })  : minTotalController = TextEditingController(
          text: _formatValue(minTotal),
        ),
        percentController = TextEditingController(
          text: _formatValue(percent),
        );

  static String _formatValue(double? value) {
    if (value == null) return '';
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void dispose() {
    minTotalController.dispose();
    percentController.dispose();
  }
}

/// Экран настроек приложения
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyNameController = TextEditingController();
  final _bonusPercentController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankPhoneController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();
  String? _selectedLanguage;
  String? _selectedThemeMode;
  String? _selectedPrimaryColor;
  String? _bankLogoPath;
  String? _bankQrCodePath;
  bool _telegramAutoExportEnabled = false;
  bool _isLoading = false;
  final List<_DiscountRuleField> _discountRuleFields = [];

  final List<Map<String, String>> _languages = [
    {'code': 'ru', 'name': 'Русский'},
    {'code': 'uz', 'name': 'O\'zbek'},
    {'code': 'en', 'name': 'English'},
    {'code': 'tj', 'name': 'Тоҷикӣ'},
    {'code': 'kk', 'name': 'Қазақша'},
    {'code': 'ky', 'name': 'Кыргызча'},
  ];

  final List<Map<String, String>> _themeModes = [
    {'code': 'light', 'name': 'Светлая'},
    {'code': 'dark', 'name': 'Темная'},
    {'code': 'system', 'name': 'Системная'},
  ];

  final List<Map<String, String>> _primaryColors = [
    {'code': '#1976D2', 'name': 'Синий'},
    {'code': '#388E3C', 'name': 'Зеленый'},
    {'code': '#F57C00', 'name': 'Оранжевый'},
    {'code': '#7B1FA2', 'name': 'Фиолетовый'},
    {'code': '#C2185B', 'name': 'Розовый'},
    {'code': '#0288D1', 'name': 'Голубой'},
  ];

  void _initializeDiscountRuleFields(List<DiscountRule> rules) {
    for (final field in _discountRuleFields) {
      field.dispose();
    }
    _discountRuleFields.clear();
    if (rules.isEmpty) {
      _discountRuleFields.add(_DiscountRuleField());
    } else {
      for (final rule in rules) {
        _discountRuleFields.add(
          _DiscountRuleField(
            minTotal: rule.minTotal,
            percent: rule.percent,
          ),
        );
      }
    }
  }

  void _addDiscountRuleField() {
    setState(() {
      _discountRuleFields.add(_DiscountRuleField());
    });
  }

  void _removeDiscountRuleField(int index) {
    setState(() {
      final field = _discountRuleFields.removeAt(index);
      field.dispose();
    });
  }

  double? _tryParseNumber(String value) {
    final sanitized = value.trim().replaceAll(',', '.');
    return double.tryParse(sanitized);
  }

  List<DiscountRule> _collectDiscountRules() {
    final rules = <DiscountRule>[];
    for (final field in _discountRuleFields) {
      final amountText = field.minTotalController.text.trim();
      final percentText = field.percentController.text.trim();
      if (amountText.isEmpty || percentText.isEmpty) continue;

      final amount = _tryParseNumber(amountText);
      final percent = _tryParseNumber(percentText);
      if (amount == null || percent == null) continue;

      rules.add(
        DiscountRule(
          minTotal: amount,
          percent: percent,
        ),
      );
    }

    rules.sort((a, b) => a.minTotal.compareTo(b.minTotal));
    return rules;
  }

  Widget _buildDiscountRulesCard(AppLocalizations loc) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.discount_outlined, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  loc.autoDiscounts,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              loc.autoDiscountsDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_discountRuleFields.isEmpty)
              Text(
                loc.discountRulesEmpty,
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Column(
                children: List.generate(
                  _discountRuleFields.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _discountRuleFields.length - 1 ? 0 : 12,
                    ),
                    child: _buildDiscountRuleRow(index, loc),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addDiscountRuleField,
                icon: const Icon(Icons.add),
                label: Text(loc.addDiscountRule),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountRuleRow(int index, AppLocalizations loc) {
    final field = _discountRuleFields[index];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: field.minTotalController,
            decoration: InputDecoration(
              labelText: loc.minReceiptAmount,
              prefixIcon: const Icon(Icons.payments_outlined),
              hintText: '500',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (_discountRuleFields.isEmpty) {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return loc.enterReceiptAmount;
              }
              final parsed = _tryParseNumber(value);
              if (parsed == null || parsed <= 0) {
                return loc.enterReceiptAmount;
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: field.percentController,
            decoration: InputDecoration(
              labelText: loc.discountPercentShort,
              prefixIcon: const Icon(Icons.percent),
              suffixText: '%',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (_discountRuleFields.isEmpty) {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return loc.enterDiscountPercent;
              }
              final parsed = _tryParseNumber(value);
              if (parsed == null) {
                return loc.enterDiscountPercent;
              }
              if (parsed < 0 || parsed > 100) {
                return loc.discountPercentRangeError;
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: loc.delete,
          onPressed: () => _removeDiscountRuleField(index),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildBonusPercentCard(AppLocalizations loc) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.loyalty, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  loc.bonusAccrualTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              loc.bonusAccrualDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bonusPercentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: loc.bonusAccrualPercentLabel,
                suffixText: '%',
                prefixIcon: const Icon(Icons.percent),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final parsed = _tryParseNumber(value ?? '');
                if (parsed == null) {
                  return loc.enterBonusPercent;
                }
                if (parsed < 0 || parsed > 100) {
                  return loc.bonusPercentRangeError;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Настройки банка',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Настройте информацию о банке для отображения на экране клиента',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Название банка
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Название банка',
                hintText: 'Например: Душанбе Сити Банк',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bankPhoneController,
              decoration: const InputDecoration(
                labelText: 'Номер телефона для перевода',
                hintText: '+992 900 00 00',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            // Логотип банка
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _bankLogoPath ?? 'Логотип не выбран',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Путь к логотипу',
                      prefixIcon: Icon(Icons.image),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickBankLogo,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать'),
                ),
              ],
            ),
            if (_bankLogoPath != null && _bankLogoPath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_bankLogoPath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // QR код (изображение)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _bankQrCodePath ?? 'QR код не выбран',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Изображение QR кода',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickBankQrCode,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Выбрать'),
                ),
              ],
            ),
            if (_bankQrCodePath != null && _bankQrCodePath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_bankQrCodePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTelegramSettingsCard(AppLocalizations loc) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.send, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  loc.telegramSettings,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              loc.telegramSettingsDescription,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telegramBotTokenController,
              decoration: InputDecoration(
                labelText: loc.telegramBotToken,
                prefixIcon: const Icon(Icons.key),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telegramChatIdController,
              decoration: InputDecoration(
                labelText: loc.telegramChatId,
                prefixIcon: const Icon(Icons.chat),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _telegramAutoExportEnabled,
              onChanged: (value) {
                setState(() {
                  _telegramAutoExportEnabled = value;
                });
              },
              title: Text(loc.telegramAutoExport),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _exportToTelegram,
                  icon: const Icon(Icons.cloud_upload),
                  label: Text(loc.exportToTelegram),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _importFromFile,
                  icon: const Icon(Icons.cloud_download),
                  label: Text(loc.importFromFile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToTelegram() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final service = TelegramExportService(
        settingsRepository: ref.read(settingsRepositoryProvider),
      );
      await service.sendExportToTelegram();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.watch(appLocalizationsProvider).exportSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.watch(appLocalizationsProvider).error}: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importFromFile() async {
    final loc = ref.read(appLocalizationsProvider);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) {
      return;
    }

    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.importWarningTitle),
        content: Text(loc.importWarningText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.continueAction),
          ),
        ],
      ),
    );
    if (firstConfirm != true) return;

    final confirmController = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.importConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.importConfirmText),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                labelText: loc.typeConfirmWord,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.importFromFile),
          ),
        ],
      ),
    );
    if (secondConfirm != true) return;

    final confirmText = confirmController.text.trim();
    if (confirmText != loc.importConfirmWord) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.importConfirmMismatch),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final service = BackupService();
      await service.importFromJsonFile(File(result.files.single.path!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.importSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.error}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickBankLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _bankLogoPath = result.files.single.path!;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickBankQrCode() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _bankQrCodePath = result.files.single.path!;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _pharmacyNameController.dispose();
    _bonusPercentController.dispose();
    _bankNameController.dispose();
    _bankPhoneController.dispose();
    _telegramBotTokenController.dispose();
    _telegramChatIdController.dispose();
    for (final field in _discountRuleFields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settingsAsync = ref.read(appSettingsStateProvider);
    settingsAsync.whenData((settings) {
      setState(() {
        _pharmacyNameController.text = settings.pharmacyName;
        _selectedLanguage = settings.language;
        _selectedThemeMode = settings.themeMode;
        _selectedPrimaryColor = settings.primaryColor;
        _bonusPercentController.text =
            settings.bonusAccrualPercent.toStringAsFixed(
          settings.bonusAccrualPercent % 1 == 0 ? 0 : 2,
        );
        _bankNameController.text = settings.bankName ?? '';
        _bankLogoPath = settings.bankLogoPath;
        _bankQrCodePath = settings.bankQrCodePath;
        _bankPhoneController.text = settings.bankPhoneNumber ?? '';
        _telegramBotTokenController.text = settings.telegramBotToken ?? '';
        _telegramChatIdController.text = settings.telegramChatId ?? '';
        _telegramAutoExportEnabled = settings.telegramAutoExportEnabled;
        _initializeDiscountRuleFields(settings.discountRules);
      });
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final discountRules = _collectDiscountRules();
      final bonusPercent =
          _tryParseNumber(_bonusPercentController.text.trim()) ?? 5.0;
      final sanitizedBonusPercent =
          bonusPercent.clamp(0, 100).toDouble();

      final newSettings = AppSettings(
        pharmacyName: _pharmacyNameController.text.trim(),
        language: _selectedLanguage ?? 'ru',
        themeMode: _selectedThemeMode ?? 'light',
        primaryColor: _selectedPrimaryColor ?? '#1976D2',
        discountRules: discountRules,
        bonusAccrualPercent: sanitizedBonusPercent,
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        bankLogoPath: _bankLogoPath?.isEmpty ?? true ? null : _bankLogoPath,
        bankQrCodePath:
            _bankQrCodePath?.isEmpty ?? true ? null : _bankQrCodePath,
        bankPhoneNumber: _bankPhoneController.text.trim().isEmpty
            ? null
            : _bankPhoneController.text.trim(),
        telegramBotToken: _telegramBotTokenController.text.trim().isEmpty
            ? null
            : _telegramBotTokenController.text.trim(),
        telegramChatId: _telegramChatIdController.text.trim().isEmpty
            ? null
            : _telegramChatIdController.text.trim(),
        telegramAutoExportEnabled: _telegramAutoExportEnabled,
      );

      await ref
          .read(appSettingsStateProvider.notifier)
          .updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.watch(appLocalizationsProvider).saveSettings),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.instance.handleError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.watch(appLocalizationsProvider).error}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String colorCode) {
    try {
      return Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF1976D2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsStateProvider);

    return Scaffold(
      body: settingsAsync.when(
        data: (settings) {
          if (_selectedLanguage == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _pharmacyNameController.text = settings.pharmacyName;
                _selectedLanguage = settings.language;
                _selectedThemeMode = settings.themeMode;
                _selectedPrimaryColor = settings.primaryColor;
              });
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Text(
                    'Настройки приложения',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Управление основными настройками системы',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),

                  // Имя аптеки
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_pharmacy, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Имя аптеки',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pharmacyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Название аптеки',
                              hintText: 'Введите название аптеки',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите название аптеки';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildDiscountRulesCard(ref.watch(appLocalizationsProvider)),

                  const SizedBox(height: 24),

                  _buildBonusPercentCard(ref.watch(appLocalizationsProvider)),

                  const SizedBox(height: 24),

                  _buildBankSettingsCard(),

                  const SizedBox(height: 24),

                  _buildTelegramSettingsCard(
                    ref.watch(appLocalizationsProvider),
                  ),

                  // Язык
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.language, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Язык',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: _languages.map((lang) {
                              return ButtonSegment<String>(
                                value: lang['code']!,
                                label: Text(lang['name']!),
                              );
                            }).toList(),
                            selected: {_selectedLanguage ?? 'ru'},
                            onSelectionChanged: (Set<String> selected) {
                              setState(() {
                                _selectedLanguage = selected.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Тема
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.palette, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Тема',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: _themeModes.map((theme) {
                              return ButtonSegment<String>(
                                value: theme['code']!,
                                label: Text(theme['name']!),
                              );
                            }).toList(),
                            selected: {_selectedThemeMode ?? 'light'},
                            onSelectionChanged: (Set<String> selected) {
                              setState(() {
                                _selectedThemeMode = selected.first;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Основной цвет
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.color_lens, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Основной цвет',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _primaryColors.map((color) {
                              final isSelected =
                                  _selectedPrimaryColor == color['code'];
                              final colorValue = _parseColor(color['code']!);
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: colorValue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(color['name']!),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPrimaryColor = color['code'];
                                    });
                                  }
                                },
                                selectedColor: colorValue.withOpacity(0.2),
                                checkmarkColor: colorValue,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Кнопка сохранения
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Сохранить настройки',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки настроек',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(appSettingsStateProvider);
                },
                child: Text(ref.watch(appLocalizationsProvider).refresh),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
