import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../utils/formatters.dart';
import '../../shared/models/receipt_history.dart';
import '../../shared/widgets/receipt_history_item.dart';
import '../widgets/receipt_details_dialog.dart';

class ReceiptsHistoryScreen extends ConsumerStatefulWidget {
  const ReceiptsHistoryScreen({super.key});

  @override
  ConsumerState<ReceiptsHistoryScreen> createState() =>
      _ReceiptsHistoryScreenState();
}

class _ReceiptsHistoryScreenState extends ConsumerState<ReceiptsHistoryScreen> {
  List<ReceiptHistory> _allReceipts = [];
  List<ReceiptHistory> _filteredReceipts = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  void _refreshReceipts() {
    if (_startDate != null && _endDate != null) {
      _filterByDateRange();
    } else {
      _loadReceipts();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final receiptRepo = ref.read(receiptRepositoryProvider);
      final receipts = await receiptRepo.getAllReceipts();

      if (!mounted) return;
      setState(() {
        _allReceipts = receipts;
        _filteredReceipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final loc = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _filterByDateRange() async {
    if (_startDate == null || _endDate == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final receiptRepo = ref.read(receiptRepositoryProvider);
      // Устанавливаем время для начала и конца дня
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );

      final receipts = await receiptRepo.getReceiptsByDateRange(start, end);

      if (!mounted) return;
      setState(() {
        _filteredReceipts = receipts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final loc = ref.read(appLocalizationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredReceipts = _allReceipts;
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });

      // Если выбрана конечная дата, применяем фильтр
      if (_endDate != null) {
        _filterByDateRange();
      }
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });

      // Если выбрана начальная дата, применяем фильтр
      if (_startDate != null) {
        _filterByDateRange();
      }
    }
  }

  void _showReceiptDetails(ReceiptHistory receipt) {
    showDialog(
      context: context,
      builder: (context) => ReceiptDetailsDialog(receipt: receipt),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(loc.receiptsHistory),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: loc.refresh,
            onPressed: _refreshReceipts,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          // Панель фильтров
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectStartDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _startDate != null
                              ? _formatDate(_startDate!)
                              : loc.selectStartDate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectEndDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _endDate != null
                              ? _formatDate(_endDate!)
                              : loc.selectEndDate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_startDate != null || _endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: loc.clearFilter,
                        onPressed: _clearFilter,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.totalReceipts}: ${_filteredReceipts.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_filteredReceipts.isNotEmpty)
                      Text(
                        '${loc.totalAmount}: ${Formatters.formatMoney(_filteredReceipts.fold(0.0, (sum, r) => sum + r.total))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Список чеков
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReceipts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.noReceiptsFound,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadReceipts,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredReceipts.length,
                      itemBuilder: (context, index) {
                        final receipt = _filteredReceipts[index];
                        return ReceiptHistoryItemWidget(
                          receipt: receipt,
                          onTap: () => _showReceiptDetails(receipt),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
