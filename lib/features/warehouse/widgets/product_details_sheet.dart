import 'package:flutter/material.dart';
import '../../../utils/formatters.dart';
import '../../cashier/models/product.dart';
import '../../../features/shared/models/manufacturer.dart';
import '../../../core/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Диалог для просмотра деталей товара
class ProductDetailsSheet extends ConsumerWidget {
  final Product product;

  const ProductDetailsSheet({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                      'Детали товара',
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
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailSection(
                        title: 'Основная информация',
                        children: [
                          _DetailRow(label: 'Название', value: product.name),
                          _DetailRow(
                            label: 'Штрих-код',
                            value: product.barcode,
                            copyable: true,
                          ),
                          if (product.qrCode != null)
                            _DetailRow(
                              label: 'QR-код',
                              value: product.qrCode!,
                              copyable: true,
                            ),
                          _DetailRow(
                            label: 'Цена',
                            value: Formatters.formatMoney(product.price),
                          ),
                          _DetailRow(
                            label: 'Остаток',
                            value: '${product.stock} ${product.unit}',
                          ),
                          _DetailRow(
                            label: 'Единиц в упаковке',
                            value: '${product.unitsPerPackage} ${product.unitName}',
                          ),
                          _DetailRow(
                            label: 'Цена за единицу',
                            value: Formatters.formatMoney(product.price / product.unitsPerPackage),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<Manufacturer?>(
                        future: _loadManufacturer(ref),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final manufacturer = snapshot.data;
                          return _DetailSection(
                            title: 'Производитель',
                            children: [
                              _DetailRow(
                                label: 'Название',
                                value: manufacturer?.name ?? 'Не указан',
                              ),
                              if (manufacturer?.country != null)
                                _DetailRow(
                                  label: 'Страна',
                                  value: manufacturer!.country!,
                                ),
                              if (manufacturer?.phone != null)
                                _DetailRow(
                                  label: 'Телефон',
                                  value: manufacturer!.phone!,
                                  copyable: true,
                                ),
                              if (manufacturer?.email != null)
                                _DetailRow(
                                  label: 'Email',
                                  value: manufacturer!.email!,
                                  copyable: true,
                                ),
                            ],
                          );
                        },
                      ),
                      if (product.composition != null ||
                          product.indications != null ||
                          product.preparationMethod != null ||
                          product.requiresPrescription)
                        const SizedBox(height: 16),
                      if (product.composition != null ||
                          product.indications != null ||
                          product.preparationMethod != null ||
                          product.requiresPrescription)
                        _DetailSection(
                          title: 'Медицинская информация',
                          children: [
                            if (product.composition != null)
                              _DetailRow(
                                label: 'Состав',
                                value: product.composition!,
                                multiline: true,
                              ),
                            if (product.indications != null)
                              _DetailRow(
                                label: 'Показания к применению',
                                value: product.indications!,
                                multiline: true,
                              ),
                            if (product.preparationMethod != null)
                              _DetailRow(
                                label: 'Способ применения',
                                value: product.preparationMethod!,
                                multiline: true,
                              ),
                            _DetailRow(
                              label: 'Требуется рецепт',
                              value: product.requiresPrescription ? 'Да' : 'Нет',
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Manufacturer?> _loadManufacturer(WidgetRef ref) async {
    if (product.manufacturerId == null) return null;
    try {
      final manufacturerRepo = ref.read(manufacturerRepositoryProvider);
      return await manufacturerRepo.getManufacturerById(product.manufacturerId!);
    } catch (e) {
      return null;
    }
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.children,
  });

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
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool multiline;

  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: multiline
                ? Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (copyable)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            // TODO: Копировать в буфер обмена
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Скопировано в буфер обмена')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

