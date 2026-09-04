import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/l10n_extensions.dart';
import '../../core/network/providers.dart';
import '../../core/utils/support_pages.dart';
import '../../core/theme/app_theme.dart';
import 'analytics_consent.dart';

/// Cheia sub care ținem minte că userul a închis banda. Fără persistență, o
/// bandă care reapare la fiecare navigare face mai mult rău decât bine.
const _dismissedKey = 'android_install_banner_dismissed';

/// Numai pe web ȘI numai de pe Android: în aplicația nativă banda n-are sens,
/// iar pe desktop sau iPhone ar fi o reclamă la ceva ce vizitatorul nu poate
/// instala. Pe web `defaultTargetPlatform` reflectă sistemul vizitatorului,
/// deci nu avem nevoie să analizăm noi user agent-ul.
bool get canOfferAndroidInstall =>
    kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Bandă lipită jos care invită la instalarea aplicației de Android.
///
/// Deliberat NU arată ca o bandă de cookie-uri, deși sta în același loc:
/// iconiță, o singură linie de text, un singur buton principal și un „×"
/// discret - nu două butoane egale ca la Accept/Refuz. Banda de cookie-uri e
/// cel mai reflex-respins element din web; ce seamana cu ea primeste acelasi
/// reflex, inchis fara sa fie citit.
///
/// Inaltimea mica nu e doar estetica: Google penalizeaza in cautare
/// interstitialele intruzive pe mobil, iar o banda lipita e acceptata explicit
/// cat timp ocupa un spatiu rezonabil din ecran.
class AndroidInstallBanner extends ConsumerStatefulWidget {
  const AndroidInstallBanner({super.key});

  @override
  ConsumerState<AndroidInstallBanner> createState() => _AndroidInstallBannerState();
}

