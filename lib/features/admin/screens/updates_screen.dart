import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../services/update_service.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key});

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  UpdateInfo? _latest;
  bool _isChecking = false;
  bool _isDownloading = false;
  String? _message;
  bool _autoUpdateEnabled = true;
  static const _autoUpdateKey = 'update_auto_enabled';

  @override
  void initState() {
    super.initState();
    _loadAutoUpdateSetting();
    _checkUpdates();
  }

  Future<void> _loadAutoUpdateSetting() async {
    final repo = ref.read(settingsRepositoryProvider);
    final value = await repo.getSetting(_autoUpdateKey);
    if (!mounted) return;
    setState(() {
      _autoUpdateEnabled =
          value == null ? true : value.toLowerCase() == 'true';
    });
  }

  Future<void> _saveAutoUpdateSetting(bool value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(_autoUpdateKey, value ? 'true' : 'false');
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    try {
      final service = UpdateService();
      final latest = await service.checkForUpdates();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _message = latest == null
            ? ref.read(appLocalizationsProvider).updateNotAvailable
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '${ref.read(appLocalizationsProvider).updateError}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _downloadAndInstall() async {
    if (_latest?.url == null || _latest!.url!.isEmpty) return;
    setState(() {
      _isDownloading = true;
      _message = null;
    });
    try {
      final service = UpdateService();
      final file = await service.downloadUpdate(
        _latest!.url!,
        _latest!.version,
      );
      await service.installUpdate(file);
      if (!mounted) return;
      setState(() {
        _message = ref.read(appLocalizationsProvider).updateInstallStarted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '${ref.read(appLocalizationsProvider).updateError}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(appLocalizationsProvider);
    final currentVersion = AppConfig.instance.appVersion;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.updates,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text('${loc.currentVersion}: $currentVersion'),
                if (_latest != null) ...[
                  const SizedBox(height: 8),
                  Text('${loc.latestVersion}: ${_latest!.version}'),
                  if (_latest!.notes != null && _latest!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_latest!.notes!),
                  ],
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.startsWith(loc.updateError)
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _autoUpdateEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _autoUpdateEnabled = value;
                    });
                    await _saveAutoUpdateSetting(value);
                  },
                  title: Text(loc.autoUpdate),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkUpdates,
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.checkUpdates),
                    ),
                    const SizedBox(width: 8),
                    if (_latest != null)
                      ElevatedButton.icon(
                        onPressed: _isDownloading ? null : _downloadAndInstall,
                        icon: Icon(
                          Platform.isWindows
                              ? Icons.system_update_alt
                              : Icons.cloud_download,
                        ),
                        label: Text(loc.installUpdate),
                      ),
                  ],
                ),
                if (_isChecking || _isDownloading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

