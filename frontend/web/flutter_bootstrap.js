// Șablon pentru loader-ul Flutter. Fără acest fișier, `flutter build web`
// generează unul implicit; existența lui în `web/` îl înlocuiește, iar
// placeholderele de mai jos sunt completate la build (nu le atinge).
//
// Două abateri de la varianta implicită:
//
// 1. `canvasKitBaseUrl` - implicit, engine-ul cere canvaskit.js și
//    canvaskit.wasm de pe https://www.gstatic.com/flutter-canvaskit/<rev>/.
//    Măsurat în waterfall-ul de pornire: DNS + TLS + două fetch-uri către un
//    domeniu terț, pornite la ~990ms, exact peste descărcarea lui
//    main.dart.js. `flutter build web` copiază oricum aceleași fișiere în
//    build/web/canvaskit/, deci le servim de la noi: aceeași conexiune deja
//    deschisă, fără un al treilea domeniu pe calea critică, și versiunea
//    canvaskit rămâne mereu sincronă cu engine-ul cu care s-a compilat.
//
// 2. Fără `serviceWorkerSettings` - aplicația nu are mod offline, iar
//    index.html dezînregistrează activ orice service worker rămas (am avut
//    două runde de bug-uri cu versiuni vechi servite din cache). Loader-ul
//    implicit îl înregistra oricum, ceea ce însemna și o cerere în plus la
//    fiecare pornire.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
