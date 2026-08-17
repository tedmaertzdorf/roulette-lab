# Changelog

## 1.3.0 — 2026-08-17

- Een live patroonherkenner als afzonderlijke dashboardkaart toegevoegd.
- Detectie van herhalende getalcycli, categorie-afwisselingen, actuele reeksen
  en terugkerende fysieke wielstappen geïmplementeerd.
- Signalen worden na iedere draai opnieuw berekend over maximaal 120 recente
  resultaten en verdwijnen direct wanneer het patroon wordt doorbroken.
- Conservatieve bewijsdrempels, begrijpelijke uitleg en een expliciete
  onafhankelijkheidswaarschuwing voorkomen dat toevalsruis als kans wordt
  gepresenteerd.
- Patroonanalyse voor weinig data, grote historie en responsieve browsers
  getest.

## 1.2.0 — 2026-08-16

- Automatische opvolgerkaart direct onder het invoerbord toegevoegd.
- Na iedere ingevoerde draai verschijnen de recente historische opvolgers van
  dat getal en de meest voorkomende opvolgers met aantallen en percentages.
- Eerste voorkomens, de nog openstaande huidige opvolger en grote aantallen
  unieke opvolgers hebben een compacte, responsieve staat gekregen.
- Rechtstreekse navigatie naar de volledige getaldetails toegevoegd.
- Automatische opvolgerweergave getest op desktop en kleine browsers.

## 1.1.0 — 2026-08-15

- Volledige Flutter Web-ondersteuning voor Chrome en Edge toegevoegd.
- SQLite/Wasm-opslag via IndexedDB met dezelfde repository en transacties als
  Android en Windows geïmplementeerd.
- Zware voorspellingen en backtests draaien op Web in een afzonderlijke worker.
- Responsive navigatie en compacte browserlay-out verbeterd.
- Alle fonts, iconen, CanvasKit-assets en fallbacks lokaal gebundeld; geen
  analytics, tracking of externe runtime-resources.
- Versioned offlinecache en PWA-installatie na de eerste online laadbeurt
  toegevoegd.
- GitHub Pages Actions-workflow voor root-hosting op
  `roulette.tedware.nl` toegevoegd.
- Chrome end-to-end, Edge release/offline/herstart en 10.000-recordscenario's
  gevalideerd.

## 1.0.0 — 2026-08-15

- Eerste volledige offline release voor Android en Windows.
- Persistent invoerbord met analysemodus, geschiedenis-CRUD en undo.
- Recente verdelingen, basisstatistiek en uitgebreide getaldetails.
- Wielafstand-patroon en adaptief ensemble met officiële evaluatie.
- Incrementele walk-forward backtest en uniforme baseline.
- Transactionele SQLite-opslag, JSON-back-up, CSV en flexibele importpreview.
- Licht/donker/systeemthema, responsieve navigatie, toetsenbord- en toegankelijkheidsbasis.
- Automatische Android cloud-back-up uitgeschakeld; geen runtime-netwerktoegang.
