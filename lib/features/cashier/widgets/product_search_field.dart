import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../../../core/providers/product_search_notifier.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../utils/formatters.dart';

/// Виджет для отображения элемента результата поиска товара
class _ProductSearchResultItem extends StatefulWidget {
  final Product product;
  final bool hasStock;
  final AppLocalizations loc;
  final VoidCallback onTap;

  const _ProductSearchResultItem({
    required this.product,
    required this.hasStock,
    required this.loc,
    required this.onTap,
  });

  @override
  State<_ProductSearchResultItem> createState() => _ProductSearchResultItemState();
}

class _ProductSearchResultItemState extends State<_ProductSearchResultItem> {
  // Получаем полку на основе ID товара (та же логика, что и в warehouse)
  String _getShelfLocation() {
    const defaultShelves = ['A-01', 'A-02', 'B-10', 'C-07', 'D-03'];
    return defaultShelves[widget.product.id % defaultShelves.length];
  }

  @override
  Widget build(BuildContext context) {
    final shelfLocation = _getShelfLocation();
    
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: () {
        if (!widget.hasStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${widget.loc.outOfStock}: ${widget.product.name}',
              ),
              duration: const Duration(milliseconds: 1500),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        if (kDebugMode) {
          print('🟢🟢🟢 _ProductSearchResultItem: ListTile onTap вызван для: ${widget.product.name}');
        }
        widget.onTap();
      },
      title: Text(
        widget.product.name,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: widget.hasStock ? Colors.black87 : Colors.grey[600],
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${widget.loc.barcode}: ${widget.product.barcode.isNotEmpty ? widget.product.barcode : widget.loc.notSpecified} | ${widget.loc.priceLabel}: ${Formatters.formatMoney(widget.product.price)} | ${widget.loc.inStockLabel}: ${widget.product.stock} ${widget.product.unit}',
            style: TextStyle(
              fontSize: 12,
              color: widget.hasStock ? Colors.grey[600] : Colors.orange[700],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.loc.shelf}: $shelfLocation',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: !widget.hasStock
          ? Text(
              widget.loc.outOfStock,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            )
          : null,
    );
  }
}

class ProductSearchField extends ConsumerStatefulWidget {
  final Function(Product) onProductSelected;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const ProductSearchField({
    super.key,
    required this.onProductSelected,
    this.focusNode,
    this.onTap,
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _searchDebounceTimer;
  DateTime? _lastInputTime;
  DateTime? _firstInputTime;
  int _inputLength = 0;
  bool _isBarcodeInput = false;
  bool _isOverlayPointerDown = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
    widget.focusNode?.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _controller.removeListener(_onSearchChanged);
    widget.focusNode?.removeListener(_onFocusChanged);
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    // При изменении фокуса overlay обновится автоматически через логику в build()
    // Здесь только удаляем overlay при потере фокуса
    if (widget.focusNode?.hasFocus != true) {
      // Даем время на обработку клика по элементу overlay
      Future.microtask(() {
        if (!mounted) return;
        if (widget.focusNode?.hasFocus != true && !_isOverlayPointerDown) {
          _removeOverlay();
        }
      });
    }
  }

  void _onSearchChanged() async {
    final query = _controller.text.trim();
    final now = DateTime.now();
    final queryLength = query.length;

    // Отменяем предыдущий таймер поиска
    _searchDebounceTimer?.cancel();

    if (query.isEmpty) {
      _removeOverlay();
      _isBarcodeInput = false;
      _firstInputTime = null;
      _inputLength = 0;
      // Загружаем все товары
      await ref.read(productSearchStateProvider.notifier).refresh();
      return;
    }

    if (queryLength < 1) {
      return;
    }

    // Отслеживаем начало ввода для определения скорости
    if (_firstInputTime == null || queryLength < _inputLength) {
      // Начало нового ввода или удаление символов - сбрасываем таймер
      _firstInputTime = now;
      _inputLength = queryLength;
      _lastInputTime = now;
    } else {
      _inputLength = queryLength;
    }

    // Для коротких запросов (< 8 символов) всегда выполняем поиск
    // Это точно не штрих-код от сканера
    if (queryLength < 8) {
      _isBarcodeInput = false;
      _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final currentQuery = _controller.text.trim();
        if (!mounted || currentQuery != query) return;
      
        // Выполняем поиск по названию, штрих-коду, QR-коду или ID
        await ref.read(productSearchStateProvider.notifier).search(currentQuery);
      });
        return;
      }
      
    // Для длинных запросов (>= 8 символов) определяем, штрих-код это или поиск
    // Сканеры обычно вводят все символы очень быстро (все символы за 50-200ms)
    // Ручной ввод происходит медленнее (каждый символ с паузой 150-500ms+)
    final timeSinceLastInput = _lastInputTime != null 
        ? now.difference(_lastInputTime!).inMilliseconds 
        : 1000;
    final timeSinceFirstInput = _firstInputTime != null
        ? now.difference(_firstInputTime!).inMilliseconds
        : 1000;
    
