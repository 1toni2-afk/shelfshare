import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  static const _tips = [
    (
      Icons.wb_sunny_outlined,
      'Întâlnește-te ziua',
      'Programează schimbul într-un interval orar cu lumină naturală, ideal dimineața sau după-amiaza.',
    ),
    (
      Icons.storefront_outlined,
      'Alege un loc public',
      'O cafenea, o librărie sau un mall sunt variante mai sigure decât adresa personală a cuiva.',
    ),
    (
      Icons.videocam_outlined,
      'Preferă locații cu supraveghere video',
      'Zonele cu camere de securitate descurajează comportamentul neplăcut.',
    ),
    (
      Icons.privacy_tip_outlined,
      'Nu distribui date personale',
      'Nu ai nevoie să dai adresa de acasă, CNP sau alte date sensibile ca să faci un schimb.',
    ),
    (
      Icons.star_outline,
      'Verifică rating-ul și scorul de încredere',
      'Un istoric bun de schimburi finalizate e un semn bun înainte să te întâlnești cu cineva.',
    ),
    (
      Icons.face_outlined,
      'O poză de profil reală crește încrederea',
      'Profilurile cu poză și bio completă inspiră mai multă siguranță celorlalți utilizatori.',
    ),
    (
      Icons.menu_book_outlined,
      'Verifică starea cărții înainte de schimb',
      'Compară cartea cu descrierea din anunț înainte să confirmi schimbul ca finalizat.',
    ),
    (
      Icons.flag_outlined,
      'Raportează orice comportament suspect',
      'Poți raporta sau bloca un utilizator direct din profilul lui sau din conversație.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centru de siguranță')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Câteva reguli simple ca schimburile prin ShelfShare să fie plăcute și sigure.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            for (final (icon, title, description) in _tips)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(icon, color: AppColors.accent),
                  title: Text(title, style: Theme.of(context).textTheme.titleSmall),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(description),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
