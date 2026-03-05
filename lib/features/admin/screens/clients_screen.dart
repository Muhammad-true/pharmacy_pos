import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../utils/formatters.dart';
import '../../shared/models/client.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(clientRepositoryProvider);
      final clients = await repo.getAllClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _filteredClients = clients;
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

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredClients = _clients;
      });
      return;
    }
    setState(() {
      _filteredClients = _clients.where((client) {
        final name = client.name.toLowerCase();
        final phone = (client.phone ?? '').toLowerCase();
        final qr = (client.qrCode ?? '').toLowerCase();
        return name.contains(query) ||
            phone.contains(query) ||
            qr.contains(query);
      }).toList();
    });
  }

  Widget _buildSearchField(AppLocalizations loc) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: '${loc.search}...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _buildSearchField(loc),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadClients,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredClients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              loc.clientNotFound,
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
                        itemCount: _filteredClients.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final client = _filteredClients[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {},
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                      child: Icon(
                                        Icons.person,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.phone,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                client.phone ?? '-',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.stars,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                Formatters.formatBonuses(
                                                  client.bonuses,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.qr_code,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  client.qrCode ?? '-',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.7),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      children: [
                                        Text(
                                          loc.qrCode,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (client.qrCode != null &&
                                            client.qrCode!.isNotEmpty)
                                          QrImageView(
                                            data: client.qrCode!,
                                            version: QrVersions.auto,
                                            size: 110,
                                            backgroundColor: Colors.white,
                                          )
                                        else
                                          Container(
                                            width: 110,
                                            height: 110,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.qr_code_2_outlined,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

