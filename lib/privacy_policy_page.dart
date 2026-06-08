import 'package:flutter/material.dart';
import 'settings_model.dart';

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
                              ? 'The app stores Pomodoro-related information only on your devices:\n\n• Completed work minutes and simple statistics (daily / monthly summaries)\n• Your timer preferences (duration, break length, language, wallpaper, alarm sound)\n\nThere is no user account, no advertising ID, and no UUID or “unique user id” collected for this app.'
                              : 'Uygulama yalnızca Pomodoro ile ilgili bilgileri cihazlarınızda saklar:\n\n• Tamamlanan çalışma dakikaları ve basit istatistikler (günlük / aylık özetler)\n• Zamanlayıcı tercihleriniz (süre, ara, dil, duvar kağıdı, alarm sesi)\n\nHesap yoktur, reklam kimliği toplanmaz; uygulama için UUID veya “benzersiz kullanıcı kimliği” tutulmaz.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish
                              ? 'Phone and watch (Android)'
                              : 'Telefon ve saat (Android)',
                          content: isEnglish
                              ? 'On Android, paired phone and Wear OS watch exchange data through Google’s Wearable Data Layer (session minutes, totals, timer settings). This link is between your own devices over Google Play services—not through our servers, because we do not operate a backend API for this app.'
                              : 'Android’de eşleşmiş telefon ve Wear OS saat, Google Wearable Data Layer üzerinden (oturum dakikaları, toplamlar, zamanlayıcı ayarları) veri alışverişi yapar. Bu bağlantı kendi cihazlarınız ve Google Play hizmetleri arasındadır; uygulamanın harici bir API sunucusu yoktur.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish
                              ? 'How we use your data'
                              : 'Verilerinizi nasıl kullanıyoruz',
                          content: isEnglish
                              ? 'Data is used only to run the timer, show statistics, and keep phone and watch in sync when you use both. We do not sell data, share it with third parties, or use it for advertising.'
                              : 'Veriler yalnızca zamanlayıcıyı çalıştırmak, istatistikleri göstermek ve telefon ile saati birlikte kullandığınızda eşitlemek için kullanılır. Verilerinizi satmıyor, üçüncü taraflarla paylaşmıyor ve reklam için kullanmıyoruz.',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish ? 'Data deletion' : 'Veri silme',
                          content: isEnglish
                              ? 'Uninstalling the app removes its local data from that device. To clear statistics inside the app, use any clear-stats option if provided in a future update, or reinstall. We do not retain copies on our servers (there is no central server for this product).'
                              : 'Uygulamayı kaldırmak, o cihazdaki yerel verileri siler. İstatistikleri uygulama içinden temizlemek için (ileride eklenirse) ilgili seçeneği kullanabilir veya uygulamayı yeniden kurabilirsiniz. Merkezi bir sunucuda kopya tutulmaz (böyle bir sunucu yoktur).',
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          title: isEnglish ? 'Contact' : 'İletişim',
                          content: isEnglish
                              ? 'Questions about this policy: nmustafa.ozkaya@gmail.com\nDeveloper: NMO Dev'
                              : 'Bu politika hakkında sorular: nmustafa.ozkaya@gmail.com\nGeliştirici: NMO Dev',
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            isEnglish
                                ? 'Last updated: May 2026'
                                : 'Son güncelleme: Mayıs 2026',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
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
