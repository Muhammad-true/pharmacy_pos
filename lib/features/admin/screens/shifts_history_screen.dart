import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../utils/formatters.dart';
import '../../shared/models/shift_record.dart';

class ShiftsHistoryScreen extends ConsumerStatefulWidget {
  const ShiftsHistoryScreen({super.key});

  @override
  ConsumerState<ShiftsHistoryScreen> createState() => _ShiftsHistoryScreenState();
}

class _ShiftsHistoryScreenState extends ConsumerState<ShiftsHistoryScreen> {
  List<ShiftRecord> _allShifts = [];
  List<ShiftRecord> _filteredShifts = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(shiftRepositoryProvider);
      final shifts = await repo.getShifts();
      setState(() {
        _allShifts = shifts;
        _filteredShifts = shifts;
        _isLoading = false;
      });
    } catch (e) {
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
      final repo = ref.read(shiftRepositoryProvider);
      final shifts = await repo.getShifts(
        startDate: DateTime(
          _startDate!.year,
          _startDate!.month,
          _startDate!.day,
        ),
        endDate: DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        ),
      );
      setState(() {
        _filteredShifts = shifts;
        _isLoading = false;
      });
    } catch (e) {
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
      if (_startDate != null) {
        _filterByDateRange();
      }
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _filteredShifts = _allShifts;
    });
  }

  void _refresh() {
    if (_startDate != null && _endDate != null) {
      _filterByDateRange();
    } else {
      _loadShifts();
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours ч ${minutes.toString().padLeft(2, '0')} м';
    }
    return '$minutes м';
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);
    final totalRevenue =
        _filteredShifts.fold<double>(0, (sum, shift) => sum + shift.totalRevenue);
    final totalReceipts =
        _filteredShifts.fold<int>(0, (sum, shift) => sum + shift.totalReceipts);
    final totalDuration = _filteredShifts.fold<Duration>(
      Duration.zero,
      (sum, shift) => sum + shift.duration,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.shiftsHistory),
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
            onPressed: _refresh,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
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
                              ? Formatters.formatDate(_startDate!)
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
                              ? Formatters.formatDate(_endDate!)
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
                  children: [
                    Expanded(
                      child: Text(
                        '${loc.totalShifts}: ${_filteredShifts.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${loc.shiftWorkingHours}: ${_formatDuration(totalDuration)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${loc.shiftRevenue}: ${Formatters.formatMoney(totalRevenue)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${loc.shiftReceipts}: $totalReceipts',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredShifts.isEmpty
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
                              loc.noShiftsFound,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadShifts,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredShifts.length,
                          itemBuilder: (context, index) {
                            final shift = _filteredShifts[index];
                            final isActive = shift.endTime == null;
                            return Card(
                              color: isActive ? Colors.blue[50] : Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          shift.userName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(shift.duration),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${loc.shiftOpenedAt}: ${Formatters.formatDateTime(shift.startTime)}',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    if (shift.endTime != null)
                                      Text(
                                        '${loc.shiftClosedAt}: ${Formatters.formatDateTime(shift.endTime!)}',
                                        style: TextStyle(color: Colors.grey[700]),
                                      )
                                    else
                                      Text(
                                        loc.shiftActive,
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Chip(
                                          avatar: const Icon(Icons.receipt_long, size: 16),
                                          label: Text(
                                            '${loc.shiftReceipts}: ${shift.totalReceipts}',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          avatar: const Icon(Icons.payments, size: 16),
                                          label: Text(
                                            '${loc.shiftRevenue}: ${Formatters.formatMoney(shift.totalRevenue)}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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

