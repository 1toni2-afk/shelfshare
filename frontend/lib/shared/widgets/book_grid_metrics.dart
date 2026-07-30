/// Metricile grilei de cărți, partajate între Home, Discover și Raftul meu, ca
/// toate ecranele să arate identic. Înainte, Raftul meu folosea un `Wrap` cu
/// cardul fixat la 160dp: pe un telefon de 360dp rămâneau 328dp utili, iar
/// 160+16+160 = 336 > 328, așa că încăpea o singură carte pe rând și toată
/// lista cădea pe o coloană lipită de marginea stângă.
library;

/// 220 e ales ca orice telefon să rămână pe 2 coloane: la 430dp (cel mai lat
/// telefon uzual) rămân 398dp utili, iar 398/220 se rotunjește tot la 2. Cu
/// 190 ar fi ieșit 3 coloane pe telefoanele late.
const kBookCardMaxWidth = 220.0;

/// Înălțimea celulei = lățime / raport. Coperta e 2:3 (deci 1.5×lățime), plus
/// ~62dp pentru titlu + autor + oraș. La 156dp lățime (telefon, 2 coloane)
/// conținutul cere ~296dp, iar 0.50 dă 312dp - marjă suficientă cât să nu
/// apară overflow, fără spațiu gol vizibil.
const kBookCardAspectRatio = 0.50;

const kBookGridMainAxisSpacing = 20.0;
const kBookGridCrossAxisSpacing = 16.0;
