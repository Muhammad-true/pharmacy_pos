import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cashier/models/product.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../features/shared/models/manufacturer.dart';

/// Диалог для редактирования товара
class EditProductSheet extends ConsumerStatefulWidget {
  final Product product;

  const EditProductSheet({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<EditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _qrCodeController;
  late final TextEditingController _inventoryCodeController;
  late final TextEditingController _organizationController;
  late final TextEditingController _shelfController;
  late final TextEditingController _priceController;
  late final TextEditingController _unitsController;
  late final TextEditingController _unitNameController;
  late final TextEditingController _compositionController;
  late final TextEditingController _indicationsController;
  late final TextEditingController _preparationMethodController;

  Manufacturer? _selectedManufacturer;
  bool _requiresPrescription = false;
  bool _isLoadingManufacturers = true;
  List<Manufacturer> _manufacturers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _barcodeController = TextEditingController(text: widget.product.barcode);
    _qrCodeController = TextEditingController(text: widget.product.qrCode ?? '');
    _inventoryCodeController = TextEditingController(text: widget.product.inventoryCode ?? '');
    _organizationController = TextEditingController(text: widget.product.organization ?? '');
    _shelfController = TextEditingController(text: widget.product.shelfLocation ?? '');
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _unitsController = TextEditingController(text: widget.product.unitsPerPackage.toString());
    _unitNameController = TextEditingController(text: widget.product.unitName);
    _compositionController = TextEditingController(text: widget.product.composition ?? '');
    _indicationsController = TextEditingController(text: widget.product.indications ?? '');
    _preparationMethodController = TextEditingController(text: widget.product.preparationMethod ?? '');
    _requiresPrescription = widget.product.requiresPrescription;
    _loadManufacturers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _qrCodeController.dispose();
    _inventoryCodeController.dispose();
    _organizationController.dispose();
    _shelfController.dispose();
    _priceController.dispose();
    _unitsController.dispose();
    _unitNameController.dispose();
    _compositionController.dispose();
    _indicationsController.dispose();
    _preparationMethodController.dispose();
    super.dispose();
  }

  Future<void> _loadManufacturers() async {
    setState(() {
      _isLoadingManufacturers = true;
    });

    try {
      final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
      final manufacturers = await manufacturerRepo.getAllManufacturers();
      
      // Находим текущего производителя
      Manufacturer? currentManufacturer;
      if (widget.product.manufacturerId != null) {
        currentManufacturer = manufacturers.firstWhere(
          (m) => m.id == widget.product.manufacturerId,
          orElse: () => manufacturers.isNotEmpty ? manufacturers.first : Manufacturer(id: 0, name: ''),
        );
      }
      
      setState(() {
        _manufacturers = manufacturers;
        _selectedManufacturer = currentManufacturer;
        _isLoadingManufacturers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingManufacturers = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final productRepo = ref.read(productRepositoryProvider);
      
      final updatedProduct = Product(
        id: widget.product.id,
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim(),
        qrCode: _qrCodeController.text.trim().isEmpty ? null : _qrCodeController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        stock: widget.product.stock, // Остаток не меняем при редактировании
        unit: widget.product.unit,
        unitsPerPackage: int.parse(_unitsController.text.trim()),
        unitName: _unitNameController.text.trim(),
        manufacturerId: _selectedManufacturer?.id,
        composition: _compositionController.text.trim().isEmpty ? null : _compositionController.text.trim(),
        indications: _indicationsController.text.trim().isEmpty ? null : _indicationsController.text.trim(),
        preparationMethod: _preparationMethodController.text.trim().isEmpty ? null : _preparationMethodController.text.trim(),
        requiresPrescription: _requiresPrescription,
        inventoryCode: _inventoryCodeController.text.trim().isEmpty
            ? null
            : _inventoryCodeController.text.trim(),
        organization: _organizationController.text.trim().isEmpty
            ? null
            : _organizationController.text.trim(),
        shelfLocation: _shelfController.text.trim().isEmpty
            ? null
            : _shelfController.text.trim(),
      );

      await productRepo.updateProduct(updatedProduct);

      if (!mounted) return;
      
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар успешно обновлен'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка обновления товара: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.transparent,
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.95,
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
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Редактировать товар',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _SectionCard(
                              title: 'Основная информация',
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Название товара',
                                      prefixIcon: Icon(Icons.medication_liquid_outlined),
                                    ),
                                    textCapitalization: TextCapitalization.sentences,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Введите название';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _barcodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Штрих-код',
                                      prefixIcon: Icon(Icons.qr_code_2),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Введите штрих-код';
                                      }
                                      return null;
                                    },
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
                                  TextFormField(
                                    controller: _inventoryCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Код товара / инвентарный код',
                                      prefixIcon: Icon(Icons.category_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _organizationController,
                                    decoration: const InputDecoration(
                                      labelText: 'Склад / организация',
                                      prefixIcon: Icon(Icons.apartment_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _shelfController,
                                    decoration: const InputDecoration(
                                      labelText: 'Полка / расположение',
                                      prefixIcon: Icon(Icons.storage_outlined),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Цена и упаковка',
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Цена за упаковку, сум',
                                      prefixIcon: Icon(Icons.attach_money),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final doubleValue = double.tryParse(value ?? '');
                                      if (doubleValue == null || doubleValue <= 0) {
                                        return 'Введите цену';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _unitsController,
                                          decoration: const InputDecoration(
                                            labelText: 'Единиц в упаковке',
                                            prefixIcon: Icon(Icons.inventory_2_outlined),
                                          ),
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            final intValue = int.tryParse(value ?? '');
                                            if (intValue == null || intValue <= 0) {
                                              return 'Введите число';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _unitNameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Название единицы',
                                            prefixIcon: Icon(Icons.medication_outlined),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Введите название';
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
                              title: 'Производитель',
                              child: _isLoadingManufacturers
                                  ? const Center(child: CircularProgressIndicator())
                                  : DropdownButtonFormField<Manufacturer?>(
                                      value: _selectedManufacturer,
                                      items: [
                                        const DropdownMenuItem<Manufacturer?>(
                                          value: null,
                                          child: Text('Не указан'),
                                        ),
                                        for (final manufacturer in _manufacturers)
                                          DropdownMenuItem<Manufacturer>(
                                            value: manufacturer,
                                            child: Text(manufacturer.name),
                                          ),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Производитель',
                                        prefixIcon: Icon(Icons.factory_outlined),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedManufacturer = value;
                                        });
                                      },
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
                                      hintText: 'Активные вещества и вспомогательные компоненты',
                                      prefixIcon: Icon(Icons.science_outlined),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 3,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _indicationsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Показания к применению',
                                      hintText: 'При каких заболеваниях/симптомах применяется',
                                      prefixIcon: Icon(Icons.medical_services_outlined),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 3,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _preparationMethodController,
                                    decoration: const InputDecoration(
                                      labelText: 'Способ применения',
                                      hintText: 'Как принимать препарат',
                                      prefixIcon: Icon(Icons.medication_liquid_outlined),
                                      alignLabelWithHint: true,
                                    ),
                                    maxLines: 3,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                  const SizedBox(height: 12),
                                  CheckboxListTile(
                                    title: const Text('Требуется рецепт врача'),
                                    subtitle: const Text('Препарат отпускается только по рецепту'),
                                    value: _requiresPrescription,
                                    onChanged: (value) {
                                      setState(() {
                                        _requiresPrescription = value ?? false;
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
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
                      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Отмена'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoadingManufacturers ? null : _save,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              child: const Text('Сохранить'),
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
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