    _lastInputTime = now;
        
    // Определяем штрих-код только если:
    // 1. Длина >= 8 символов
    // 2. Очень быстрый ввод: время между символами < 50ms И весь ввод за < 300ms
    // Это более строгие критерии, чтобы не блокировать обычный поиск
    if (timeSinceLastInput < 50 && 
        timeSinceFirstInput < 300 &&
        queryLength >= 8) {
      // Очень быстрый ввод длинной строки - скорее всего штрих-код от сканера
      _isBarcodeInput = true;
      _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () async {
        final currentQuery = _controller.text.trim();
        if (!mounted) {
          _isBarcodeInput = false;
          return;
        }
        
        if (currentQuery != query) {
          // Если текст изменился, это не штрих-код - выполняем поиск
          _isBarcodeInput = false;
          if (currentQuery.isNotEmpty) {
            await ref.read(productSearchStateProvider.notifier).search(currentQuery);
          }
          return;
        }
        
        // Проверяем, что текст не изменился - это штрих-код
        await _tryFindProductByBarcode(currentQuery);
      });
            return;
      }
      
    // Медленный ввод длинного запроса - это поиск по названию/коду
    _isBarcodeInput = false;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final currentQuery = _controller.text.trim();
      if (!mounted || currentQuery != query) return;
      
      // Выполняем поиск по названию, штрих-коду, QR-коду или ID
      await ref.read(productSearchStateProvider.notifier).search(currentQuery);
      
      // После выполнения поиска overlay должен показаться автоматически через build()
      // Но убедимся, что _isBarcodeInput сброшен
      if (mounted) {
        _isBarcodeInput = false;
      }
    });
  }

  /// Попытка найти товар по штрих-коду или QR-коду и автоматически добавить в чек
  Future<void> _tryFindProductByBarcode(String code) async {
    try {
      final productRepo = ref.read(productRepositoryProvider);
      
      // Сначала пробуем найти по штрих-коду
      Product? product = await productRepo.getProductByBarcode(code);
      
      // Если не найден по штрих-коду, пробуем по QR-коду
      if (product == null) {
        product = await productRepo.getProductByQrCode(code);
      }
      
      // Если товар найден, автоматически добавляем его в чек
      if (product != null && mounted) {
        widget.onProductSelected(product);
        _controller.clear();
        _removeOverlay();
        _isBarcodeInput = false;
        
        // Возвращаем фокус на поле поиска для следующего сканирования
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.focusNode != null) {
            widget.focusNode!.requestFocus();
          }
        });
        
        // Показываем уведомление о добавлении товара
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ref.watch(appLocalizationsProvider).productAdded}: "${product.name}"'),
              duration: const Duration(milliseconds: 1000),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // Если товар не найден по штрих-коду/QR-коду, выполняем обычный поиск
      // (может быть это код товара или название)
      _isBarcodeInput = false;
      await ref.read(productSearchStateProvider.notifier).search(code);
      
      // Убеждаемся, что overlay покажется после поиска
      if (mounted) {
        // Триггерим обновление виджета, чтобы overlay показался
        setState(() {});
      }
    } catch (e) {
      // В случае ошибки показываем сообщение и выполняем обычный поиск
      _isBarcodeInput = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.watch(appLocalizationsProvider).error}: ${e.toString()}'),
            duration: const Duration(milliseconds: 2000),
            backgroundColor: Colors.red,
          ),
        );
      }
      await ref.read(productSearchStateProvider.notifier).search(code);
      
      // Убеждаемся, что overlay покажется после поиска
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showOverlay(List<Product> products) {
    if (!mounted || products.isEmpty) {
    _removeOverlay();
      return;
    }

    try {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        if (kDebugMode) {
          print('❌ ProductSearchField: renderBox равен null, не могу показать overlay');
        }
        _removeOverlay();
        return;
      }
    
    final size = renderBox.size;
      final loc = ref.read(appLocalizationsProvider);
      final productsToShow = products.length > 20 ? products.take(20).toList() : products;

      if (kDebugMode) {
        print('🟢 ProductSearchField: Показываю overlay с ${productsToShow.length} товарами');
      }

      // Удаляем старый overlay и создаем новый с актуальными данными
      _removeOverlay();

      // Сохраняем ссылку на продукты для использования в builder
      final productsForOverlay = productsToShow;

    _overlayEntry = OverlayEntry(
        builder: (overlayContext) {
          if (kDebugMode) {
            print('🟢 ProductSearchField: OverlayEntry builder вызван для ${productsForOverlay.length} товаров');
          }
          return Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Listener(
            onPointerDown: (_) => _isOverlayPointerDown = true,
            onPointerUp: (_) {
              Future.microtask(() {
                if (!mounted) return;
                _isOverlayPointerDown = false;
                if (widget.focusNode?.hasFocus != true) {
                  _removeOverlay();
                }
              });
            },
            child: Material(
              elevation: 8.0,
              borderRadius: BorderRadius.circular(8.0),
                  color: Colors.white,
                  shadowColor: Colors.black26,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: productsForOverlay.length,
                  itemBuilder: (context, index) {
                        final product = productsForOverlay[index];
                        final hasStock = product.stock > 0;
                        return _ProductSearchResultItem(
                          product: product,
                          hasStock: hasStock,
                          loc: loc,
                      onTap: () {
                            if (kDebugMode) {
                              print('🟢🟢🟢 ProductSearchField: КЛИК ПО ТОВАРУ в itemBuilder: ${product.name}');
                            }
                            
                            // Вызываем onProductSelected СНАЧАЛА
                            try {
                    widget.onProductSelected(product);
                              if (kDebugMode) {
                                print('🟢 ProductSearchField: onProductSelected вызван для: ${product.name}');
                              }
                            } catch (e, stackTrace) {
                              if (kDebugMode) {
                                print('❌ ProductSearchField: Ошибка при вызове onProductSelected: $e');
                                print('❌ StackTrace: $stackTrace');
                              }
                            }
                            
                            // Удаляем overlay и очищаем поле ПОСЛЕ вызова onProductSelected
                            _removeOverlay();
                            _isBarcodeInput = false;
                            _isOverlayPointerDown = false;
                            
                            // Очищаем поле через небольшую задержку
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) {
                    _controller.clear();
                    // Оставляем фокус для следующего поиска
                                if (widget.focusNode != null) {
                                  widget.focusNode!.requestFocus();
                                }
                              }
                            });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
          );
        },
    );

    overlay.insert(_overlayEntry!);
      if (kDebugMode) {
        print('🟢 ProductSearchField: Overlay вставлен в overlay stack');
      }
    } catch (e, stackTrace) {
      // В случае ошибки просто не показываем overlay
      if (kDebugMode) {
        print('❌ ProductSearchField: Ошибка при показе overlay: $e');
        print('❌ StackTrace: $stackTrace');
      }
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productSearchStateProvider);

    // Обновляем overlay при изменении результатов поиска
    // Используем addPostFrameCallback чтобы избежать вызова setState во время build
    productsAsync.when(
      data: (products) {
        final currentQuery = _controller.text.trim();
        
        // Показываем overlay если:
        // 1. Есть результаты поиска
        // 2. Поле в фокусе
        // 3. Запрос не пустой
        // 4. Это не быстрый ввод штрих-кода
        if (products.isNotEmpty && 
            widget.focusNode?.hasFocus == true && 
            currentQuery.isNotEmpty &&
            !_isBarcodeInput) {
          // Используем addPostFrameCallback чтобы избежать setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && 
                products.isNotEmpty && 
                widget.focusNode?.hasFocus == true && 
                _controller.text.trim().isNotEmpty) {
              _showOverlay(products);
            }
          });
        } else {
          // Удаляем overlay если нет результатов или запрос пустой
          if (products.isEmpty || currentQuery.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _removeOverlay();
              }
            });
          }
        }
      },
      loading: () {
        // При загрузке не удаляем overlay
      },
      error: (error, stack) {
        // При ошибке не удаляем overlay
      },
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        decoration: InputDecoration(
          hintText: ref.watch(appLocalizationsProvider).scanBarcodeOrEnter,
          prefixIcon: productsAsync.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.qr_code_scanner),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) async {
          final query = value.trim();
          if (query.isEmpty) return;
          
          // Отменяем таймер поиска при нажатии Enter
          _searchDebounceTimer?.cancel();
          _isBarcodeInput = false;
          _removeOverlay();
          
          // Выполняем поиск
          await ref.read(productSearchStateProvider.notifier).search(query);
          
          // Ждем немного, чтобы состояние обновилось
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (!mounted) return;
          
          // Получаем актуальные результаты поиска
          final searchState = ref.read(productSearchStateProvider);
          searchState.whenData((products) {
            if (!mounted) return;
            
            if (products.isNotEmpty) {
              // Добавляем первый найденный товар
              widget.onProductSelected(products.first);
              _controller.clear();
              _removeOverlay();
              // Оставляем фокус для следующего поиска
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && widget.focusNode != null) {
                  widget.focusNode!.requestFocus();
                }
              });
            } else {
              // Если товар не найден, показываем сообщение
              final loc = ref.watch(appLocalizationsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${loc.productNotFound}: "$query"'),
                  duration: const Duration(milliseconds: 2000),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          });
        },
      ),
    );
  }
}
