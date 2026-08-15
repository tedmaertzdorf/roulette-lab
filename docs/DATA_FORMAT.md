# Dataformaat

## JSON-back-up (schema 1)

UTF-8 JSON met dit hoofdobject:

```json
{
  "schemaVersion": 1,
  "appVersion": "1.0.0",
  "exportedAtUtc": "2026-08-15T12:00:00.000Z",
  "modelVersions": {
    "wheel_distance": 1,
    "adaptive_ensemble": 1
  },
  "settings": {},
  "spins": [],
  "predictions": []
}
```

Een draai bevat `position`, `number`, optioneel `occurredAtUtc` en de UTC-velden `createdAtUtc` en `updatedAtUtc`. `number` is een integer 0–36; dubbele nummers zijn geldig. Voorspellingen bevatten engine/modelversie, fingerprint, targetpositie, status, top 3, de volledige 37-delige verdeling, vier geaggregeerde dozijn/0-scores, diagnostics, expertgewichten en eventuele evaluatiescores.

Import ondersteunt schema 1. Een hogere onbekende schemaversie wordt geweigerd om stil dataverlies te voorkomen. Ongeldige draaien worden met hun regel/index gemeld in de preview. Een vervangende import gebruikt één databasetransactie.

## CSV-export

UTF-8 met CRLF-regels:

```csv
position,number,occurred_at_utc
1,8,2026-08-15T12:00:00.000Z
2,8,
3,0,2026-08-15T12:01:00.000Z
```

De import herkent een header met `number` of `nummer`, en komma, puntkomma of tab als delimiter. Zonder header mogen één of meerdere nummers per regel staan. Spaties en lege regels worden genegeerd; alleen gehele waarden 0–36 zijn geldig.

## Importgedrag

- **Toevoegen:** behoudt bestaande historie; een actieve voorspelling wordt op het eerste geïmporteerde nummer geëvalueerd.
- **Vervangen:** vereist extra bevestiging; spins en eventuele predictionrecords uit een JSON-back-up worden transactioneel hersteld.
- Fouten worden vóór schrijven getoond. Een fatale parsefout schrijft niets.
