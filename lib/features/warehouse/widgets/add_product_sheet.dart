import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../features/shared/models/manufacturer.dart';
import '../../../utils/formatters.dart';
import '../../cashier/models/product.dart';
import '../models/warehouse_item.dart';

class AddProductResult {
  final WarehouseItem? item;

  const AddProductResult({required this.item});
}

class AddProductSheet extends ConsumerStatefulWidget {
  final List<String> organizations;

  const AddProductSheet({
    super.key,
    required this.organizations,
    required List manufacturers,
  });

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _qrCodeController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  final _unitsController = TextEditingController(text: '10');
  final _costController = TextEditingController(text: '5000');
  final _priceController = TextEditingController(text: '7000');
  final _newManufacturerController = TextEditingController();
  final _newOrganizationController = TextEditingController();
  final _shelfController = TextEditingController(text: 'A-01');
  final _compositionController = TextEditingController();
  final _indicationsController = TextEditingController();
  final _preparationMethodController = TextEditingController();

  DateTime? _expiryDate = DateTime.now().add(const Duration(days: 365));
  Manufacturer? _selectedManufacturer;
  String? _selectedOrganization;
  bool _requiresPrescription = false;
  bool _isLoadingManufacturers = true;
  List<Manufacturer> _manufacturers = [];
  Timer? _searchTimer;
  bool _isSearching = false;
  bool _isFormAutoFilled = false;
  List<Product> _searchResults = [];
  bool _showSearchResults = false;
  final FocusNode _nameFocus = FocusNode();
  bool _isSelectingProduct = false; // Флаг для предотвращения повторных кликов
  bool _isClearing =
      false; // Флаг для блокировки автоматического заполнения при очистке
  bool _isClosing = false; // Флаг для предотвращения повторных вызовов закрытия
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  // Сохраняем исходные значения перед автозаполнением

  bool get _isAddingNewManufacturer => _selectedManufacturer == null;
  bool get _isAddingNewOrganization =>
      widget.organizations.isEmpty || _selectedOrganization == '__org__';

