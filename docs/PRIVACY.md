# Privacy en offline werking

Roulette Lab Offline verwerkt alles op het apparaat:

- spins en officiële predictionrecords staan in een lokale SQLite-database;
- op Web wordt die database duurzaam in IndexedDB binnen de origin
  `https://roulette.tedware.nl` bewaard;
- kleine voorkeuren staan in lokale platformvoorkeuren of browseropslag;
- modelberekeningen en walk-forwardtests draaien in Dart op het apparaat;
- import en export gebruiken uitsluitend een door de gebruiker gekozen lokaal bestand.

De app bevat geen backend, account, Firebase, advertenties, telemetry,
analytics-SDK, remote config, online fonts of externe afbeeldingen. De webapp
vraagt alleen statische applicatiebestanden van dezelfde origin op; spins,
instellingen en modelresultaten worden niet meegestuurd. Het Android
releasemanifest bevat geen `INTERNET`-permissie. Alleen debug/profile hebben de
standaard Flutter-permissie voor hot reload en debugging.

De web-service-worker cachet uitsluitend de app-shell, lokale fonts, iconen,
SQLite/Wasm en JavaScript-bestanden. Daardoor kan de app na één volledige
online laadbeurt opnieuw offline worden geopend. De roulettegegevens zelf
blijven in IndexedDB en maken geen deel uit van die deelbare cache.

Android cloud-back-up is uitgeschakeld en database-/voorkeurendomeinen zijn bovendien uitgesloten van back-up en device-transferregels. Gebruik de handmatige JSON-back-up om gegevens zelf te bewaren of verplaatsen.

Een geëxporteerd bestand kan gevoelige persoonlijke notities in tijdstippen en gebruikspatronen bevatten. Bewaar het daarom op een locatie die je vertrouwt. De app versleutelt exportbestanden niet.
