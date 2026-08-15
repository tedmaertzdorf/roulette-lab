# Webdeployment naar roulette.tedware.nl

## Productieconfiguratie

- Custom domein: `https://roulette.tedware.nl`
- Flutter base href: `/`
- GitHub-account: `tedmaertzdorf`
- Repository: `tedmaertzdorf/roulette-lab` (`main`, publiek)
- GitHub Pages CNAME-doel: `tedmaertzdorf.github.io`
- Build/deployworkflow: `.github/workflows/deploy-pages.yml`

De projectmap is gekoppeld aan de repository en volgt `origin/main`. GitHub
Pages gebruikt **GitHub Actions** als publicatiebron en het custom domein
`roulette.tedware.nl` is via de Pages API ingesteld.

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

## GitHub Pages-status

- bron: GitHub Actions;
- custom domain: `roulette.tedware.nl`;
- meest recente productiebuild: geslaagd;
- HTTPS-certificaat: wacht op de CNAME-wijziging bij STRATO;
- **Enforce HTTPS**: wordt beschikbaar nadat GitHub de DNS-check en
  certificaatuitgifte heeft voltooid.

Er resteert geen handmatige GitHub Pages-configuratie. Na DNS-propagatie kan
HTTPS via de Pages API of via **Settings → Pages → Enforce HTTPS** worden
ingeschakeld.

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
dezelfde host als STRATO die niet automatisch vervangt. Bij de laatste controle
wees de host nog naar STRATO (`217.160.0.63` plus een STRATO-IPv6-adres); die
records moeten door de CNAME worden vervangen.

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
