# Uitvoeringsplan — Roulette Lab Offline

## Doel

Een releasewaardige, volledig offline Flutter-app voor Europese single-zero roulette bouwen. De app bewaart handmatig ingevoerde historie lokaal, analyseert die zonder winstclaims, maakt twee deterministische experimentele voorspellingen, evalueert die walk-forward en biedt betrouwbare lokale back-up en herstel.

## Uitgangspunten

- Flutter 3.35.6 / Dart 3.9.2; Android, Windows en Web als ondersteunde targets.
- Pure Dart-domeinlogica, Material 3 UI, Riverpod voor state en dependency injection.
- SQLite als bron van waarheid; voorkeuren apart in `shared_preferences`.
- Geen netwerkcode, accounts, telemetry, remote assets of runtime-downloads.
- Chronologische historie is leidend. Elke mutatie invalideert afhankelijke voorspellingen en herbouwt afgeleide staat deterministisch.
- Kansverdelingen zijn altijd genormaliseerd, eindig en defensief teruggevallen naar uniform.

## Fasen en afhankelijkheden

- [x] 1. Projectfundament
  - Flutter-project voor Android en Windows aanmaken.
  - Strikte analyse-instellingen, dependencies, lokalisatiebasis en mappenstructuur configureren.
  - Android release zonder `INTERNET`-permissie en zonder cloud-back-up configureren.
- [x] 2. Domein en wiskunde
  - Roulette-eigenschappen, fysieke wielafstanden, statistiek, hashing, kansnormalisatie en scores implementeren.
  - Spins, voorspellingen, evaluaties en instellingen als immutable domeintypen modelleren.
- [x] 3. Modellen en validatie
  - Wielafstand-model met suffix-, fuzzy-, periodiciteits-, transition- en decayed-prior-experts bouwen.
  - Adaptief ensemble met zeven verklaarbare experts, smoothing, Hedge en sample-shrinkage bouwen.
  - Walk-forward evaluator, uniforme baseline, rolling metrics en anti-leakage-waarborg implementeren.
- [x] 4. Lokale gegevenslaag
  - SQLite schema v1, migratiepad, repository-implementaties en transacties toevoegen.
  - Prediction snapshots, automatische evaluatie, invalidatie na edit/delete/import en herbouw implementeren.
  - Voorkeuren, JSON/CSV-export, flexibele importparser en importpreview bouwen.
- [x] 5. Product-UI
  - Responsieve navigatieshell en dashboard op telefoon/tablet/desktop bouwen.
  - Bordmodi, numerieke snelinvoer, geschiedenis-CRUD/undo, analysekaarten en getaldetails integreren.
  - Beide voorspellingkaarten, volledige verdeling, uitleg en evaluatiestatus integreren.
  - Analyse-, modelprestatie- en instellingenpagina's volledig functioneel maken.
- [x] 6. UX, toegankelijkheid en prestaties
  - Semantics, toetsenbord/focus, hover, minimaal 48×48 doelen, 200% tekstschaal en fout/lege/loading-states controleren.
  - Lijsten virtualiseren; zware modelherbouw boven de drempel buiten de UI-isolate uitvoeren en stale resultaten verwerpen.
- [x] 7. Verificatie
  - Unit-, propertyachtige, repository-, widget- en integratietests uitvoeren.
  - Edge cases voor lege/korte/lange/repetitieve historie, snelle invoer en corrupte import afdekken.
  - Formatter, analyzer, tests, Android release en Windows release uitvoeren waar de toolchain dit toelaat.
- [x] 8. Oplevering
  - Nederlandstalige README, algoritme-, dataformaat- en privacy-documentatie, changelog en VS Code-configuratie afronden.
  - Eigen lokale app-identiteit toevoegen en alle acceptatiecriteria nalopen.
- [x] 9. Web en GitHub Pages
  - Webdatabase via SQLite/Wasm en IndexedDB toevoegen zonder domeinlogica te
    dupliceren.
  - Zware berekeningen naar een Web Worker verplaatsen en de responsive shell
    voor compacte browsers verfijnen.
  - Lokale fonts/assets, PWA-manifest, custom offline-service-worker en
    custom-domainconfiguratie toevoegen.
  - Reproduceerbare GitHub Pages-workflow met format, analyze, tests,
    artifactcontroles en deployment toevoegen.

## Belangrijkste risico's en beheersing

- **Look-ahead bias:** ieder backtestpunt ontvangt uitsluitend een onveranderlijke prefix; regressietests bewaken prefix-invariantie.
- **Dataintegriteit bij mutaties:** één mutation-controller en databasetransacties verzorgen herindexering, evaluatie en invalidatie.
- **Numerieke instabiliteit:** centrale normalisatie, epsilon-clamping en propertytests op eindigheid, bereik en som.
- **Trage herbouw bij grote historie:** pure functies, incrementeel waar veilig,
  isolate/Web Worker vanaf 500 spins en generation-token tegen stale resultaten.
- **Responsieve overflow:** expliciete widgettests op 360×800, 800×600 en 1440×900 plus 200% tekstschaal.
- **Windows buildomgeving:** `flutter doctor` meldt ontbrekende C++ workload-componenten; alle andere checks blijven verplicht en het exacte bouwresultaat wordt gedocumenteerd.
- **Native bestandsdialogen in tests:** parser/serializer en services volledig unit-testen; device-integratie gebruikt echte dialogen alleen waar automatiseerbaar.

## Acceptatiecriteria

- Alle 22 criteria uit het masterdocument zijn geïmplementeerd of aantoonbaar door lokale tooling geblokkeerd.
- `flutter analyze` en `flutter test` zijn groen.
- De Android release-build slaagt en bevat geen onnodige netwerkpermissie.
- De Windows release-build wordt uitgevoerd; bij de bekende ontbrekende Visual Studio-componenten wordt de exacte fout vastgelegd.
- Geen tijdelijke taakmarkeringen, nepdata, dode bediening of misleidende claims in de oplevering.

## Gerealiseerde verificatie

- `dart format --set-exit-if-changed .`: geslaagd.
- `flutter analyze`: geslaagd, geen issues.
- `flutter test`: 31 tests geslaagd, inclusief 10.000-spinmodellen, 10.000-spin-DB-import en 2.000-spin walk-forward.
- `flutter test integration_test -d emulator-5554`: geslaagd op Android 17-emulator, inclusief herstartpersistentie.
- `flutter build apk --release`: geslaagd; manifest gecontroleerd zonder `INTERNET`.
- `flutter build windows --release`: uitgevoerd, maar lokaal geblokkeerd doordat de Visual Studio-installatie de C++ desktopworkload/CMake/Windows SDK-componenten mist.
- Flutter Web-productiebouw met root-base, SQLite/Wasm, modelworker en
  versioned offlinecache: geslaagd.
- Chrome end-to-endtest: geslaagd, inclusief databaseheropening en
  import/export-roundtrip.
- Edge releasecontrole: geslaagd voor desktop en compact formaat; IndexedDB
  bleef na een nieuwe browsersessie behouden en de app startte zonder netwerk
  vanuit de service-workercache.