  @override
  void initState() {
    super.initState();
    _selectedOrganization = widget.organizations.isNotEmpty
        ? widget.organizations.first
        : '__org__';
    _codeController.text = _generateInventoryCode();
    _loadManufacturers();

    // Добавляем слушатели для автозаполнения
    _nameController.addListener(_onNameOrBarcodeChanged);
    _barcodeController.addListener(_onNameOrBarcodeChanged);

    // Закрываем список результатов при потере фокуса
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && mounted) {
        // Небольшая задержка, чтобы дать время кликнуть на товар в списке
        // Не закрываем список, если идет процесс выбора товара
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_nameFocus.hasFocus && !_isSelectingProduct) {
            setState(() {
              _showSearchResults = false;
            });
          }
        });
      }
    });

    // Отслеживаем попытки закрытия через скролл
    _draggableController.addListener(() {
      if (!mounted || _isClosing) return;

      // Если размер стал меньше минимального (0.6), пользователь пытается закрыть
      final currentSize = _draggableController.size;
      const minSize = 0.6; // Минимальный размер из DraggableScrollableSheet

      // Предотвращаем закрытие, если есть данные
      if (_hasEnteredData() && currentSize < minSize) {
        // Немедленно возвращаем окно обратно к минимальному размеру
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _draggableController.size < minSize) {
            _draggableController.animateTo(
              minSize,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
            // Показываем диалог подтверждения
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted && !_isClosing) {
                _handleClose();
              }
            });
          }
        });
      }
    });
  }

  Future<void> _loadManufacturers() async {
    setState(() {
      _isLoadingManufacturers = true;
    });

    try {
      final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
      final manufacturers = await manufacturerRepo.getAllManufacturers();
      setState(() {
        _manufacturers = manufacturers;
        _isLoadingManufacturers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingManufacturers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки производителей: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  String _generateInventoryCode() {
    final ts = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'INV-${ts.toString().padLeft(5, '0')}';
  }

  /// Проверяет, есть ли введенные данные в форме
  bool _hasEnteredData() {
    // Проверяем основные поля
    if (_nameController.text.trim().isNotEmpty ||
        _codeController.text.trim().isNotEmpty ||
        _barcodeController.text.trim().isNotEmpty ||
        _qrCodeController.text.trim().isNotEmpty) {
      return true;
    }

    // Проверяем числовые поля (если изменены от значений по умолчанию)
    if (_quantityController.text.trim() != '10' ||
        _unitsController.text.trim() != '10' ||
        _costController.text.trim() != '5000' ||
        _priceController.text.trim() != '7000' ||
        _shelfController.text.trim() != 'A-01') {
      return true;
    }

    // Проверяем медицинскую информацию
    if (_compositionController.text.trim().isNotEmpty ||
        _indicationsController.text.trim().isNotEmpty ||
        _preparationMethodController.text.trim().isNotEmpty ||
        _requiresPrescription) {
      return true;
    }

    // Проверяем производителя и организацию
    if (_selectedManufacturer != null) {
      return true;
    }

    final defaultOrg = widget.organizations.isNotEmpty
        ? widget.organizations.first
        : '__org__';
    if (_selectedOrganization != null &&
        _selectedOrganization != '__org__' &&
        _selectedOrganization != defaultOrg) {
      return true;
    }

    // Проверяем, была ли форма автозаполнена
    if (_isFormAutoFilled) {
      return true;
    }

    return false;
  }

  /// Показывает диалог подтверждения закрытия
  Future<bool> _confirmClose() async {
    if (!_hasEnteredData()) {
      return true; // Нет данных, можно закрывать без подтверждения
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть форму?'),
        content: const Text(
          'В форме есть введенные данные. Вы уверены, что хотите закрыть? Все данные будут потеряны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Обработчик закрытия окна
  Future<void> _handleClose() async {
    // Предотвращаем повторные вызовы
    if (_isClosing || !mounted) return;

    _isClosing = true;
    try {
      final shouldClose = await _confirmClose();
      if (shouldClose && mounted) {
        Navigator.pop(context, const AddProductResult(item: null));
      }
    } finally {
      if (mounted) {
        _isClosing = false;
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _nameController.removeListener(_onNameOrBarcodeChanged);
    _barcodeController.removeListener(_onNameOrBarcodeChanged);
    _draggableController.dispose();
    _nameFocus.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _barcodeController.dispose();
    _qrCodeController.dispose();
    _quantityController.dispose();
    _unitsController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _newManufacturerController.dispose();
    _newOrganizationController.dispose();
    _shelfController.dispose();
    _compositionController.dispose();
    _indicationsController.dispose();
    _preparationMethodController.dispose();
    super.dispose();
  }

  void _onNameOrBarcodeChanged() {
    // Если идет процесс очистки, не обрабатываем изменения
    if (_isClearing) return;

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();

    // Сбрасываем флаг автозаполнения при любом изменении текста
    // Это позволяет пользователю свободно редактировать поле после выбора товара
    if (_isFormAutoFilled) {
      setState(() {
        _isFormAutoFilled = false;
        _showSearchResults = false;
        _searchResults.clear();
      });
    }

    // Отменяем предыдущий поиск
    _searchTimer?.cancel();

    // Если оба поля пустые, скрываем результаты и отменяем все поиски
    if (name.isEmpty && barcode.isEmpty) {
      _searchTimer?.cancel();
      _searchTimer = null;
      setState(() {
        _showSearchResults = false;
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    // Запускаем поиск с задержкой (debounce) только если есть текст для поиска
    if (name.isNotEmpty || barcode.isNotEmpty) {
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        if (!_isClearing) {
          _searchProducts(name, barcode);
        }
      });
    }
  }

  Future<void> _searchProducts(String name, String barcode) async {
    if (!mounted || _isClearing) return;

    // Проверяем, что поля все еще содержат текст для поиска
    final currentName = _nameController.text.trim();
    final currentBarcode = _barcodeController.text.trim();
    if (currentName.isEmpty && currentBarcode.isEmpty) {
      // Если поля пустые, не запускаем поиск
      if (mounted) {
        setState(() {
          _isSearching = false;
          _showSearchResults = false;
        });
      }
      return;
    }

    if (!mounted || _isClearing) return;

    setState(() {
      _isSearching = true;
      _showSearchResults = false;
    });

    try {
      final productRepo = ref.read(productRepositoryProvider);
      List<Product> results = [];

      // Если есть штрих-код, ищем точное совпадение
      if (barcode.isNotEmpty) {
        final product = await productRepo.getProductByBarcode(barcode);
        if (!mounted) {
          return; // Виджет размонтирован, выходим
        }
        if (product != null && !_isClearing) {
          // Если нашли точное совпадение по штрих-коду, сразу заполняем
          // Но только если не идет процесс очистки
          await _fillFormWithProduct(product);
          if (mounted && !_isClearing) {
            setState(() {
              _isFormAutoFilled = true;
              _isSearching = false;
              _showSearchResults = false;
              _searchResults.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Товар "${product.name}" найден. Форма заполнена автоматически.',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      // Если есть название, ищем товары, начинающиеся с введенного текста
      if (name.isNotEmpty) {
        final allProducts = await productRepo.searchProducts(name);
        if (!mounted) {
          return; // Виджет размонтирован, выходим
        }
        // Фильтруем товары, которые начинаются с введенного текста
        results = allProducts
            .where(
              (product) =>
                  product.name.toLowerCase().startsWith(name.toLowerCase()),
            )
            .take(10) // Ограничиваем до 10 результатов
            .toList();
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _showSearchResults = results.isNotEmpty && name.isNotEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      // Гарантируем, что индикатор всегда сбрасывается при ошибке
      if (mounted) {
        setState(() {
          _isSearching = false;
          _showSearchResults = false;
        });
      }
      print('Ошибка поиска товаров: $e');
    } finally {
      // Дополнительная гарантия сброса индикатора
      if (mounted && _isSearching) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectProductFromSearch(Product product) async {
    // Предотвращаем повторные клики
    // Флаг уже должен быть установлен в onTapDown, но проверяем на всякий случай
    if (!mounted) return;

    // Если флаг не установлен (например, вызов не из клика), устанавливаем его
    if (!_isSelectingProduct) {
      _isSelectingProduct = true;
    }

    try {
      // Сразу закрываем список результатов, чтобы избежать повторных кликов
      setState(() {
        _showSearchResults = false;
        _searchResults.clear();
      });

      // Убеждаемся, что список производителей загружен
      if (_isLoadingManufacturers) {
        await _loadManufacturers();
      }

      if (!mounted) return;

      // Заполняем форму
      await _fillFormWithProduct(product);

      if (!mounted) return;

      // Устанавливаем флаг автозаполнения после заполнения формы
      setState(() {
        _isFormAutoFilled = true;
      });

      // Убираем фокус с поля поиска с небольшой задержкой
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _nameFocus.unfocus();
        }
      });

      // Показываем уведомление
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Товар "${product.name}" выбран. Форма заполнена автоматически.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // Сбрасываем флаг после завершения
      if (mounted) {
        _isSelectingProduct = false;
      }
    }
  }

  /// Закрывает список результатов поиска
  void _closeSearchResults() {
    setState(() {
      _showSearchResults = false;
      _searchResults.clear();
    });
  }

  /// Очищает выбранный товар и полностью очищает форму
  void _clearSelectedProduct() {
    if (!mounted) return;

    // Устанавливаем флаг очистки, чтобы блокировать автоматическое заполнение
    _isClearing = true;

    // Отменяем поиск, если он идет
    _searchTimer?.cancel();
    _searchTimer = null;

    // Временно отключаем слушатели, чтобы не запускать поиск при очистке
    _nameController.removeListener(_onNameOrBarcodeChanged);
    _barcodeController.removeListener(_onNameOrBarcodeChanged);

    // Сначала сбрасываем все флаги, чтобы индикатор исчез сразу
    setState(() {
      _isFormAutoFilled = false;
      _isSearching = false;
      _showSearchResults = false;
      _searchResults.clear();
    });

    // Очищаем все поля сразу, чтобы они исчезли мгновенно
    _nameController.text = '';
    _barcodeController.text = '';
    _qrCodeController.text = '';
    _codeController.text = _generateInventoryCode();
    _shelfController.text = 'A-01';
    _quantityController.text = '10';
    _unitsController.text = '';
    _costController.text = '5000';
    _priceController.text = '';
    _compositionController.text = '';
    _indicationsController.text = '';
    _preparationMethodController.text = '';
    _newOrganizationController.text = '';
    _newManufacturerController.text = '';

    // Сбрасываем остальные флаги и значения
    setState(() {
      _selectedManufacturer = null;
      _selectedOrganization = null;
      _requiresPrescription = false;
      _expiryDate = DateTime.now().add(const Duration(days: 365));
    });

    // Очищаем сохраненные исходные значения

    // Возвращаем слушатели с задержкой, чтобы не запустить поиск сразу
    // Используем WidgetsBinding для гарантии, что все обновления UI завершены
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Проверяем, что поля все еще пустые перед возвратом слушателей
          // И что флаг автозаполнения не был установлен заново
          if (_nameController.text.isEmpty &&
              _barcodeController.text.isEmpty &&
              !_isFormAutoFilled) {
            _nameController.addListener(_onNameOrBarcodeChanged);
            _barcodeController.addListener(_onNameOrBarcodeChanged);
            // Устанавливаем фокус на поле, чтобы пользователь мог сразу вводить
            _nameFocus.requestFocus();
          }
          // Сбрасываем флаг очистки после возврата слушателей
          _isClearing = false;
        }
      });
    });
  }

  Future<void> _fillFormWithProduct(Product product) async {
    // Временно отключаем слушатели, чтобы не запускать поиск при заполнении
    _nameController.removeListener(_onNameOrBarcodeChanged);
    _barcodeController.removeListener(_onNameOrBarcodeChanged);

    // Сохраняем исходные значения перед автозаполнением

    // Заполняем основные поля
    // Используем прямое присваивание текста
    _nameController.text = product.name;
    _barcodeController.text = product.barcode;
    if (product.qrCode != null && product.qrCode!.isNotEmpty) {
      _qrCodeController.text = product.qrCode!;
    }
    _codeController.text = product.inventoryCode ?? _generateInventoryCode();
    _shelfController.text = product.shelfLocation ?? 'A-01';

    // Заполняем количество и единицы
    _quantityController.text = '10'; // По умолчанию 10 упаковок
    _unitsController.text = product.unitsPerPackage.toString();

    // Заполняем цену (себестоимость оставляем пустой или можно взять из product)
    _priceController.text = product.price.toStringAsFixed(0);
    _costController.text = '5000'; // По умолчанию

    // Заполняем медицинскую информацию
    if (product.composition != null && product.composition!.isNotEmpty) {
      _compositionController.text = product.composition!;
    }
    if (product.indications != null && product.indications!.isNotEmpty) {
      _indicationsController.text = product.indications!;
    }
    if (product.preparationMethod != null &&
        product.preparationMethod!.isNotEmpty) {
      _preparationMethodController.text = product.preparationMethod!;
    }

    _requiresPrescription = product.requiresPrescription;

    // Заполняем производителя
    if (product.manufacturerId != null) {
      try {
        // Сначала ищем производителя в уже загруженном списке
        Manufacturer? foundManufacturer = _manufacturers.firstWhere(
          (m) => m.id == product.manufacturerId,
          orElse: () => throw StateError('Not found'),
        );

        // Если нашли в списке, используем его
        setState(() {
          _selectedManufacturer = foundManufacturer;
        });
      } catch (e) {
        // Если не нашли в списке, загружаем из БД и добавляем в список
        try {
          final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
          final manufacturer = await manufacturerRepo.getManufacturerById(
            product.manufacturerId!,
          );
          if (manufacturer != null) {
            // Проверяем, нет ли уже такого производителя в списке
            final existingIndex = _manufacturers.indexWhere(
              (m) => m.id == manufacturer.id,
            );
            if (existingIndex >= 0) {
              // Используем существующий из списка
              setState(() {
                _selectedManufacturer = _manufacturers[existingIndex];
              });
            } else {
              // Добавляем в список и используем
              setState(() {
                _manufacturers.add(manufacturer);
                _selectedManufacturer = manufacturer;
              });
            }
          }
        } catch (e2) {
          print('Ошибка загрузки производителя: $e2');
        }
      }
    }

    // Заполняем организацию
    if (product.organization != null && product.organization!.isNotEmpty) {
      if (widget.organizations.contains(product.organization)) {
        setState(() {
          _selectedOrganization = product.organization;
        });
      } else {
        // Если организации нет в списке, добавляем её
        setState(() {
          _selectedOrganization = '__org__';
          _newOrganizationController.text = product.organization!;
        });
      }
    }

    // Возвращаем слушатели с задержкой, чтобы не запускать поиск сразу
    // Используем WidgetsBinding для гарантии, что все обновления UI завершены
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _nameController.addListener(_onNameOrBarcodeChanged);
          _barcodeController.addListener(_onNameOrBarcodeChanged);
        }
      });
    });
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 365)),
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Выберите срок годности',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1976D2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Получаем или создаем производителя
    Manufacturer? manufacturer;
    String manufacturerName;

    if (_isAddingNewManufacturer) {
      manufacturerName = _newManufacturerController.text.trim();
      if (manufacturerName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите фирму-производителя')),
        );
        return;
      }

      try {
        final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
        // Проверяем, существует ли производитель
        manufacturer = await manufacturerRepo.getManufacturerByName(
          manufacturerName,
        );
        manufacturer ??= await manufacturerRepo.createManufacturer(
          Manufacturer(id: 0, name: manufacturerName),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания производителя: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      manufacturer = _selectedManufacturer;
      manufacturerName = manufacturer?.name ?? '';
    }

    if (manufacturer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите фирму-производителя')),
      );
      return;
    }

    final organization = _isAddingNewOrganization
        ? _newOrganizationController.text.trim()
        : (_selectedOrganization ?? '');

    if (organization.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите организацию хранения')),
      );
      return;
    }

    final quantity = int.parse(_quantityController.text.trim());
    final unitsPerPackage = int.parse(_unitsController.text.trim());
    final costPrice = double.parse(_costController.text.trim());
    final sellingPrice = double.parse(_priceController.text.trim());
    final barcode = _barcodeController.text.trim().isEmpty
        ? 'GEN-${DateTime.now().millisecondsSinceEpoch}'
        : _barcodeController.text.trim();
    final qrCode = _qrCodeController.text.trim().isEmpty
        ? null
        : _qrCodeController.text.trim();
    final composition = _compositionController.text.trim().isEmpty
        ? null
        : _compositionController.text.trim();
    final indications = _indicationsController.text.trim().isEmpty
        ? null
        : _indicationsController.text.trim();
    final preparationMethod = _preparationMethodController.text.trim().isEmpty
        ? null
        : _preparationMethodController.text.trim();

    // ID будет присвоен БД при создании
    final product = Product(
      id: 0, // ID будет присвоен БД
      name: _nameController.text.trim(),
      barcode: barcode,
      qrCode: qrCode,
      price: sellingPrice,
      stock: quantity,
      unit: 'упаковка',
      unitsPerPackage: unitsPerPackage,
      unitName: 'таблетка',
      manufacturerId: manufacturer.id,
      composition: composition,
      indications: indications,
      preparationMethod: preparationMethod,
      requiresPrescription: _requiresPrescription,
      inventoryCode: _codeController.text.trim().isEmpty
          ? _generateInventoryCode()
          : _codeController.text.trim(),
      organization: organization,
      shelfLocation: _shelfController.text.trim(),
    );

    final item = WarehouseItem(
      product: product,
      manufacturer: manufacturerName,
      organization: organization,
      inventoryCode: _codeController.text.trim().isEmpty
          ? _generateInventoryCode()
          : _codeController.text.trim(),
      shelfLocation: _shelfController.text.trim(),
      quantity: quantity,
      totalUnits: quantity * unitsPerPackage,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      lastReceived: DateTime.now(),
      lastSold: null,
      expiryDate: _expiryDate,
    );

    if (mounted) {
      Navigator.pop(context, AddProductResult(item: item));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isClosing && mounted) {
          // Предотвращаем повторные вызовы
          _isClosing = true;
          try {
            final shouldClose = await _confirmClose();
            if (shouldClose && mounted) {
              Navigator.pop(context, const AddProductResult(item: null));
            }
          } finally {
            if (mounted) {
              _isClosing = false;
            }
          }
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: Colors.transparent,
          child: DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.85,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            snap: false, // Отключаем автоматическое закрытие при скролле
            builder: (context, controller) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: EdgeInsets.only(bottom: viewInsets),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Добавить товар',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _handleClose,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _SectionCard(
                                title: 'Основная информация',
                                child: Column(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: _nameController,
                                          focusNode: _nameFocus,
                                          enabled: true,
                                          readOnly: false,
                                          decoration: InputDecoration(
                                            labelText: 'Название товара',
                                            prefixIcon: const Icon(
                                              Icons.medication_liquid_outlined,
                                            ),
                                            suffixIcon: _isSearching
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: Padding(
                                                      padding: EdgeInsets.all(
                                                        12.0,
                                                      ),
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    ),
                                                  )
                                                : _isFormAutoFilled
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.grey,
                                                      size: 20,
                                                    ),
                                                    tooltip:
                                                        'Очистить выбранный товар',
                                                    onPressed:
                                                        _clearSelectedProduct,
                                                  )
                                                : null,
                                            helperText: _isFormAutoFilled
                                                ? 'Форма заполнена автоматически. Вы можете изменить или стереть название.'
                                                : 'Начните вводить название для поиска товаров',
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          onChanged: (value) {
                                            // Явно обрабатываем изменения, чтобы поле всегда было редактируемым
                                            // Слушатель _onNameOrBarcodeChanged уже обработает это
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Введите название';
                                            }
                                            return null;
                                          },
                                        ),
                                        // Список результатов поиска
                                        if (_showSearchResults &&
                                            _searchResults.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            constraints: const BoxConstraints(
                                              maxHeight: 250,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Заголовок с кнопкой закрытия
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 8,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Найдено товаров: ${_searchResults.length}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Colors.grey[700],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                          color: Colors.grey,
                                                        ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        constraints:
                                                            const BoxConstraints(),
                                                        tooltip:
                                                            'Закрыть список',
                                                        onPressed:
                                                            _closeSearchResults,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Divider(height: 1),
                                                // Список товаров
                                                Flexible(
                                                  child: ListView.separated(
                                                    shrinkWrap: true,
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    itemCount:
                                                        _searchResults.length,
                                                    separatorBuilder: (_, __) =>
                                                        const Divider(
                                                          height: 1,
                                                        ),
                                                    itemBuilder: (context, index) {
                                                      final product =
                                                          _searchResults[index];
                                                      return GestureDetector(
                                                        onTapDown: (_) {
                                                          // Устанавливаем флаг сразу при нажатии,
                                                          // чтобы предотвратить закрытие списка
                                                          if (!_isSelectingProduct) {
                                                            _isSelectingProduct =
                                                                true;
                                                          }
                                                        },
                                                        onTapCancel: () {
                                                          // Сбрасываем флаг, если действие отменено
                                                          if (mounted) {
                                                            _isSelectingProduct =
                                                                false;
                                                          }
                                                        },
                                                        child: ListTile(
                                                          dense: true,
                                                          leading: const Icon(
                                                            Icons
                                                                .medication_liquid,
                                                            color: Colors.blue,
                                                          ),
                                                          title: Text(
                                                            product.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                          subtitle:
                                                              product
                                                                  .barcode
                                                                  .isNotEmpty
                                                              ? Text(
                                                                  'Штрих-код: ${product.barcode}',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .grey[600],
                                                                  ),
                                                                )
                                                              : null,
                                                          trailing: const Icon(
                                                            Icons
                                                                .arrow_forward_ios,
                                                            size: 16,
                                                            color: Colors.grey,
                                                          ),
                                                          onTap: () {
                                                            // Выбираем товар (флаг уже установлен в onTapDown)
                                                            if (mounted) {
                                                              _selectProductFromSearch(
                                                                product,
                                                              );
                                                            }
                                                          },
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _codeController,
                                      decoration: const InputDecoration(
                                        labelText: 'Код товара',
                                        helperText: 'Например: 201-Парацетамол',
                                        prefixIcon: Icon(Icons.tag_outlined),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Введите код товара';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _ManufacturerField(
                                      manufacturers: _manufacturers,
                                      selectedManufacturer:
                                          _selectedManufacturer,
                                      isAddingNewManufacturer:
                                          _isAddingNewManufacturer,
                                      isLoading: _isLoadingManufacturers,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedManufacturer = value;
                                        });
                                      },
                                      newManufacturerController:
                                          _newManufacturerController,
                                    ),
                                    const SizedBox(height: 12),
                                    _OrganizationField(
                                      organizations: widget.organizations,
                                      selectedOrganization:
                                          _selectedOrganization,
                                      isAddingNewOrganization:
                                          _isAddingNewOrganization,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedOrganization = value;
                                        });
                                      },
                                      newOrganizationController:
                                          _newOrganizationController,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _shelfController,
                                      decoration: const InputDecoration(
                                        labelText: 'Полка / расположение',
                                        hintText: 'Например: A-01 или C-12-03',
                                        prefixIcon: Icon(
                                          Icons.storage_outlined,
                                        ),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Укажите полку';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Продажи и упаковка',
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _barcodeController,
                                      decoration: InputDecoration(
                                        labelText: 'Штрих-код',
                                        hintText:
                                            'Можно оставить пустым — сгенерируется автоматически',
                                        prefixIcon: const Icon(Icons.qr_code_2),
                                        helperText:
                                            'Введите штрих-код для поиска существующего товара',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _qrCodeController,
                                      decoration: const InputDecoration(
                                        labelText: 'QR-код',
                                        hintText: 'Опционально',
                                        prefixIcon: Icon(Icons.qr_code_scanner),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _quantityController,
                                            decoration: const InputDecoration(
                                              labelText: 'Количество упаковок',
                                              prefixIcon: Icon(
                                                Icons.inventory_2_outlined,
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator: (value) {
                                              final intValue = int.tryParse(
                                                value ?? '',
                                              );
                                              if (intValue == null ||
                                                  intValue <= 0) {
                                                return 'Введите количество';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _unitsController,
                                            decoration: const InputDecoration(
                                              labelText: 'Таблеток в упаковке',
                                              prefixIcon: Icon(
                                                Icons.medication_outlined,
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator: (value) {
                                              final intValue = int.tryParse(
                                                value ?? '',
                                              );
                                              if (intValue == null ||
                                                  intValue <= 0) {
                                                return 'Введите число';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Финансы',
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _costController,
                                            decoration: const InputDecoration(
                                              labelText: 'Себестоимость, сум',
                                              prefixIcon: Icon(
                                                Icons.payments_outlined,
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator: (value) {
                                              final doubleValue =
                                                  double.tryParse(value ?? '');
                                              if (doubleValue == null ||
                                                  doubleValue <= 0) {
                                                return 'Введите себестоимость';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _priceController,
                                            decoration: const InputDecoration(
                                              labelText: 'Цена продажи, сум',
                                              prefixIcon: Icon(
                                                Icons.sell_outlined,
                                              ),
                                            ),
                                            keyboardType: TextInputType.number,
                                            validator: (value) {
                                              final doubleValue =
                                                  double.tryParse(value ?? '');
                                              if (doubleValue == null ||
                                                  doubleValue <= 0) {
                                                return 'Введите цену';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Медицинская информация',
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _compositionController,
                                      decoration: const InputDecoration(
                                        labelText: 'Состав',
                                        hintText:
                                            'Активные вещества и вспомогательные компоненты',
                                        prefixIcon: Icon(
                                          Icons.science_outlined,
                                        ),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLines: 3,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _indicationsController,
                                      decoration: const InputDecoration(
                                        labelText: 'Показания к применению',
                                        hintText:
                                            'При каких заболеваниях/симптомах применяется',
                                        prefixIcon: Icon(
                                          Icons.medical_services_outlined,
                                        ),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLines: 3,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _preparationMethodController,
                                      decoration: const InputDecoration(
                                        labelText: 'Способ применения',
                                        hintText: 'Как принимать препарат',
                                        prefixIcon: Icon(
                                          Icons.medication_liquid_outlined,
                                        ),
                                        alignLabelWithHint: true,
                                      ),
                                      maxLines: 3,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                    ),
                                    const SizedBox(height: 12),
                                    CheckboxListTile(
                                      title: const Text(
                                        'Требуется рецепт врача',
                                      ),
                                      subtitle: const Text(
                                        'Препарат отпускается только по рецепту',
                                      ),
                                      value: _requiresPrescription,
                                      onChanged: (value) {
                                        setState(() {
                                          _requiresPrescription =
                                              value ?? false;
                                        });
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _SectionCard(
                                title: 'Срок годности',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Дата истечения',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _expiryDate != null
                                                    ? Formatters.formatDate(
                                                        _expiryDate!,
                                                      )
                                                    : 'Не выбрана',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          ElevatedButton.icon(
                                            onPressed: _pickExpiryDate,
                                            icon: const Icon(Icons.event),
                                            label: const Text('Выбрать'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          _expiryDate != null &&
                                                  _expiryDate!.isBefore(
                                                    DateTime.now(),
                                                  )
                                              ? Icons.error_outline
                                              : Icons.info_outline,
                                          color:
                                              _expiryDate != null &&
                                                  _expiryDate!.isBefore(
                                                    DateTime.now(),
                                                  )
                                              ? Colors.red
                                              : Colors.blueGrey,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _expiryDate != null
                                                ? 'В избежание просрочки контролируйте остатки за 30 дней до истечения.'
                                                : 'Рекомендуем указать срок годности для отслеживания партии.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blueGrey[600],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ).copyWith(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _handleClose,
                                child: const Text('Отмена'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoadingManufacturers
                                    ? null
                                    : _submit,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: _isLoadingManufacturers
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Сохранить товар'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ManufacturerField extends StatelessWidget {
  final List<Manufacturer> manufacturers;
  final Manufacturer? selectedManufacturer;
  final bool isAddingNewManufacturer;
  final bool isLoading;
  final ValueChanged<Manufacturer?> onChanged;
  final TextEditingController newManufacturerController;

  const _ManufacturerField({
    required this.manufacturers,
    required this.selectedManufacturer,
    required this.isAddingNewManufacturer,
    required this.isLoading,
    required this.onChanged,
    required this.newManufacturerController,
  });

  @override
  Widget build(BuildContext context) {
    // Находим производителя в списке по ID, если он установлен
    // Это нужно, чтобы объект из списка совпадал по ссылке с value
    Manufacturer? validSelectedManufacturer;
    if (selectedManufacturer != null && manufacturers.isNotEmpty) {
      try {
        validSelectedManufacturer = manufacturers.firstWhere(
          (m) => m.id == selectedManufacturer!.id,
        );
      } catch (e) {
        // Если не найден в списке, используем null
        validSelectedManufacturer = null;
      }
    }

    return Column(
      children: [
        if (isLoading)
          const LinearProgressIndicator()
        else
          DropdownButtonFormField<Manufacturer?>(
            value: validSelectedManufacturer,
            items: [
              for (final manufacturer in manufacturers)
                DropdownMenuItem<Manufacturer>(
                  value: manufacturer,
                  child: Text(manufacturer.name),
                ),
              const DropdownMenuItem<Manufacturer?>(
                value: null,
                child: Text('Добавить новую фирму...'),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Фирма-производитель',
              prefixIcon: Icon(Icons.factory_outlined),
            ),
            onChanged: onChanged,
          ),
        if (isAddingNewManufacturer) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: newManufacturerController,
            decoration: const InputDecoration(
              labelText: 'Название новой фирмы',
              prefixIcon: Icon(Icons.add_business_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите название фирмы';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}

class _OrganizationField extends StatelessWidget {
  final List<String> organizations;
  final String? selectedOrganization;
  final bool isAddingNewOrganization;
  final ValueChanged<String?> onChanged;
  final TextEditingController newOrganizationController;

  const _OrganizationField({
    required this.organizations,
    required this.selectedOrganization,
    required this.isAddingNewOrganization,
    required this.onChanged,
    required this.newOrganizationController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedOrganization,
          items: [
            for (final organization in organizations)
              DropdownMenuItem(value: organization, child: Text(organization)),
            const DropdownMenuItem(
              value: '__org__',
              child: Text('Добавить новую организацию...'),
            ),
          ],
          decoration: const InputDecoration(
            labelText: 'Организация/склад',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
          onChanged: onChanged,
        ),
        if (isAddingNewOrganization) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: newOrganizationController,
            decoration: const InputDecoration(
              labelText: 'Название новой организации',
              prefixIcon: Icon(Icons.business_center_outlined),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите название организации';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}
