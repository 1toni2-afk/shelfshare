import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const _faqs = [
    (
      'Cum funcționează un schimb de cărți?',
      'Ceri o carte din anunțul altcuiva (poți oferi și tu o carte în schimb), '
          'proprietarul acceptă sau refuză, apoi vă stabiliți o întâlnire prin chat. '
          'După ce faceți schimbul în realitate, oricare dintre voi marchează schimbul ca finalizat.',
    ),
    (
      'Ce e Scorul de încredere?',
      'Un indicator 0-100 calculat automat din activitatea din aplicație: vechimea contului, '
          'email verificat, câte schimburi ai finalizat, rating-ul primit, cât de des răspunzi și cât de rar '
          'anulezi cereri. Nu e o verificare de identitate, doar un semnal de comportament.',
    ),
    (
      'Cum se calculează prețul „din librării"?',
      'Când adaugi o carte cu ISBN, încercăm să găsim prețul de listă pe Google Books. Acoperirea e parțială - '
          'nu toate cărțile au preț disponibil acolo, mai ales edițiile mai vechi sau românești.',
    ),
    (
      'Ce înseamnă NENEGOCIABIL?',
      'Dacă cel care vinde o carte bifează asta, cumpărătorii nu mai pot trimite oferte de preț - '
          'cartea se cumpără doar la prețul afișat.',
    ),
    (
      'Cum raportez sau blochez un utilizator?',
      'Din meniul din colțul din dreapta sus al unei conversații, sau din pagina de detalii a unui anunț '
          '(iconița de steag). Blocarea oprește mesajele în ambele direcții.',
    ),
    (
      'Ce se întâmplă cu cartea după ce o vând sau o dau la schimb?',
      'Anunțul devine indisponibil definitiv. Dacă persoana care a primit-o vrea să o listeze mai departe, '
          'poate face asta din ecranul de Schimburi/Oferte ("Adaugă în biblioteca ta") - istoricul cărții rămâne '
          'urmăribil pe pagina ei de detalii, cu poze puse de fiecare proprietar.',
    ),
    (
      'De ce nu-mi apare o carte în Categorii sau la Cărți similare?',
      'Genul unei cărți vine din Open Library sau Google Books la adăugare - unele cărți nu au gen completat '
          'în sursele externe, mai ales edițiile mai puțin populare.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Întrebări frecvente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (question, answer) in _faqs)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(question, style: Theme.of(context).textTheme.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Nu ai găsit răspunsul? Poți raporta o problemă direct din conversația cu utilizatorul implicat.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
