import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../theme/colors.dart';
import '../widgets/motion_wrapper.dart';
import '../widgets/animated_modal_sheet.dart';
import '../screens/onboarding_screen.dart';

class ProfileModal extends StatefulWidget {
  final VoidCallback onProfileUpdated;

  const ProfileModal({super.key, required this.onProfileUpdated});

  static Future<void> show(BuildContext context, {required VoidCallback onProfileUpdated}) {
    return showSettlrModalSheet(
      context: context,
      child: SettlrModalContainer(
        maxHeightRatio: 0.88,
        child: ProfileModal(onProfileUpdated: onProfileUpdated),
      ),
    );
  }

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  final _nameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  String _selectedCurrency = 'INR';
  bool _isLoading = false;
  bool _isSavingName = false;
  bool _isSavingServer = false;
  bool _isCheckingUpdate = false;
  String? _statusMessage;
  bool _isError = false;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ApiService.getUserName();
    final url = await ApiService.getBaseUrl();
    if (mounted) {
      setState(() {
        _nameController.text = name;
        _serverUrlController.text = url;
      });
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isSavingName = true;
      _statusMessage = null;
    });

    try {
      await ApiService.startSession(name: newName, defaultCurrency: _selectedCurrency);
      widget.onProfileUpdated();
      if (mounted) {
        setState(() {
          _statusMessage = 'Profile updated successfully!';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to update profile: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _saveServerUrl() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isSavingServer = true;
      _statusMessage = null;
    });

    try {
      await ApiService.setBaseUrl(url);
      if (mounted) {
        setState(() {
          _statusMessage = 'Server URL set. Restart/syncing data...';
          _isError = false;
        });
      }
      widget.onProfileUpdated();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to set URL: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingServer = false);
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _isCheckingUpdate = true;
      _statusMessage = null;
    });

    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (info.hasUpdate) {
        _showUpdateDialog(info);
      } else {
        setState(() {
          _statusMessage = 'Settlr is up to date (${info.currentVersion})';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Update check failed: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String downloadStatus = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.system_update, color: SettlrColors.primary),
                  const SizedBox(width: 8),
                  Text('Update to ${info.latestVersion}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new version (${info.latestVersion}) is available. Current version is ${info.currentVersion}.',
                    style: const TextStyle(fontSize: 13, color: SettlrColors.textMain),
                  ),
                  const SizedBox(height: 12),
                  if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
                    const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          info.releaseNotes!,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isDownloading) ...[
                    LinearProgressIndicator(value: downloadProgress > 0 ? downloadProgress : null),
                    const SizedBox(height: 6),
                    Text(
                      downloadStatus,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isDownloading) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SettlrColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (info.downloadUrl == null) return;
                      setModalState(() {
                        isDownloading = true;
                        downloadStatus = 'Downloading update package...';
                      });

                      try {
                        await UpdateService.downloadAndInstall(
                          downloadUrl: info.downloadUrl!,
                          onProgress: (prog, rec, tot) {
                            setModalState(() {
                              downloadProgress = prog;
                              final mbRec = (rec / (1024 * 1024)).toStringAsFixed(1);
                              final mbTot = (tot / (1024 * 1024)).toStringAsFixed(1);
                              downloadStatus = '$mbRec MB / $mbTot MB (${(prog * 100).toInt()}%)';
                            });
                          },
                        );
                        Navigator.pop(ctx);
                      } catch (e) {
                        setModalState(() {
                          isDownloading = false;
                          downloadStatus = 'Install failed: $e';
                        });
                      }
                    },
                    child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out and clear your active local session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SettlrColors.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pop(context); // close modal
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nameController.text.isNotEmpty
        ? _nameController.text.substring(0, _nameController.text.length >= 2 ? 2 : 1).toUpperCase()
        : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: SettlrColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: SettlrColors.textMain,
                        ),
                      ),
                      Text(
                        'Preferences & connection settings',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              BouncyPress(
                onTap: () => Navigator.pop(context),
                scaleDown: 0.90,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Status message banner
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isError ? SettlrColors.negativeBg : SettlrColors.positiveBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isError ? SettlrColors.negative : SettlrColors.positive,
                ),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  fontSize: 12,
                  color: _isError ? SettlrColors.negative : SettlrColors.positive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Name Field
          const Text(
            'Display Name',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1F000000)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BouncyPress(
                onTap: _isSavingName ? null : _saveName,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isSavingName
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Currency Selector
          const Text(
            'Default Currency',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
          ),
          const SizedBox(height: 6),
          SlidingPillSegment(
            selectedIndex: _currencies.indexOf(_selectedCurrency) >= 0
                ? _currencies.indexOf(_selectedCurrency)
                : 0,
            itemCount: _currencies.length,
            height: 36,
            onSelected: (idx) {
              setState(() => _selectedCurrency = _currencies[idx]);
            },
            children: _currencies.map((c) {
              return Text(
                c,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _selectedCurrency == c ? FontWeight.bold : FontWeight.w500,
                  color: _selectedCurrency == c ? SettlrColors.primary : Colors.grey.shade600,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Backend Server Switcher (Wi-Fi config)
          const Text(
            'Backend API Server',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
          ),
          const Text(
            'Local network IP or Cloudflare tunnel URL',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    hintText: 'http://192.168.1.X:8080',
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0x1F000000)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BouncyPress(
                onTap: _isSavingServer ? null : _saveServerUrl,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: SettlrColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isSavingServer
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // In-App Updates Card
          SettlrPanel(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Version',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: SettlrColors.textMain),
                    ),
                    Text(
                      'v0.0.5 (Deterministic Signing)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                BouncyPress(
                  onTap: _isCheckingUpdate ? null : _checkForUpdate,
                  scaleDown: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x1A000000)),
                    ),
                    child: _isCheckingUpdate
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: SettlrColors.primary),
                          )
                        : const Text(
                            'Check Update',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: SettlrColors.textMain,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Log Out Button
          BouncyPress(
            onTap: _logout,
            scaleDown: 0.96,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: SettlrColors.negativeBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SettlrColors.negative.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 16, color: SettlrColors.negative),
                  SizedBox(width: 8),
                  Text(
                    'Log Out & Switch User',
                    style: TextStyle(
                      color: SettlrColors.negative,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
