# Repositoryrichtlijnen

## Structuur

- `lib/core`: constante, wiskunde, thema, lokalisatie en gedeelde widgets.
- `lib/domain`: Flutter-onafhankelijke entities, repositorycontracten en services/modellen.
- `lib/data`: SQLite, voorkeuren, repositories en import/export.
- `lib/features`: dashboard, historie, analyse, voorspelling, prestatie en instellingen.
- `test`: unit-, repository- en widgettests; `integration_test`: hoofdflow.
- `docs`: algoritmen, dataformaat en privacy.

## Architectuurregels

- De domeinlaag importeert geen Flutter- of databasepackages.
- UI bevat geen model- of persistentielogica; controllers/services verzorgen mutaties.
- Historie is chronologisch en immutable aan modelgrenzen.
- Alleen centrale rouletteconstanten en kansnormalisatie gebruiken.
- Alle historie-mutaties lopen via één transactionele flow en invalidatiebeleid.
- Nieuwe zichtbare tekst komt uit de centrale Nederlandstalige tekstlaag.
- Geen netwerk-, cloud-, analytics- of remote-assetdependency toevoegen.

## Kwaliteitscommando's

```powershell
dart format --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
flutter test integration_test -d emulator-5554
flutter build apk --release
flutter build windows --release
```

## Definitie van klaar

Een wijziging is klaar als de volledige verticale flow werkt, fout- en lege staten zijn afgehandeld, relevante tests zijn toegevoegd, format/analyze/test groen zijn en er geen tijdelijke taakmarkeringen, placeholders, dode knoppen of onterechte winstclaims achterblijven. Release-builds worden uitgevoerd voor iedere lokaal beschikbare toolchain.
