import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale/l10n_extensions.dart';
import '../../core/network/providers.dart';
import '../../core/theme/app_theme.dart';

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
                onPressed: () {
                  // Aplicația nu e încă publică pe Play, deci trimitem spre
                  // pagina de pre-înscriere. Cand ajunge in magazin, aici intra
                  // linkul de Play.
                  context.push('/pre-register');
                },
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
