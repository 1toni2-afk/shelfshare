/**
 * `app-ads.txt` (standardul IAB) - declară public ce conturi AdMob au dreptul
 * să vândă reclame în aplicațiile care listează shelfshare.ro la „Website" în
 * Play Store. Crawler-ul AdMob îl cere fix din rădăcina domeniului.
 *
 * Stă aici, nu în fiecare server, fiindcă îl servesc amândouă:
 * static-server.js (Flutter, azi pe shelfshare.ro) și beta-server.js (React,
 * care preia domeniul la mutare). Fără el pe beta-server, mutarea ar fi scos
 * fișierul de pe domeniu, iar AdMob marchează aplicația ca neautorizată și
 * taie reclamele - fără nicio eroare vizibilă pe site.
 */
const APP_ADS_TXT = `google.com, pub-7014376175927154, DIRECT, f08c47fec0942fa0
`;

module.exports = { APP_ADS_TXT };
