# Algoritmen — Roulette Lab Offline

## Eerlijke interpretatie

Een eerlijk Europees roulettewiel produceert onafhankelijke uitkomsten. De verdelingen in deze app zijn genormaliseerde **modelinschattingen**, geen bewezen kansen, inzetadvies of winstgarantie. Iedere evaluatie wordt daarom ook vergeleken met de uniforme verdeling `1/37`.

## Twee ordeningen

Het invoerbord gebruikt de rekenkundige tafelvolgorde: 0 bovenaan en daarna 12 rijen met 1–3, 4–6, …, 34–36. Fysieke afstanden gebruiken uitsluitend deze Europese wielvolgorde:

```text
0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23,
10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
```

Voor indices `a` en `b` is de klokwijzerafstand `(b-a) mod 37`. Waarden 19–36 worden als `raw-37` geschreven, zodat de getekende afstand altijd `-18..18` is. Dezelfde uitkomst heeft afstand 0.

## Gemeenschappelijke numerieke regels

- Iedere expert levert exact 37 niet-negatieve, eindige waarden.
- `normalizeOrUniform` normaliseert de som naar 1. Bij verkeerde lengte, nulmassa, `NaN`, oneindigheid of negatieve invoer valt de hele vector veilig terug op uniform.
- Gelijke scores worden deterministisch opgelost op het laagste getal.
- Dozijnscores worden afgeleid door getalkansen op te tellen; index 0 blijft apart omdat 0 geen dozijn heeft.
- Log-loss gebruikt `-ln(max(pActual, 1e-12))`.
- De multiclass Brier-score is `Σ(p_i-y_i)²`.
- De fingerprint is een lokale FNV-1a-achtige 32-bit hash van volgorde, positie en modelinstellingen.

## Model 1: wielafstand-patroon, versie 1

Het model zet de historie om in getekende fysieke wielafstanden en combineert vijf experts:

1. **Exact suffix** zoekt eerdere exacte suffixen van lengte 1–6. Langere contexten wegen kwadratisch en recente overeenkomsten wegen exponentieel zwaarder.
2. **Fuzzy patroon** vergelijkt contexten van lengte 3–6 op getekende én absolute afstand. De similarity is exponentieel aflopend met de gemiddelde afwijking.
3. **Periodiciteit** test lags 2–8 en weegt support en gemiddelde afwijking. Lag 2 krijgt een kleine voorkeur wanneer een duidelijke afwisseling bestaat.
4. **Delta-overgang** schat de volgende delta conditioneel op de laatste delta en smooth naar de algemene afstandsprior.
5. **Aflopende prior** telt algemene deltas met een halfwaardetijd van ongeveer 90 observaties en een Dirichletmassa richting uniform.

Experts starten gelijk. Voor iedere historisch bekende volgende delta wordt eerst met alleen de prefix voorspeld en pas daarna Hedge toegepast:

```text
loss_i       = clip(-ln(max(p_i(actual), 1e-12)), 0, 27.631)
raw_i        = old_i * exp(-0.07 * loss_i)
normalized_i = raw_i / Σ raw
new_i        = 0.97 * normalized_i + 0.03 / 5
```

De gecombineerde deltaverdeling wordt vanaf het laatste wielgetal teruggeprojecteerd naar 0–36. Sample-shrinkage gebruikt maximaal 0,78 modelmassa en groeit als `deltaCount / (deltaCount + 90)`.

### Fixture +5/+10/+5

Historie `[0, 21, 30, 24]` heeft deltas `+5, +10, +5`. Exact suffix, delta-overgang en lag 2 rangschikken vervolgens `+10` hoog. Vanaf 24 wijst `+10` op getal 29. De regressietest eist daarom dat 29 in de top 3 staat.

## Model 2: adaptief ensemble, versie 1

Dit model combineert zeven getalexperts:

1. **Uniforme controle**: altijd exact `1/37`.
2. **Aflopende frequentie**: halfwaardetijd 60, plus twaalf uniforme pseudotellingen.
3. **Markov eerste orde**: `P(next | last)`, hiërarchisch gesmoothed naar de aflopende frequentie.
4. **Markov tweede orde**: `P(next | previous,last)`, stevig gesmoothed naar eerste orde.
5. **Contextgelijkenis**: contexten van 3–6 getallen; similarity combineert exacte overeenkomst, fysieke wielafstand, kleur, dozijn, kolom, parity en laag/hoog.
6. **Eigenschapsovergang**: aparte transitionmodellen voor kleur/0, dozijn/0, kolom/0, parity/0 en laag/hoog/0. Een gewogen geometrische combinatie projecteert conservatief terug naar getallen.
7. **Wielsector-overgang**: zoekt gelijke of nabije laatste wielgebieden en verspreidt opvolgerstemmen met een cyclische kernel over centrum en ±1/±2.

Hedge gebruikt `eta=0,065` en `gamma=0,035`. Iedere historische uitkomst telt mee, ook wanneer de gebruiker toen niet op de voorspelknop drukte. De eindverdeling wordt naar uniform geshrinkt met:

```text
lambda = min(0.80, spinCount / (spinCount + 120.0))
Pfinal = lambda * Pensemble + (1-lambda) * Puniform
```

## Modelsterkte

Modelsterkte is een conservatieve UI-indicator op basis van samplefactor, genormaliseerde concentratie, echte contextsupport en recente walk-forward log-loss ten opzichte van uniform. Onder 30 draaien en bij slechtere validatie geldt een harde lage cap. Het label zegt dus niets over een gegarandeerd werkelijk voordeel.

## Walk-forward en geen look-ahead

Voor target `t` ziet een model uitsluitend prefix `[0,t)`. De voorspelling wordt gescoord tegen `history[t]`; pas daarna worden expertgewichten bijgewerkt. De evaluator voert dit incrementeel uit, zodat alle punten worden meegenomen zonder het model voor ieder punt vanaf nul te trainen.

Bij edit, delete of vervangende import worden afhankelijke officiële snapshots ongeldig. Backtests worden steeds uit de nieuwe chronologie opgebouwd. Zware berekeningen vanaf 2.000 draaien lopen in een isolate; een generation-token voorkomt dat een verouderd resultaat na een gelijktijdige mutatie wordt opgeslagen.

## Beperkingen

Patroonzoekers kunnen ruis overfitten. Kleine contexten zijn instabiel, afhankelijke eigenschappen kunnen schijnzekerheid geven en zelfs een betere historische score hoeft niet stand te houden. De uniforme expert, smoothing, entropy-indicator, sample-shrinkage en eerlijke out-of-samplevergelijking beperken dit risico, maar nemen het niet weg.
