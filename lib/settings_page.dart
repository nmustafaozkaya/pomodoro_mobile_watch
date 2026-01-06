import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_model.dart';
import 'privacy_policy_page.dart';
import 'user_id_helper.dart';

class SettingsPage extends StatefulWidget {
  /// Dışarıdan hazır gelen ayarlar modeli (PhoneHome'dan paylaşılır)
  final SettingsModel settings;

  /// Arka planda gösterilecek mevcut duvar kağıdı (PhoneHome ile senkron)
  final String wallpaper;

  final Function(String) onWallpaperChanged;
  final Function(String) onLanguageChanged;

  const SettingsPage({
    super.key,
    required this.settings,
    required this.wallpaper,
    required this.onWallpaperChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  late final SettingsModel _settings;
  String _userId = '';
  final AudioPlayer _audioPlayer = AudioPlayer(); // Ses önizleme için

  @override
  bool get wantKeepAlive => true; // State'i koru

  @override
  void initState() {
    super.initState();
    // PhoneHome'dan gelen SettingsModel'i kullan
    _settings = widget.settings;
    // Sadece User ID'yi asenkron yükle
    _loadUserId();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final userId = await getOrCreateUserId();
    if (mounted) {
      setState(() {
        _userId = userId;
      });
    }
  }

  Future<void> _toggleLanguage() async {
    await _settings.toggleLanguage();
    setState(() {});
    widget.onLanguageChanged(_settings.currentLanguage);
  }

  Future<void> _changeWallpaper(String wallpaper) async {
    await _settings.setWallpaper(wallpaper);
    setState(() {});
    widget.onWallpaperChanged(wallpaper);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          // Arka planı PhoneHome'dan gelen duvar kağıdıyla senkron tut
          image: AssetImage('assets/wallpaper/${widget.wallpaper}'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    _settings.getText('settings'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // User ID Section (en üstte)
              _buildUserIdCard(),
              const SizedBox(height: 20),

              // Language Section
              _buildSettingCard(
                icon: Icons.language,
                title: _settings.getText('language'),
                subtitle: _settings.languageName,
                onTap: _toggleLanguage,
              ),
              const SizedBox(height: 20),

              // Alarm Sound Section
              _buildAlarmSoundSection(),
              const SizedBox(height: 20),

              // Pomodoro Duration Section
              _buildPomodoroDurationSection(),
              const SizedBox(height: 20),

              // Break Duration Section
              _buildBreakDurationSection(),
              const SizedBox(height: 20),

              // Wallpaper Section
              _buildWallpaperSection(),

              const SizedBox(height: 20),

              // Privacy Policy Section (en altta)
              _buildSettingCard(
                icon: Icons.privacy_tip,
                title: _settings.currentLanguage == 'en'
                    ? 'Privacy Policy'
                    : 'Gizlilik Politikası',
                subtitle: _settings.currentLanguage == 'en'
                    ? 'How we use your data'
                    : 'Verilerinizi nasıl kullanıyoruz',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PrivacyPolicyPage(
                        settings: _settings,
                        wallpaper: _settings.currentWallpaper,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80), // Bottom padding for navbar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 28),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildUserIdCard() {
    final isEnglish = _settings.currentLanguage == 'en';
    final shortId = _userId.length > 8
        ? '${_userId.substring(0, 8)}...'
        : _userId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
        title: Text(
          isEnglish ? 'Your Unique ID' : 'Özel Atanan ID',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          shortId,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
            fontFamily: 'monospace',
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy, color: Colors.white, size: 20),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _userId));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEnglish ? 'ID copied to clipboard' : 'ID panoya kopyalandı',
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlarmSoundSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _settings.getText('alarm_sound'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Alarm sound list
            ...(_settings.availableAlarmSounds.map((sound) {
              final soundId = sound['id']!;
              final soundName = sound['name']!;
              final isSelected = soundId == _settings.currentAlarmSound;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(
                    soundName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (soundId != SettingsModel.alarmNone)
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _previewSound(soundId),
                          tooltip: 'Preview',
                        ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                    ],
                  ),
                  onTap: () => _changeAlarmSound(soundId),
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Future<void> _changeAlarmSound(String soundId) async {
    await _settings.setAlarmSound(soundId);
    setState(() {});
  }

  Future<void> _previewSound(String soundId) async {
    try {
      final soundPath = 'sounds/$soundId';
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      // Ses dosyası yoksa kullanıcıya bildir
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _settings.currentLanguage == 'en'
                  ? 'Sound file not found'
                  : 'Ses dosyası bulunamadı',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildWallpaperSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wallpaper, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  _settings.getText('wallpaper'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Wallpaper Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: _settings.availableWallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = _settings.availableWallpapers[index];
                final isSelected = wallpaper == _settings.currentWallpaper;

                return GestureDetector(
                  onTap: () => _changeWallpaper(wallpaper),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/wallpaper/$wallpaper',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPomodoroDurationSection() {
    final List<int> availableMinutes = [15, 20, 25, 30, 45, 60];

    return _buildSettingCard(
      icon: Icons.timer,
      title: _settings.getText('pomodoro'),
      subtitle:
          '${_settings.selectedMinutes} ${_settings.currentLanguage == 'tr' ? 'dk' : 'min'}',
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[900]!,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings.getText('pomodoro'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ...availableMinutes.map((minutes) {
                  final isSelected = minutes == _settings.selectedMinutes;
                  return ListTile(
                    title: Text(
                      '$minutes ${_settings.currentLanguage == 'tr' ? 'dk' : 'min'}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () async {
                      await _settings.setSelectedMinutes(minutes);
                      if (!mounted || !context.mounted) return;
                      setState(() {});
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakDurationSection() {
    final List<int> availableBreakMinutes = [3, 5, 10, 15];

    return _buildSettingCard(
      icon: Icons.coffee,
      title: _settings.getText('break_time'),
      subtitle:
          '${_settings.breakMinutes} ${_settings.currentLanguage == 'tr' ? 'dk' : 'min'}',
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[900]!,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _settings.getText('break_time'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                ...availableBreakMinutes.map((minutes) {
                  final isSelected = minutes == _settings.breakMinutes;
                  return ListTile(
                    title: Text(
                      '$minutes ${_settings.currentLanguage == 'tr' ? 'dk' : 'min'}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () async {
                      await _settings.setBreakMinutes(minutes);
                      if (!mounted || !context.mounted) return;
                      setState(() {});
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
