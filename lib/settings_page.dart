import 'package:flutter/material.dart';
import 'settings_model.dart';

class SettingsPage extends StatefulWidget {
  final Function(String) onWallpaperChanged;
  final Function(String) onLanguageChanged;

  const SettingsPage({
    super.key,
    required this.onWallpaperChanged,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsModel _settings = SettingsModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.loadSettings();
    setState(() {
      _isLoading = false;
    });
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/wallpaper/${_settings.currentWallpaper}'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Padding(
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

              // Language Section
              _buildSettingCard(
                icon: Icons.language,
                title: _settings.getText('language'),
                subtitle: _settings.languageName,
                onTap: _toggleLanguage,
              ),
              const SizedBox(height: 20),

              // Wallpaper Section
              _buildWallpaperSection(),
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
}
