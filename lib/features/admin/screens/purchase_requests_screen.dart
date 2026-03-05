import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../utils/formatters.dart';
import '../../shared/models/purchase_request.dart';

class PurchaseRequestsScreen extends ConsumerStatefulWidget {
  const PurchaseRequestsScreen({super.key});

  @override
  ConsumerState<PurchaseRequestsScreen> createState() =>
      _PurchaseRequestsScreenState();
}

class _PurchaseRequestsScreenState
    extends ConsumerState<PurchaseRequestsScreen> {
  List<PurchaseRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final repo = ref.read(purchaseRequestRepositoryProvider);
      final requests = await repo.getAllRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      final loc = ref.read(appLocalizationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolve(int id) async {
    final repo = ref.read(purchaseRequestRepositoryProvider);
    await repo.markResolved(id);
    await _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        loc.purchaseRequests,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final req = _requests[index];
                    final isResolved = req.status == 'resolved';
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          isResolved
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: isResolved ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          req.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (req.requestedByUserName != null)
                              Text(
                                '${loc.requestedBy}: ${req.requestedByUserName}',
                              ),
                            if (req.createdAt != null)
                              Text(
                                Formatters.formatDateTime(req.createdAt!),
                              ),
                          ],
                        ),
                        trailing: isResolved
                            ? Text(
                                loc.requestStatusResolved,
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => _resolve(req.id),
                                child: Text(loc.resolve),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

