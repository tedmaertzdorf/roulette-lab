# Roulette Lab Offline

Roulette Lab Offline is een persoonlijke Flutter-app voor lokale analyse van handmatig ingevoerde uitkomsten van Europese single-zero roulette (0–36). De app bewaart data op het apparaat, toont transparante statistiek, maakt twee experimentele modelverdelingen en vergelijkt die via officiële volgende-draaiscores en een walk-forward backtest met uniform toeval.

> **Verantwoord gebruik:** bij een eerlijk roulettespel zijn draaien onafhankelijk. Historische patronen geven geen winstgarantie. De app geeft geen inzet-, bankroll- of verliesachtervolgingsadvies.

## Functies

- correct Europees tafelbord en fysieke wielvolgorde;
- invoer- en analysemodus, numerieke desktopinvoer en geldige herhalingen;
- persistente, virtuele historie met edit, delete, undo en instelbare volgorde;
- vensters 5/10/20/30, kleur, parity, hoog/laag, kolommen en nul;
- getalfrequentie, posities, gaps, voorgangers, opvolgers en wielburen;
- automatische opvolgersamenvatting na iedere nieuwe invoer, met recente
  volgorde en frequentieverdeling;
- live patroonherkenning voor getalcycli, afwisselingen, reeksen en fysieke
  wielstappen, met conservatieve bewijssterkte en automatische herberekening;
- deterministisch wielafstand-model met vijf experts;
- deterministisch adaptief ensemble met zeven experts en online Hedge-gewichten;
- actieve snapshots voor precies de volgende draai, log-loss en Brier-score;
- incrementele walk-forwardtest zonder look-ahead en uniforme baseline;
- platformonafhankelijke SQLite-opslag: native database op Android/Windows en
  SQLite/Wasm in IndexedDB op Web;
- JSON-back-up, CSV-export en preview voor JSON/CSV/TXT-import;
- responsieve Material 3-interface voor telefoon, tablet, laptop en desktop;
- donker, licht en systeemthema; toetsenbord, hover en Nederlandse semantics.

## Vereisten

- Flutter 3.35.6 of een compatibele nieuwere stabiele versie;
- Dart 3.9.2 of compatibel;
- Android SDK voor Android-builds;
- Visual Studio met **Desktop development with C++**, CMake-tools en Windows SDK voor Windows-builds.
- Chrome of Edge voor Flutter Web.

Controleer de omgeving:

```powershell
flutter doctor -v
flutter devices
```

## Installeren en draaien

```powershell
flutter pub get
flutter run -d emulator-5554
```

Voor Web tijdens ontwikkeling:

```powershell
flutter run -d chrome
```

In VS Code kun je via **Run and Debug** kiezen uit `Roulette Lab · Android` en `Roulette Lab · Windows`. De meegeleverde taken voeren formattering, analyse, tests en releasebuilds uit.

## Kwaliteitschecks

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test -d emulator-5554
```

De tests omvatten roulette-eigenschappen, numerieke stabiliteit, beide modellen, anti-leakage, SQLite CRUD/migratie, import/export, responsieve widgets, 200% tekstschaal, de prediction lifecycle en herstartpersistentie.

## Release bouwen

Android APK:

```powershell
flutter build apk --release
```

Resultaat: `build/app/outputs/flutter-apk/app-release.apk`.

Windows:

```powershell
flutter build windows --release
```

Resultaat: `build/windows/x64/runner/Release/roulette_lab.exe` plus de naastgelegen DLL- en datamappen. Verspreid de volledige `Release`-map, niet alleen het exe-bestand.

Web voor hosting op het custom domein:

```powershell
flutter build web --release --base-href / --pwa-strategy none
dart compile js -O4 --no-source-maps -o build/web/model_worker.js tool/model_worker.dart
dart run tool/generate_web_service_worker.dart
```

Resultaat: een zelfstandig, offline-capabel artifact in `build/web`. De custom
service worker vervangt Flutter's verouderde automatisch gegenereerde worker en
cachet alle lokale appbestanden na de eerste volledige online laadbeurt.

## Back-up en herstel

Open het menu rechtsboven of **Instellingen → Databeheer**:

- **JSON-back-up exporteren** bewaart spins, instellingen, modelversies en officiële predictionrecords;
- **CSV exporteren** schrijft positie, nummer en optioneel UTC-tijdstip;
- **Data importeren** toont eerst geldige/ongeldige regels en biedt toevoegen of expliciet bevestigd vervangen.

JSON/CSV-details staan in [docs/DATA_FORMAT.md](docs/DATA_FORMAT.md).

## Offline en privacy

Er is geen backend, account, cloud, Firebase, telemetry, advertentie, online font
of externe runtime-netwerkcall. De webapp haalt uitsluitend eigen statische
bestanden van dezelfde origin op. Het Android releasemanifest heeft geen
`INTERNET`-permissie en cloud-back-up is uitgeschakeld. Handmatige export is de
enige gegevensoverdracht. Zie [docs/PRIVACY.md](docs/PRIVACY.md).

## Architectuur

- `lib/domain`: pure Dart-entities, statistiek, prediction engines en evaluatie;
- `lib/data`: SQLite schema/repository, voorkeuren en import/export;
- `lib/app`: providers, centrale mutationflow, platformuitvoering, navigatie en appstart;
- `lib/features`: dashboard, historie, analyse, predictions, prestatie en instellingen;
- `lib/core`: rouletteconstanten, kansrekenen, hashing, thema, teksten en widgets.

Riverpod verzorgt state/dependency injection. De SQLite-repository is de bron
van waarheid op alle platformen. Alle historiewijzigingen lopen door één
geserialiseerde controller. Zware modelberekeningen vanaf 500 spins draaien
native in een isolate en op Web in een Web Worker; resultaten worden alleen
opgeslagen als hun bronfingerprint nog actueel is.

## Webdeployment

Een push naar `main` activeert `.github/workflows/deploy-pages.yml`. De workflow
formatteert, analyseert en test de app, bouwt het root-hosted productieartifact,
compileert de modelworker, maakt de offlinecache en publiceert via GitHub Pages.
De domeinnaam, DNS-waarde, Pages-instellingen en verificatiestappen staan in
[docs/WEB_DEPLOYMENT.md](docs/WEB_DEPLOYMENT.md).

De volledige modelbeschrijving staat in [docs/ALGORITHMS.md](docs/ALGORITHMS.md). Projectregels en acceptatiecriteria staan in [AGENTS.md](AGENTS.md) en [PLAN.md](PLAN.md).
