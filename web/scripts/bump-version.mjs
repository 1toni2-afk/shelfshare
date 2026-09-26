/**
 * Ridică versiunea aplicației într-un singur pas.
 *
 * Sursa unică e web/package.json: `version` (versionName, afișat în Setări)
 * și `versionCode` (numărul pe care îl verifică Play). Gradle și Vite le
 * citesc direct de acolo; scriptul le copiază doar acolo unde nu se poate
 * citi din alt fișier: package-lock.json și pubspec.yaml-ul aplicației Flutter,
 * care împarte același slot pe Play.
 *
 * Usage (din web/):
 *   npm run bump                 # doar versionCode + 1 (un nou AAB, aceeași versiune)
 *   npm run bump -- patch        # 2.0.0 -> 2.0.1, versionCode + 1
 *   npm run bump -- minor        # 2.0.0 -> 2.1.0, versionCode + 1
 *   npm run bump -- major        # 2.0.0 -> 3.0.0, versionCode + 1
 *   npm run bump -- 2.3.1        # versiune exactă, versionCode + 1
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const pkgPath = resolve(webDir, 'package.json');
const lockPath = resolve(webDir, 'package-lock.json');
const pubspecPath = resolve(webDir, '..', 'frontend', 'pubspec.yaml');

const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
const arg = process.argv[2];

const [major, minor, patch] = pkg.version.split('.').map(Number);
let version = pkg.version;
if (arg === 'major') version = `${major + 1}.0.0`;
else if (arg === 'minor') version = `${major}.${minor + 1}.0`;
else if (arg === 'patch') version = `${major}.${minor}.${patch + 1}`;
else if (arg && /^\d+\.\d+\.\d+$/.test(arg)) version = arg;
else if (arg) {
  console.error(`Argument necunoscut: ${arg}. Foloseste patch, minor, major sau X.Y.Z.`);
  process.exit(1);
}
const versionCode = pkg.versionCode + 1;

// Înlocuire pe text, nu JSON.stringify: păstrează formatarea și ordinea cheilor.
const setField = (text, field, value, count) => {
  let left = count;
  return text.replace(new RegExp(`"${field}": [^,\\r\\n]+`, 'g'), (match) =>
    left-- > 0 ? `"${field}": ${JSON.stringify(value)}` : match,
  );
};

writeFileSync(
  pkgPath,
  setField(setField(readFileSync(pkgPath, 'utf8'), 'version', version, 1), 'versionCode', versionCode, 1),
);
// Primele două apariții: rădăcina și packages[""]. Restul sunt dependențe.
writeFileSync(lockPath, setField(readFileSync(lockPath, 'utf8'), 'version', version, 2));

// `[^\r\n]`, nu `.`: pe Windows fișierul poate avea CRLF, iar `.` ar înghiți `\r`.
const pubspecVersion = /^version: [^\r\n]+/m;
const pubspec = readFileSync(pubspecPath, 'utf8');
if (!pubspecVersion.test(pubspec)) {
  console.error('Nu gasesc linia `version:` in frontend/pubspec.yaml.');
  process.exit(1);
}
writeFileSync(pubspecPath, pubspec.replace(pubspecVersion, `version: ${version}+${versionCode}`));

console.log(`${pkg.version} (${pkg.versionCode}) -> ${version} (${versionCode})`);
