import 'package:flutter/material.dart';
import 'settings_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Gizlilik metni: veri yalnızca cihazda ve (Android’de) telefon–saat arasında Google Wear Data Layer ile taşınır; harici API / sunucu yoktur.
class PrivacyPolicyPage extends StatelessWidget {
  final SettingsModel settings;
  final String wallpaper;

  const PrivacyPolicyPage({
    super.key,
    required this.settings,
    required this.wallpaper,
  });

  @override
  Widget build(BuildContext context) {
    final isEnglish = settings.currentLanguage == 'en';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/wallpaper/$wallpaper'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEnglish ? 'Privacy Policy' : 'Gizlilik Politikası',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection(
                          title: isEnglish
                              ? 'What data is stored'
                              : 'Hangi veriler saklanır',
                          content: isEnglish
                              ? 'The app stores Pomodoro-related information only on your device:\n\n• Completed work minutes and simple statistics (daily / monthly summaries)\n• Your timer preferences (duration, break length, language, wallpaper, alarm sound)\n\nThere is no user account, no advertising ID, and no UUID or “unique user id” collected for this app.'
                              : 'Uygulama yalnızca Pomodoro ile ilgili bilgileri cihazınızda saklar:\n\n• Tamamlanan çalışma dakikaları ve basit istatistikler (günlük / aylık özetler)\n• Zamanlayıcı tercihleriniz (süre, ara, dil, duvar kağıdı, alarm sesi)\n\nHesap yoktur, reklam kimliği toplanmaz; uygulama için UUID veya “benzersiz kullanıcı kimliği” tutulmaz.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish
                              ? '100% Offline & Standalone'
                              : '100% Çevrimdışı ve Bağımsız',
                          content: isEnglish
                              ? 'This app runs entirely on your local device. It does not connect to any external server, transfer data over the internet, or require any online accounts. Your data never leaves your device.'
                              : 'Bu uygulama tamamen yerel cihazınızda çalışır. Herhangi bir harici sunucuya bağlanmaz, internet üzerinden veri aktarmaz ve çevrimiçi hesap gerektirmez. Verileriniz asla cihazınızdan dışarı çıkmaz.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish
                              ? 'How we use your data'
                              : 'Verilerinizi nasıl kullanıyoruz',
                          content: isEnglish
                              ? 'Data is used only to run the timer and show statistics. We do not sell data, share it with third parties, or use it for advertising.'
                              : 'Veriler yalnızca zamanlayıcıyı çalıştırmak ve istatistikleri göstermek için kullanılır. Verilerinizi satmıyor, üçüncü taraflarla paylaşmıyor ve reklam için kullanmıyoruz.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish ? 'Data deletion' : 'Veri silme',
                          content: isEnglish
                              ? 'Uninstalling the app removes its local data from your device. We do not retain copies on our servers (there is no central server for this product).'
                              : 'Uygulamayı kaldırmak, o cihazdaki yerel verileri tamamen siler. Merkezi bir sunucuda kopya tutulmaz (böyle bir sunucu yoktur).',
                        ),
                        const SizedBox(height: 20),
                        // Tıklanabilir İletişim Bölümü
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEnglish ? 'Contact' : 'İletişim',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final Uri emailLaunchUri = Uri(
                                  scheme: 'mailto',
                                  path: 'nmustafa.ozkaya@gmail.com',
                                  queryParameters: {'subject': 'Pomodoro - Destek Talebi'},
                                );
                                try {
                                  await launchUrl(emailLaunchUri);
                                } catch (_) {}
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.email, color: Colors.blue, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEnglish
                                          ? 'Email: nmustafa.ozkaya@gmail.com'
                                          : 'E-Posta: nmustafa.ozkaya@gmail.com',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final Uri url = Uri.parse('https://mustafaozkaya.com');
                                try {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                } catch (_) {}
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.language, color: Colors.blue, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      isEnglish
                                          ? 'Website: mustafaozkaya.com'
                                          : 'Web Sitesi: mustafaozkaya.com',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEnglish
                                  ? 'Developer: Mustafa Özkaya'
                                  : 'Geliştirici: Mustafa Özkaya',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            String version = '1.1.4';
                            if (snapshot.hasData) {
                              version = snapshot.data!.version;
                            }
                            return Center(
                              child: Text(
                                isEnglish
                                    ? 'Version: v$version'
                                    : 'Sürüm: v$version',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
