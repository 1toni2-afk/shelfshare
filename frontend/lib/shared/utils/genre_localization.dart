import 'package:flutter/widgets.dart';
import '../../core/locale/l10n_extensions.dart';

/// `books.genre` e text liber în română (vezi BOOK_GENRES pe backend) - lista
/// oferită în UI e fixă, dar câmpul din DB rămâne text liber ca să nu limităm
/// cărțile importate din surse externe. Localizăm doar AFIȘAREA pentru cele
/// din lista cunoscută; un gen necunoscut (import extern) rămâne cum e, ca să
/// nu inventăm o traducere pentru text arbitrar.
String localizedGenre(BuildContext context, String genre) {
  final l10n = context.l10n;
  switch (genre) {
    case 'Ficțiune':
      return l10n.genreFiction;
    case 'Non-ficțiune':
      return l10n.genreNonFiction;
    case 'Clasic':
      return l10n.genreClassic;
    case 'Clasic românesc':
      return l10n.genreRomanianClassic;
    case 'Fantasy':
      return l10n.genreFantasy;
    case 'SF':
      return l10n.genreSciFi;
    case 'Thriller':
      return l10n.genreThriller;
    case 'Mister':
      return l10n.genreMystery;
    case 'Distopie':
      return l10n.genreDystopia;
    case 'Romantic':
      return l10n.genreRomance;
    case 'Istoric':
      return l10n.genreHistorical;
    case 'Biografie':
      return l10n.genreBiography;
    case 'Dezvoltare personală':
      return l10n.genreSelfHelp;
    case 'Psihologie':
      return l10n.genrePsychology;
    case 'Filosofie':
      return l10n.genrePhilosophy;
    case 'Business':
      return l10n.genreBusiness;
    case 'Poezie':
      return l10n.genrePoetry;
    case 'Copii':
      return l10n.genreChildren;
    case 'Young adult':
      return l10n.genreYoungAdult;
    case 'Benzi desenate':
      return l10n.genreComics;
    default:
      return genre;
  }
}
