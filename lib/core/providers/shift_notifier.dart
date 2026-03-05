import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/shift_repository.dart';
import '../../features/shared/models/shift_record.dart';
import 'repository_providers.dart';

class ShiftState {
  final bool isLoading;
  final bool isProcessing;
  final ShiftRecord? activeShift;
  final String? error;

  const ShiftState({
    required this.isLoading,
    required this.isProcessing,
    required this.activeShift,
    this.error,
  });

  factory ShiftState.initial() => const ShiftState(
        isLoading: false,
        isProcessing: false,
        activeShift: null,
      );

  ShiftState copyWith({
    bool? isLoading,
    bool? isProcessing,
    ShiftRecord? activeShift,
    String? error,
  }) {
    return ShiftState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      activeShift: activeShift ?? this.activeShift,
      error: error,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  final Ref ref;

  ShiftNotifier(this.ref) : super(ShiftState.initial());

  ShiftRepository get _repository => ref.read(shiftRepositoryProvider);

  Future<void> load(int userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final shift = await _repository.getActiveShift(userId);
      state = state.copyWith(isLoading: false, activeShift: shift, error: null);
    } catch (e) {
      // Логируем ошибку, но не прерываем работу приложения
      // Если смена не загрузилась, кассир все равно может работать
      state = state.copyWith(
        isLoading: false, 
        activeShift: null, 
        error: e.toString(),
      );
      // Не пробрасываем ошибку дальше, чтобы не падало приложение
    }
  }

  Future<ShiftRecord> startShift(int userId, String userName) async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final shift = await _repository.startShift(userId, userName);
      state = state.copyWith(isProcessing: false, activeShift: shift);
      return shift;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }

  Future<ShiftRecord?> closeShift(int userId) async {
    final currentShift = state.activeShift;
    if (currentShift == null) return null;

    state = state.copyWith(isProcessing: true, error: null);
    try {
      final result = await _repository.endShift(currentShift.id, userId);
      state = state.copyWith(isProcessing: false, activeShift: null);
      return result;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }

  void reset() {
    state = ShiftState.initial();
  }
}

final shiftStateProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>((ref) {
  return ShiftNotifier(ref);
});

