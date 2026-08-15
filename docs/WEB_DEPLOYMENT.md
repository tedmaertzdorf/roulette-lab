# Webdeployment naar roulette.tedware.nl

## Productieconfiguratie

- Custom domein: `https://roulette.tedware.nl`
- Flutter base href: `/`
- GitHub-account: `tedmaertzdorf`
- GitHub Pages CNAME-doel: `tedmaertzdorf.github.io`
- Build/deployworkflow: `.github/workflows/deploy-pages.yml`

De accountnaam is gecontroleerd via de gekoppelde GitHub-sessie. De lokale
projectmap bevat op dit moment echter geen `.git`-metadata en in het account is
nog geen herkenbare Roulette Lab-repository aanwezig. De repositorynaam moet
daarom eerst expliciet worden gekoppeld of gekozen; die wordt niet aangenomen.

## Automatische pipeline

Een push naar `main` voert achtereenvolgens uit:

1. Flutter 3.35.6 installeren en dependencies ophalen;
2. formattering, `flutter analyze` en alle tests uitvoeren;
3. Flutter Web voor hosting vanaf `/` bouwen;
4. de aparte model-Web-Worker compileren;
5. een inhoudsgehashte offline-service-worker genereren;
6. controleren dat database-Wasm, workers, fonts, CNAME en base href aanwezig
   zijn;
7. het artifact met de officiële GitHub Pages Actions publiceren.

De meegebouwde `CNAME` is een controleerbare declaratie van het beoogde domein.
Bij een custom Actions-workflow beheert GitHub de werkelijke domeinkoppeling via
de Pages-instelling/API; daarom wordt die instelling na het koppelen van de
repository ook expliciet gezet.

## Eenmalige GitHub Pages-instelling

Na het koppelen van de repository:

1. open **GitHub → repository → Settings → Pages**;
2. kies bij **Build and deployment → Source** voor **GitHub Actions**;
3. vul bij **Custom domain** `roulette.tedware.nl` in en sla op;
4. activeer **Enforce HTTPS** zodra de DNS-check groen is.

Deze stappen kunnen via de GitHub API worden uitgevoerd wanneer de exacte
repository bekend is en de huidige accountrechten dat toestaan.

## Eenmalige STRATO DNS-instelling

Maak voor het reeds aangemaakte subdomein exact deze record aan:

```text
Type:   CNAME
Naam:   roulette
Doel:   tedmaertzdorf.github.io
TTL:    3600 (of STRATO-standaard)
```

Als STRATO in het subdomeinscherm de volledige hostnaam toont, is de naam
`roulette.tedware.nl`. Voeg geen `https://`, slash of repositorynaam aan het
doel toe. Verwijder een conflicterende A-, AAAA- of andere CNAME-record voor
dezelfde host als STRATO die niet automatisch vervangt.

## Controleren

Na DNS-propagatie:

```powershell
Resolve-DnsName roulette.tedware.nl -Type CNAME
curl.exe -I https://roulette.tedware.nl
```

De CNAME moet eindigen op `tedmaertzdorf.github.io` en HTTPS moet een succesvolle
GitHub Pages-response geven. Controleer vervolgens in Chrome of Edge:

- bord, geschiedenis, bewerken/verwijderen en beide voorspellingen;
- DevTools → Application → IndexedDB: database `sqflite_databases`;
- DevTools → Application → Service Workers: geactiveerde root-worker;
- herladen na invoer: geschiedenis blijft behouden;
- na minstens één volledige online laadbeurt: browser offline zetten en opnieuw
  openen; de app-shell en lokale gegevens blijven beschikbaar.

DNS-propagatie en de eerste uitgifte van het TLS-certificaat kunnen enige tijd
duren. Activeer **Enforce HTTPS** pas wanneer GitHub de DNS-check heeft voltooid.