class _AndroidInstallBannerState extends ConsumerState<AndroidInstallBanner> {
  // null = încă nu știm (citim din storage). Nu randăm nimic în acest timp, ca
  // banda să nu clipească pe ecran înainte să aflăm că fusese închisă.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!canOfferAndroidInstall) {
      if (mounted) setState(() => _visible = false);
      return;
    }
    String? dismissed;
    try {
      dismissed = await ref.read(secureStorageProvider).read(key: _dismissedKey);
    } catch (_) {
      // Storage indisponibil (ex. navigare privată) - preferăm să o arătăm.
    }
    if (mounted) setState(() => _visible = dismissed == null);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      await ref.read(secureStorageProvider).write(key: _dismissedKey, value: '1');
    } catch (_) {
      // Dacă nu putem scrie, reapare la următoarea sesiune. Acceptabil.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    // Banda de consimțământ pentru analytics (web/index.html) e
    // `position: fixed; bottom`, deci plutește peste canvas-ul Flutter -
    // exact peste banda asta. Cât timp userul nu a răspuns la ea, ne dăm la o
    // parte; două benzi suprapuse jos nu se citesc nici una, nici alta.
    //
    // Verificat la fiecare build, nu o singură dată la montare: userul poate
    // răspunde la consimțământ cât timp e deja într-un ecran din shell, iar
    // banda trebuie să apară după aceea. E o singură citire din localStorage,
    // neglijabilă, și build-ul nu rulează la fiecare cadru.
    if (!analyticsConsentAnswered()) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Material(
      color: AppColors.card,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              // Nu folosim assets/icon/*.png: acele fișiere există doar
              // pentru generarea icoanelor native, nu sunt incluse în bundle
              // (`assets:` e comentat în pubspec), deci Image.asset ar eșua.
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.installBannerText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                // Aplicația e publicată, deci butonul duce direct în magazin,
                // nu la pagina de pre-înscriere.
                onPressed: () => openPlayStore(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  l10n.installBannerAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l10n.installBannerDismiss,
                visualDensity: VisualDensity.compact,
                color: AppColors.mutedForeground,
                onPressed: _dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pe desktop web nu are cine să instaleze un APK, dar vizitatorul are aproape
/// sigur un telefon Android în buzunar - deci acolo promovăm aplicația ca
/// „pune-o pe telefonul tău", nu ca „instalează acum".
///
/// Condiția e complementară cu `canOfferAndroidInstall`: exact una dintre cele
/// două e adevărată pe web, deci banda de jos și cardul din meniu nu apar
/// niciodată în același timp.
bool get canPromoteAndroidApp => kIsWeb && !canOfferAndroidInstall;

/// Card de promovare a aplicației de Android, pentru locurile unde o bandă
/// lipită jos ar fi nepotrivită.
///
/// Are exact două întrebuințări, iar `inSidebar` le distinge - toate celelalte
/// diferențe (cine îl vede, dacă se poate închide, unde duce butonul) decurg
/// din ea, deci nu le mai expunem ca parametri separați:
///
///  * `true` - în meniul din stânga, pe desktop. Îl vede doar cine NU e deja
///    pe Android (aceia primesc banda de jos) și se poate închide definitiv.
///  * `false` - pe pagina de creare a contului. O văd toți vizitatorii de web
///    și n-are „×" (pagina se vede o singură dată, n-are rost să consumăm
///    alegerea de „nu mai arăta").
///
/// Butonul duce în ambele cazuri la pagina din Google Play. Înainte mergea la
/// `/pre-register`, respectiv `/get-the-app` - ecrane de pre-înscriere, de pe
/// vremea când aplicația nu era încă publicată.
class AndroidInstallCard extends ConsumerStatefulWidget {
  const AndroidInstallCard({super.key, required this.inSidebar});

  final bool inSidebar;

  @override
  ConsumerState<AndroidInstallCard> createState() => _AndroidInstallCardState();
}

class _AndroidInstallCardState extends ConsumerState<AndroidInstallCard> {
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final applies = widget.inSidebar ? canPromoteAndroidApp : kIsWeb;
    if (!applies) {
      if (mounted) setState(() => _visible = false);
      return;
    }
    if (!widget.inSidebar) {
      if (mounted) setState(() => _visible = true);
      return;
    }
    String? dismissed;
    try {
      dismissed = await ref.read(secureStorageProvider).read(key: _dismissedKey);
    } catch (_) {
      // Storage indisponibil (navigare privată) - preferăm să-l arătăm.
    }
    if (mounted) setState(() => _visible = dismissed == null);
  }

  /// Aceeași cheie ca banda de jos: „nu mai vreau să văd asta" e un singur
  /// răspuns, indiferent pe ce dispozitiv l-a dat userul.
  Future<void> _dismiss() async {
    setState(() => _visible = false);
    try {
      await ref.read(secureStorageProvider).write(key: _dismissedKey, value: '1');
    } catch (_) {
      // Reapare la sesiunea următoare. Acceptabil.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    // Banda de consimțământ din web/index.html e `position: fixed; bottom`,
    // lată de max 560px și centrată - la lățimi de 900-1040px ajunge peste
    // colțul de jos al sidebar-ului, exact unde stă cardul. Cât timp userul
    // nu a răspuns, ne dăm la o parte.
    //
    // Doar în sidebar: pe pagina de înscriere cardul e conținut normal, în
    // fluxul unui scroll, iar ascunderea lui aici ar fi definitivă în
    // practică - un „Accept" în DOM nu declanșează un rebuild în Flutter, deci
    // cardul n-ar mai reapărea. Acolo e suficient că banda dispare singură
    // după răspuns și descoperă cardul de sub ea.
    if (widget.inSidebar && !analyticsConsentAnswered()) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    l10n.installCardTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (widget.inSidebar)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 15),
                    tooltip: l10n.installBannerDismiss,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    color: AppColors.mutedForeground,
                    onPressed: _dismiss,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.installCardText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            // Aplicația nu e încă în Play Store: pre-înscrierea e singurul
            // lucru care poate fi făcut acum. Cand ajunge in magazin, aici
            // intra linkul de Play.
            onPressed: () => openPlayStore(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              l10n.installCardAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
