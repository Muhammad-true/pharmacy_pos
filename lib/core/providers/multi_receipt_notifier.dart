import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/cashier/models/receipt.dart';
import '../../features/cashier/models/active_receipt.dart';

part 'multi_receipt_notifier.g.dart';

/// Состояние нескольких активных чеков
@Riverpod(keepAlive: true)
class MultiReceiptState extends _$MultiReceiptState {
  @override
  Map<String, ActiveReceipt> build() {
    // Создаем начальный чек при инициализации
    final initialReceipt = Receipt();
    final initialId = _generateReceiptId();
    return {
      initialId: ActiveReceipt(
        id: initialId,
        receipt: initialReceipt,
      ),
    };
  }

  String? _currentReceiptId;

  /// Получить ID текущего активного чека
  String? get currentReceiptId => _currentReceiptId ?? state.keys.firstOrNull;

  /// Получить текущий активный чек
  ActiveReceipt? get currentReceipt {
    final id = currentReceiptId;
    if (id == null) return null;
    return state[id];
  }

  /// Получить список всех активных чеков
  List<ActiveReceipt> get activeReceipts => state.values.toList();

  /// Создать новый чек
  String createNewReceipt() {
    final newId = _generateReceiptId();
    final newReceipt = Receipt();
    final newActiveReceipt = ActiveReceipt(
      id: newId,
      receipt: newReceipt,
    );
    
    state = {...state, newId: newActiveReceipt};
    _currentReceiptId = newId;
    return newId;
  }

  /// Переключиться на другой чек
  void switchToReceipt(String receiptId) {
    if (state.containsKey(receiptId)) {
      _currentReceiptId = receiptId;
      // Обновляем состояние для перерисовки
      state = {...state};
    }
  }

  /// Удалить чек
  void removeReceipt(String receiptId) {
    if (!state.containsKey(receiptId)) return;
    
    final newState = Map<String, ActiveReceipt>.from(state);
    newState.remove(receiptId);
    
    // Если удалили текущий чек, переключаемся на первый доступный
    if (_currentReceiptId == receiptId) {
      if (newState.isEmpty) {
        // Если нет чеков, создаем новый
        final newId = _generateReceiptId();
        final newReceipt = Receipt();
        newState[newId] = ActiveReceipt(
          id: newId,
          receipt: newReceipt,
        );
        _currentReceiptId = newId;
      } else {
        _currentReceiptId = newState.keys.first;
      }
    }
    
    state = newState;
  }

  /// Обновить чек
  void updateReceipt(String receiptId, Receipt receipt) {
    if (!state.containsKey(receiptId)) return;
    
    final activeReceipt = state[receiptId]!;
    state = {
      ...state,
      receiptId: ActiveReceipt(
        id: receiptId,
        receipt: receipt,
        clientName: activeReceipt.clientName,
        createdAt: activeReceipt.createdAt,
      ),
    };
  }

  /// Обновить имя клиента для чека
  void updateClientName(String receiptId, String? clientName) {
    if (!state.containsKey(receiptId)) return;
    
    final activeReceipt = state[receiptId]!;
    // Не обновляем, если имя уже такое же (предотвращаем бесконечный цикл)
    if (activeReceipt.clientName == clientName) return;
    
    state = {
      ...state,
      receiptId: ActiveReceipt(
        id: receiptId,
        receipt: activeReceipt.receipt,
        clientName: clientName,
        createdAt: activeReceipt.createdAt,
      ),
    };
  }

  /// Получить чек по ID
  Receipt? getReceipt(String receiptId) {
    return state[receiptId]?.receipt;
  }

  String _generateReceiptId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}

