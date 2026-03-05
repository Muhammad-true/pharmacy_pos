import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/auth_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/settings_notifier.dart';
import '../../../utils/formatters.dart';
import '../../../utils/qr_code_generator.dart';
import '../../shared/models/client.dart';

class AddClientDialog extends ConsumerStatefulWidget {
  final String? initialName;

  const AddClientDialog({super.key, this.initialName});

  @override
  ConsumerState<AddClientDialog> createState() => _AddClientDialogState();
}

class ClientCreatedDialog extends ConsumerWidget {
  final Client client;

  const ClientCreatedDialog({super.key, required this.client});

  Future<Uint8List> _buildClientPdf(
    BuildContext context,
    String pharmacyName,
  ) async {
    final logoData = await rootBundle.load('assets/img/logo.PNG');
    final logoBytes = logoData.buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(logoImage, width: 64, height: 64),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pharmacyName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'libiss pos',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'Больше возможностей',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Спасибо, что вы наш клиент!',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Имя: ${client.name}'),
              pw.Text('Телефон: ${client.phone ?? '-'}'),
              pw.Text('Бонусы: ${Formatters.formatBonuses(client.bonuses)}'),
              pw.SizedBox(height: 24),
              if (client.qrCode != null && client.qrCode!.isNotEmpty)
                pw.BarcodeWidget(
                  data: client.qrCode!,
                  barcode: pw.Barcode.qrCode(),
                  width: 140,
                  height: 140,
                ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Покажите этот QR-код при следующем визите',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsStateProvider);
    final pharmacyName = settings.maybeWhen(
      data: (s) => s.pharmacyName,
      orElse: () => 'Аптека',
    );

    return AlertDialog(
      title: const Text('Клиент создан'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/img/logo.PNG',
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'libiss pos',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const Text(
                        'Больше возможностей',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Спасибо, что вы наш клиент!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Имя: ${client.name}'),
                  Text('Телефон: ${client.phone ?? '-'}'),
                  Text('Бонусы: ${Formatters.formatBonuses(client.bonuses)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (client.qrCode != null && client.qrCode!.isNotEmpty)
              QrImageView(
                data: client.qrCode!,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              await Printing.layoutPdf(
                onLayout: (_) => _buildClientPdf(context, pharmacyName),
              );
            } on MissingPluginException {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Печать недоступна. Перезапустите приложение.'),
                  backgroundColor: Colors.orange,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка печати: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          icon: const Icon(Icons.print),
          label: const Text('Печать'),
        ),
      ],
    );
  }
}

class _AddClientDialogState extends ConsumerState<AddClientDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bonusesController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _bonusesFocus = FocusNode();

  bool _isLoading = false;
  FocusNode? _activeFocus;
  TextEditingController? _activeController;
  bool _shouldClearOnNextInput = false;
  String _valueWhenFocused = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.trim().isNotEmpty) {
      _nameController.text = widget.initialName!.trim();
    }
    // Устанавливаем фокус на поле телефона при открытии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bonusesController.dispose();
    _phoneFocus.dispose();
    _bonusesFocus.dispose();
    super.dispose();
  }

  void _onFieldFocusChanged(
    FocusNode? focus,
    TextEditingController? controller,
  ) {
    setState(() {
      _activeFocus = focus;
      _activeController = controller;
      if (focus != null && controller != null) {
        _shouldClearOnNextInput = true;
        _valueWhenFocused = controller.text;
      }
    });
  }

  void _handleKeypadKey(String key) {
    if (_activeController == null || _activeFocus == null) return;

    final currentValue = _activeController!.value;
    final currentText = currentValue.text;
    final selection = currentValue.selection;

    final cursorPosition = selection.isValid
        ? selection.start
        : currentText.length;
    final selectionStart = selection.isValid ? selection.start : cursorPosition;
    final selectionEnd = selection.isValid ? selection.end : cursorPosition;

    if (key == '.') {
      // Точка/запятая только для поля бонусов
      if (_bonusesFocus.hasFocus) {
        if (!currentText.contains('.') && !currentText.contains(',')) {
          final newText = currentText.isEmpty ? '0,' : currentText + ',';
          _activeController!.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          );
        }
      }
      // Для телефона точка не обрабатывается
    } else {
      // Добавляем символ
      final newText = currentText.isEmpty
          ? key
          : currentText.substring(0, selectionStart) +
                key +
                currentText.substring(selectionEnd);

      final newCursorPosition = selectionStart + 1;

      _activeController!.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );

      // Обрабатываем первый ввод
      if (_shouldClearOnNextInput && newText.isNotEmpty) {
        if (newText.startsWith(_valueWhenFocused) &&
            newText.length == _valueWhenFocused.length + 1) {
          final lastChar = newText[newText.length - 1];
          if (RegExp(r'^\d$').hasMatch(lastChar) && _bonusesFocus.hasFocus) {
            _activeController!.value = TextEditingValue(
              text: lastChar,
              selection: TextSelection.collapsed(offset: 1),
            );
            _shouldClearOnNextInput = false;
          }
        }
      }

      // Возвращаем фокус
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_activeFocus != null &&
            mounted &&
            _activeController != null &&
            _activeFocus!.hasFocus) {
          final textLength = _activeController!.text.length;
          _activeController!.selection = TextSelection.collapsed(
            offset: textLength,
          );
        }
      });
    }
  }

  void _handleKeypadBackspace() {
    if (_activeController == null) return;

    final currentValue = _activeController!.value;
    final currentText = currentValue.text;
    final selection = currentValue.selection;

    final cursorPosition = selection.isValid
        ? selection.start
        : currentText.length;
    final selectionStart = selection.isValid ? selection.start : cursorPosition;
    final selectionEnd = selection.isValid ? selection.end : cursorPosition;

    if (currentText.isNotEmpty && selectionStart > 0) {
      final newText =
          currentText.substring(0, selectionStart - 1) +
          currentText.substring(selectionEnd);
      final newCursorPosition = selectionStart - 1;

      _activeController!.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    } else if (currentText.isNotEmpty &&
        selectionStart == 0 &&
        selectionEnd > 0) {
      final newText = currentText.substring(selectionEnd);
      _activeController!.value = TextEditingValue(
        text: newText,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    // Возвращаем фокус
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_activeFocus != null &&
          mounted &&
          _activeController != null &&
          _activeFocus!.hasFocus) {
        final textLength = _activeController!.text.length;
        _activeController!.selection = TextSelection.collapsed(
          offset: textLength,
        );
      }
    });
  }

  Future<void> _createClient() async {
    // Валидация
    final nameInput = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      final loc = ref.watch(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.enterPhoneNumber),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Парсим бонусы
    final bonuses = _bonusesController.text.trim().isEmpty
        ? 0.0
        : (Formatters.parseNumber(_bonusesController.text.trim()) ?? 0.0);

    // Получаем текущего пользователя (кассира) - необязательно
    final currentUser = ref.read(authStateProvider);

    // Автоматически генерируем имя клиента
    final clientName = nameInput.isEmpty ? 'Новый клиент' : nameInput;

    setState(() {
      _isLoading = true;
    });

    try {
      // Генерируем QR код
      final qrCode = QrCodeGenerator.generateClientQrCodeFromData(
        name: clientName,
        phone: phone,
      );

      // Создаем клиента
      final client = Client(
        id: 0, // ID будет присвоен БД
        name: clientName,
        phone: phone,
        qrCode: qrCode,
        bonuses: bonuses,
        discountPercent: 0.0,
        createdByUserId: currentUser
            ?.id, // Может быть null, если пользователь не авторизован
        createdByUserName: currentUser?.name,
      );

      // Сохраняем в БД
      final clientRepository = ref.read(clientRepositoryProvider);
      final createdClient = await clientRepository.createClient(client);

      if (mounted) {
        // Показываем карточку клиента с QR и печатью
        await showDialog(
          context: context,
          builder: (context) => ClientCreatedDialog(client: createdClient),
        );

        // Возвращаем созданного клиента
        if (mounted) {
          Navigator.pop(context, createdClient);
        }
      }
    } on DatabaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = ref.watch(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.clientCreationError}: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final loc = ref.watch(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.clientCreationError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancel() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Заголовок
              Row(
                children: [
                  Icon(
                    Icons.person_add,
                    color: const Color(0xFF1976D2),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    ref.watch(appLocalizationsProvider).createNewClient,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Информация об автоматическом имени и накопительных баллах
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Если имя не указано, будет использовано "Новый клиент"',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final settings = ref.watch(appSettingsStateProvider);
                      final bonusPercent = settings.maybeWhen(
                        data: (s) => s.bonusAccrualPercent,
                        orElse: () => 5.0,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stars,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Процент накопительных баллов: ${bonusPercent.toStringAsFixed(bonusPercent % 1 == 0 ? 0 : 2)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Имя клиента (необязательно)
              TextField(
                controller: _nameController,
                keyboardType: TextInputType.text,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Имя клиента',
                  hintText: 'Введите имя (необязательно)',
                  prefixIcon: Icon(Icons.person, size: 24),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Номер телефона
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 16),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Номер телефона *',
                  hintText: '+996555123456',
                  prefixIcon: Icon(Icons.phone, size: 24),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onTap: () {
                  _onFieldFocusChanged(_phoneFocus, _phoneController);
                },
              ),
              const SizedBox(height: 16),

              // Бонусы
              TextField(
                controller: _bonusesController,
                focusNode: _bonusesFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 16),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Начальные бонусы',
                  hintText: '0',
                  prefixIcon: const Icon(Icons.stars, size: 24),
                  suffixText: 'с',
                  border: const OutlineInputBorder(),
                  helperText: 'Начальное количество бонусов для клиента',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onTap: () {
                  _onFieldFocusChanged(_bonusesFocus, _bonusesController);
                },
              ),
              const SizedBox(height: 20),

              // Информация о QR коде
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'QR код будет автоматически сгенерирован при создании клиента',
                        style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Цифровая клавиатура
              SizedBox(
                height: 340,
                child: _CompactNumericKeypad(
                  onKeyPressed: _handleKeypadKey,
                  onBackspace: _handleKeypadBackspace,
                ),
              ),
              const SizedBox(height: 20),

              // Кнопки
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _cancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      ref.watch(appLocalizationsProvider).cancel,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createClient,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 44),
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
                        : Text(
                            ref.watch(appLocalizationsProvider).createClient,
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Компактная версия цифровой клавиатуры для диалогов
class _CompactNumericKeypad extends StatelessWidget {
  final Function(String) onKeyPressed;
  final VoidCallback onBackspace;

  const _CompactNumericKeypad({
    required this.onKeyPressed,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const fontSize = 14.0;
    const spacing = 2.0;
    const borderRadius = 4.0;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.0,
        children: [
          _buildKey(
            '7',
            () => onKeyPressed('7'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '8',
            () => onKeyPressed('8'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '9',
            () => onKeyPressed('9'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '4',
            () => onKeyPressed('4'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '5',
            () => onKeyPressed('5'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '6',
            () => onKeyPressed('6'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '1',
            () => onKeyPressed('1'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '2',
            () => onKeyPressed('2'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '3',
            () => onKeyPressed('3'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '.',
            () => onKeyPressed('.'),
            fontSize: fontSize * 1.2,
            borderRadius: borderRadius,
            isSpecial: true,
          ),
          _buildKey(
            '0',
            () => onKeyPressed('0'),
            fontSize: fontSize,
            borderRadius: borderRadius,
          ),
          _buildKey(
            '⌫',
            onBackspace,
            color: const Color(0xFF1976D2),
            fontSize: fontSize * 1.1,
            borderRadius: borderRadius,
            isSpecial: true,
          ),
        ],
      ),
    );
  }

  Widget _buildKey(
    String label,
    VoidCallback onPressed, {
    Color? color,
    required double fontSize,
    required double borderRadius,
    bool isSpecial = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: color ?? Colors.white,
          border: Border.all(
            color: color != null ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSpecial ? FontWeight.w600 : FontWeight.bold,
              color: color != null ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
